package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"sync"
)

const defaultSyncCollection = "sync_states"

type syncChange struct {
	ID      string         `json:"id"`
	Type    string         `json:"type"`
	Data    map[string]any `json:"data,omitempty"`
	Deleted bool           `json:"deleted,omitempty"`
	Version uint64         `json:"version,omitempty"`
}

type syncRequest struct {
	ClientID   string       `json:"clientId"`
	Cursor     uint64       `json:"cursor"`
	BaseCursor uint64       `json:"baseCursor"`
	Changes    []syncChange `json:"changes"`
}

type syncState struct {
	RecordID string       `json:"-"`
	Cursor   uint64       `json:"cursor"`
	Items    []syncChange `json:"items"`
}

type syncStore interface {
	Authenticate(context.Context, string) (string, error)
	Load(context.Context, string, string) (syncState, error)
	Save(context.Context, string, string, syncState) error
}

var errUnauthorized = errors.New("unauthorized")

// A process lock also prevents lost updates when several requests hit this
// instance. PocketBase remains the durable source of truth.
var syncLocks sync.Map

func (s *server) sync(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if s.syncStore == nil {
		http.Error(w, "sync is not configured", http.StatusServiceUnavailable)
		return
	}
	token := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	if token == "" || token == r.Header.Get("Authorization") {
		http.Error(w, "authentication required", http.StatusUnauthorized)
		return
	}
	userID, err := s.syncStore.Authenticate(r.Context(), token)
	if err != nil {
		http.Error(w, "invalid authentication", http.StatusUnauthorized)
		return
	}
	var req syncRequest
	if err := decodeJSON(w, r, &req); err != nil {
		return
	}
	if strings.TrimSpace(req.ClientID) == "" || len(req.ClientID) > 128 {
		http.Error(w, "clientId is required and must be at most 128 characters", http.StatusBadRequest)
		return
	}
	for _, change := range req.Changes {
		if change.ID == "" || change.Type == "" || len(change.ID) > 128 || len(change.Type) > 64 {
			http.Error(w, "every change requires a bounded id and type", http.StatusBadRequest)
			return
		}
	}
	lockValue, _ := syncLocks.LoadOrStore(userID, &sync.Mutex{})
	lock := lockValue.(*sync.Mutex)
	lock.Lock()
	defer lock.Unlock()

	state, err := s.syncStore.Load(r.Context(), token, userID)
	if err != nil {
		http.Error(w, "could not load sync state", http.StatusBadGateway)
		return
	}
	if len(req.Changes) > 0 && req.BaseCursor != state.Cursor {
		writeJSON(w, http.StatusConflict, map[string]any{
			"error": "stale baseCursor; pull and merge before pushing", "cursor": state.Cursor,
			"changes": changesAfter(state.Items, req.Cursor),
		})
		return
	}
	for _, incoming := range req.Changes {
		state.Cursor++
		incoming.Version = state.Cursor
		// Tombstones are retained so every client can observe deletions.
		state.Items = replaceChange(state.Items, incoming)
	}
	if len(req.Changes) > 0 {
		if err := s.syncStore.Save(r.Context(), token, userID, state); err != nil {
			http.Error(w, "could not save sync state", http.StatusBadGateway)
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"cursor": state.Cursor, "changes": changesAfter(state.Items, req.Cursor)})
}

func replaceChange(items []syncChange, change syncChange) []syncChange {
	for i := range items {
		if items[i].Type == change.Type && items[i].ID == change.ID {
			items[i] = change
			return items
		}
	}
	return append(items, change)
}

func changesAfter(items []syncChange, cursor uint64) []syncChange {
	result := make([]syncChange, 0)
	for _, item := range items {
		if item.Version > cursor {
			result = append(result, item)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Version < result[j].Version })
	return result
}

type pocketBaseStore struct {
	baseURL, collection string
	client              *http.Client
}

func newPocketBaseStore(baseURL, collection string, client *http.Client) *pocketBaseStore {
	if collection == "" {
		collection = defaultSyncCollection
	}
	return &pocketBaseStore{baseURL: baseURL, collection: collection, client: client}
}

func (p *pocketBaseStore) Authenticate(ctx context.Context, token string) (string, error) {
	var response struct {
		Record struct {
			ID string `json:"id"`
		} `json:"record"`
	}
	if err := p.request(ctx, token, http.MethodPost, "/api/collections/users/auth-refresh", nil, &response); err != nil || response.Record.ID == "" {
		return "", errUnauthorized
	}
	return response.Record.ID, nil
}

func (p *pocketBaseStore) Load(ctx context.Context, token, userID string) (syncState, error) {
	path := "/api/collections/" + url.PathEscape(p.collection) + "/records?perPage=1&filter=" + url.QueryEscape("owner='"+strings.ReplaceAll(userID, "'", "\\'")+"'")
	var response struct {
		Items []struct {
			ID     string       `json:"id"`
			Cursor uint64       `json:"cursor"`
			Items  []syncChange `json:"items"`
		} `json:"items"`
	}
	if err := p.request(ctx, token, http.MethodGet, path, nil, &response); err != nil {
		return syncState{}, err
	}
	if len(response.Items) == 0 {
		return syncState{}, nil
	}
	return syncState{RecordID: response.Items[0].ID, Cursor: response.Items[0].Cursor, Items: response.Items[0].Items}, nil
}

func (p *pocketBaseStore) Save(ctx context.Context, token, userID string, state syncState) error {
	method, path := http.MethodPost, "/api/collections/"+url.PathEscape(p.collection)+"/records"
	if state.RecordID != "" {
		method, path = http.MethodPatch, path+"/"+url.PathEscape(state.RecordID)
	}
	body := map[string]any{"owner": userID, "cursor": state.Cursor, "items": state.Items}
	return p.request(ctx, token, method, path, body, nil)
}

func (p *pocketBaseStore) request(ctx context.Context, token, method, path string, body any, result any) error {
	var reader io.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(encoded)
	}
	req, err := http.NewRequestWithContext(ctx, method, p.baseURL+path, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		io.Copy(io.Discard, resp.Body)
		return fmt.Errorf("PocketBase returned %s", resp.Status)
	}
	if result == nil {
		io.Copy(io.Discard, resp.Body)
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(result)
}
