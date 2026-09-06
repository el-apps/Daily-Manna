package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"sort"
	"strings"
	"sync"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
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
	app core.App
}

func newPocketBaseStore(app core.App) *pocketBaseStore {
	return &pocketBaseStore{app: app}
}

func (p *pocketBaseStore) Authenticate(ctx context.Context, token string) (string, error) {
	record, err := p.app.Dao().FindAuthRecordByToken(token, p.app.Settings().RecordAuthToken.Secret)
	if err != nil || record == nil || record.Collection().Name != "users" {
		return "", errUnauthorized
	}
	return record.Id, nil
}

func (p *pocketBaseStore) Load(ctx context.Context, token, userID string) (syncState, error) {
	record, err := p.app.Dao().FindFirstRecordByFilter(defaultSyncCollection, "owner={:owner}", dbx.Params{"owner": userID})
	if errors.Is(err, sql.ErrNoRows) {
		return syncState{}, nil
	}
	if err != nil {
		return syncState{}, err
	}
	var items []syncChange
	raw, err := json.Marshal(record.Get("items"))
	if err != nil {
		return syncState{}, err
	}
	if err := json.Unmarshal(raw, &items); err != nil {
		return syncState{}, err
	}
	return syncState{RecordID: record.Id, Cursor: uint64(record.GetInt("cursor")), Items: items}, nil
}

func (p *pocketBaseStore) Save(ctx context.Context, token, userID string, state syncState) error {
	var record *models.Record
	var err error
	if state.RecordID != "" {
		record, err = p.app.Dao().FindRecordById(defaultSyncCollection, state.RecordID)
	} else {
		collection, findErr := p.app.Dao().FindCollectionByNameOrId(defaultSyncCollection)
		err = findErr
		if err == nil {
			record = models.NewRecord(collection)
		}
	}
	if err != nil {
		return err
	}
	record.Set("owner", userID)
	record.Set("cursor", state.Cursor)
	record.Set("items", state.Items)
	return p.app.Dao().SaveRecord(record)
}
