package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeSyncStore struct {
	state syncState
}

func (f *fakeSyncStore) Authenticate(_ context.Context, token string) (string, error) {
	if token != "valid" {
		return "", errors.New("bad token")
	}
	return "user-1", nil
}

func (f *fakeSyncStore) Load(context.Context, string, string) (syncState, error) {
	return f.state, nil
}

func (f *fakeSyncStore) Save(_ context.Context, _, _ string, state syncState) error {
	f.state = state
	return nil
}

func syncCall(t *testing.T, s *server, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/api/sync", strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	s.sync(w, req)
	return w
}

func TestSyncRequiresAuthentication(t *testing.T) {
	w := syncCall(t, &server{syncStore: &fakeSyncStore{}}, "", `{"clientId":"device","changes":[]}`)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestSyncPullMergePushAndTombstone(t *testing.T) {
	store := &fakeSyncStore{state: syncState{Cursor: 1, Items: []syncChange{{ID: "old", Type: "result", Data: map[string]any{"score": float64(80)}, Version: 1}}}}
	s := &server{syncStore: store}

	pull := syncCall(t, s, "valid", `{"clientId":"device-a","cursor":0,"baseCursor":0,"changes":[]}`)
	if pull.Code != http.StatusOK {
		t.Fatalf("pull status = %d: %s", pull.Code, pull.Body.String())
	}
	var pulled struct {
		Cursor  uint64       `json:"cursor"`
		Changes []syncChange `json:"changes"`
	}
	if err := json.Unmarshal(pull.Body.Bytes(), &pulled); err != nil {
		t.Fatal(err)
	}
	if pulled.Cursor != 1 || len(pulled.Changes) != 1 {
		t.Fatalf("unexpected pull: %+v", pulled)
	}

	push := syncCall(t, s, "valid", `{"clientId":"device-a","cursor":1,"baseCursor":1,"changes":[{"type":"result","id":"old","deleted":true},{"type":"result","id":"new","data":{"score":95}}]}`)
	if push.Code != http.StatusOK {
		t.Fatalf("push status = %d: %s", push.Code, push.Body.String())
	}
	if store.state.Cursor != 3 || len(store.state.Items) != 2 || !store.state.Items[0].Deleted || store.state.Items[0].Version != 2 {
		t.Fatalf("unexpected saved state: %+v", store.state)
	}
}

func TestSyncRejectsStalePushWithPullChanges(t *testing.T) {
	store := &fakeSyncStore{state: syncState{Cursor: 2, Items: []syncChange{{ID: "remote", Type: "note", Version: 2}}}}
	w := syncCall(t, &server{syncStore: store}, "valid", `{"clientId":"device-b","cursor":1,"baseCursor":1,"changes":[{"type":"note","id":"local","data":{"text":"x"}}]}`)
	if w.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d: %s", w.Code, http.StatusConflict, w.Body.String())
	}
	var response struct {
		Cursor  uint64       `json:"cursor"`
		Changes []syncChange `json:"changes"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response.Cursor != 2 || len(response.Changes) != 1 || store.state.Cursor != 2 {
		t.Fatalf("unexpected conflict response/state: %+v / %+v", response, store.state)
	}
}
