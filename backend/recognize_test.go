package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestValidRecognition(t *testing.T) {
	p := func(s string) *string { return &s }
	i := func(v int) *int { return &v }
	book := "Psa"
	single := i(1)
	allowed := map[string]bool{"psa": true, "1cor": true}

	cases := []struct {
		name string
		r    passageRecognition
		want bool
	}{
		{"valid single verse", passageRecognition{BookID: &book, Chapter: single, StartVerse: single}, true},
		{"missing book id", passageRecognition{Chapter: single, StartVerse: single}, false},
		{"missing start verse", passageRecognition{BookID: &book, Chapter: single}, false},
		{"book not allowed", passageRecognition{BookID: p("Gen"), Chapter: single, StartVerse: single}, false},
		{"capitalized book resolves lowercase", passageRecognition{BookID: p("1Cor"), Chapter: single, StartVerse: single}, true},
		{"zero chapter", passageRecognition{BookID: &book, Chapter: i(0), StartVerse: single}, false},
		{"end before start", passageRecognition{BookID: &book, Chapter: single, StartVerse: i(5), EndVerse: i(3)}, false},
		{"end after start", passageRecognition{BookID: &book, Chapter: single, StartVerse: i(3), EndVerse: i(5)}, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := validRecognition(&tc.r, allowed); got != tc.want {
				t.Errorf("validRecognition() = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestRecognizePassageUsesStubAndReturnsBookRef(t *testing.T) {
	s := &server{
		classify: func(ctx context.Context, text string, ids []string) (map[string]any, error) {
			return map[string]any{
				"bookId":     "Psa",
				"book":       "Psalms",
				"chapter":    23,
				"startVerse": 1,
				"endVerse":   1,
			}, nil
		},
	}

	req := httptest.NewRequest(http.MethodPost, "/api/recognize-passage",
		strings.NewReader(`{"transcribedText":"The Lord is my shepherd","availableBookIds":["gen","psa","1cor"]}`))
	w := httptest.NewRecorder()
	s.recognizePassage(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", w.Code, w.Body.String())
	}
	var res struct {
		BookID     any `json:"bookId"`
		Chapter    any `json:"chapter"`
		StartVerse any `json:"startVerse"`
		EndVerse   any `json:"endVerse"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.BookID != "Psa" || res.Chapter != float64(23) || res.StartVerse != float64(1) || res.EndVerse != float64(1) {
		t.Fatalf("unexpected response: %+v", res)
	}
}

func TestRecognizePassageAllowsManualUncertainty(t *testing.T) {
	// If the stub returns all-null (uncertain), the handler should return it
	// rather than an error, letting the client prompt for manual entry.
	s := &server{
		classify: func(ctx context.Context, text string, ids []string) (map[string]any, error) {
			return map[string]any{"bookId": nil, "book": nil, "chapter": nil, "startVerse": nil, "endVerse": nil}, nil
		},
	}

	req := httptest.NewRequest(http.MethodPost, "/api/recognize-passage",
		strings.NewReader(`{"transcribedText":"some text","availableBookIds":["gen"]}`))
	w := httptest.NewRecorder()
	s.recognizePassage(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"bookId":null`) {
		t.Fatalf("expected null bookId in uncertain response, got %s", w.Body.String())
	}
}

func TestRecognitionResponseNormalizesBookID(t *testing.T) {
	p := func(s string) *string { return &s }
	i := func(v int) *int { return &v }

	r := &passageRecognition{
		BookID:     p("1Cor"),
		Book:       p("1 Corinthians"),
		Chapter:    i(13),
		StartVerse: i(1),
		EndVerse:   i(13),
	}

	res := recognitionResponse(r)
	if res["bookId"] != "1cor" {
		t.Errorf("bookId = %v, want lowercase %q", res["bookId"], "1cor")
	}
	if res["chapter"] != 13 || res["startVerse"] != 1 || res["endVerse"] != 13 {
		t.Errorf("unexpected response: %+v", res)
	}
}
