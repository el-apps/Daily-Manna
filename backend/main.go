package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/labstack/echo/v5"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	_ "github.com/el-apps/Daily-Manna/backend/migrations"
)

const (
	openRouterURL      = "https://openrouter.int.exe.xyz/api/v1"
	transcriptionModel = "nvidia/parakeet-tdt-0.6b-v3"
	recognitionModel   = "openai/gpt-5.6-luna"
	maxRequestBytes    = 8 << 20

	// recognitionAttempts is how many times the classifier is asked to
	// re-identify the passage when it returns unparsable or invalid output.
	recognitionAttempts = 3
)

type server struct {
	client    *http.Client
	syncStore syncStore
	classify  classifyFunc
}

type transcribeRequest struct {
	AudioBase64 string `json:"audioBase64"`
	Filename    string `json:"filename"`
}

type recognizeRequest struct {
	TranscribedText  string   `json:"transcribedText"`
	AvailableBookIDs []string `json:"availableBookIds"`
}

func main() {
	client := &http.Client{Timeout: 2 * time.Minute}
	app := pocketbase.New()
	s := &server{client: client, syncStore: newPocketBaseStore(app)}
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{})

	app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
		e.Router.GET("/api/health", echo.WrapHandler(http.HandlerFunc(s.health)))
		e.Router.POST("/api/transcribe", echo.WrapHandler(http.HandlerFunc(s.transcribe)))
		e.Router.POST("/api/recognize-passage", echo.WrapHandler(http.HandlerFunc(s.recognizePassage)))
		e.Router.POST("/api/sync", echo.WrapHandler(http.HandlerFunc(s.sync)))
		return nil
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if len(os.Args) == 1 {
		os.Args = append(os.Args, "serve", "--http=0.0.0.0:"+strconv.Itoa(mustPort(port)))
	}
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

func mustPort(value string) int {
	port, err := strconv.Atoi(value)
	if err != nil || port < 1 || port > 65535 {
		log.Fatalf("invalid PORT %q", value)
	}
	return port
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *server) transcribe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req transcribeRequest
	if err := decodeJSON(w, r, &req); err != nil {
		return
	}
	audio, err := base64.StdEncoding.DecodeString(req.AudioBase64)
	if err != nil || len(audio) == 0 {
		http.Error(w, "audioBase64 must contain valid audio", http.StatusBadRequest)
		return
	}
	format := audioFormat(req.Filename)
	body, err := json.Marshal(map[string]any{
		"model":       transcriptionModel,
		"input_audio": map[string]string{"data": req.AudioBase64, "format": format},
	})
	if err != nil {
		http.Error(w, "could not build request", http.StatusInternalServerError)
		return
	}
	var response struct {
		Text string `json:"text"`
	}
	if err := s.openRouter(r.Context(), "/audio/transcriptions", body, &response); err != nil {
		writeBackendError(w, err)
		return
	}
	if response.Text == "" {
		http.Error(w, "transcription response did not contain text", http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"text": response.Text})
}

func (s *server) recognizePassage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req recognizeRequest
	if err := decodeJSON(w, r, &req); err != nil {
		return
	}
	if strings.TrimSpace(req.TranscribedText) == "" || len(req.AvailableBookIDs) == 0 {
		http.Error(w, "transcribedText and availableBookIds are required", http.StatusBadRequest)
		return
	}

	classify := s.classify
	if classify == nil {
		classify = s.classifyPassage
	}
	result, err := classify(r.Context(), req.TranscribedText, req.AvailableBookIDs)
	if err != nil {
		writeBackendError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

// passageRecognition stores one recognized passage from the classifier.
type passageRecognition struct {
	BookID     *string `json:"bookId"`
	Book       *string `json:"book"`
	Chapter    *int    `json:"chapter"`
	StartVerse *int    `json:"startVerse"`
	EndVerse   *int    `json:"endVerse"`
}

// classifyFunc queries the classifier LLM against a single-chapter passage
// and returns its parsed output. Extracted so tests can inject a stub.
type classifyFunc func(ctx context.Context, transcribedText string, availableBookIDs []string) (map[string]any, error)

// classifyPassage asks the classifier LLM to identify the passage, logs the
// raw output for traceability, and retries when the output is unparsable or
// invalid (missing or out-of-scope fields). It returns the first valid
// recognition, or an empty (all-null) recognition if none of the attempts
// produced valid output.
func (s *server) classifyPassage(ctx context.Context, transcribedText string, availableBookIDs []string) (map[string]any, error) {
	allowed := make(map[string]bool, len(availableBookIDs))
	for _, id := range availableBookIDs {
		allowed[strings.ToLower(id)] = true
	}

	systemPrompt := fmt.Sprintf("You are a Bible passage recognition AI. Given transcribed text from someone reciting a Bible passage, identify which passage they are reciting. The text may contain transcription errors, paraphrasing, or slight variations. Available books (exactly these book IDs): %s. Return a book ID exactly as listed. Respond only with JSON in this format: {\"bookId\":\"Psa\",\"book\":\"Psalms\",\"chapter\":23,\"startVerse\":1,\"endVerse\":3}. Only single-chapter passages are supported. If uncertain, return all null values.", strings.Join(availableBookIDs, ", "))
	messages := []map[string]string{
		{"role": "system", "content": systemPrompt},
		{"role": "user", "content": "Identify this Bible passage from the transcribed text:\n\n\"" + transcribedText + "\""},
	}

	for attempt := 1; attempt <= recognitionAttempts; attempt++ {
		body, err := json.Marshal(map[string]any{
			"model":           recognitionModel,
			"temperature":     0.3,
			"response_format": map[string]string{"type": "json_object"},
			"messages":        messages,
		})
		if err != nil {
			return nil, fmt.Errorf("could not build request: %w", err)
		}

		var response struct {
			Choices []struct {
				Message struct {
					Content string `json:"content"`
				} `json:"message"`
			} `json:"choices"`
		}
		if err := s.openRouter(ctx, "/chat/completions", body, &response); err != nil {
			return nil, err
		}
		if len(response.Choices) == 0 {
			log.Printf("[recognize] attempt %d/%d: no choices returned", attempt, recognitionAttempts)
			continue
		}
		rawContent := response.Choices[0].Message.Content
		log.Printf("[recognize] attempt %d/%d raw output: %s", attempt, recognitionAttempts, rawContent)

		var parsed map[string]any
		if err := json.Unmarshal([]byte(rawContent), &parsed); err != nil {
			log.Printf("[recognize] attempt %d/%d: invalid JSON (%v)", attempt, recognitionAttempts, err)
			continue
		}

		recognized := passageRecognition{}
		if bookID, ok := parsed["bookId"].(string); ok {
			recognized.BookID = &bookID
		}
		if book, ok := parsed["book"].(string); ok {
			recognized.Book = &book
		}
		if chapter, ok := parsed["chapter"].(float64); ok {
			c := int(chapter)
			recognized.Chapter = &c
		}
		if startVerse, ok := parsed["startVerse"].(float64); ok {
			sv := int(startVerse)
			recognized.StartVerse = &sv
		}
		if endVerse, ok := parsed["endVerse"].(float64); ok {
			ev := int(endVerse)
			recognized.EndVerse = &ev
		}

		if !validRecognition(&recognized, allowed) {
			log.Printf("[recognize] attempt %d/%d: invalid recognition: %+v", attempt, recognitionAttempts, recognized)
			continue
		}

		return recognitionResponse(&recognized), nil
	}

	log.Printf("[recognize] no valid recognition after %d attempts", recognitionAttempts)
	return map[string]any{
		"bookId":     nil,
		"book":       nil,
		"chapter":    nil,
		"startVerse": nil,
		"endVerse":   nil,
	}, nil
}

func validRecognition(r *passageRecognition, allowed map[string]bool) bool {
	if r.BookID == nil || r.Chapter == nil || r.StartVerse == nil {
		return false
	}
	if !allowed[strings.ToLower(*r.BookID)] {
		return false
	}
	if *r.Chapter < 1 || *r.StartVerse < 1 {
		return false
	}
	if r.EndVerse == nil {
		e := *r.StartVerse
		r.EndVerse = &e
	}
	return *r.EndVerse >= *r.StartVerse
}

// recognitionResponse maps a validated recognition to the API response,
// normalizing the book id to lowercase so it matches the app's canonical
// (lowercase) book keys. This prevents the app from looking up an id that
// isn't in its map (which surfaced as "Unknown").
func recognitionResponse(r *passageRecognition) map[string]any {
	return map[string]any{
		"bookId":     strings.ToLower(*r.BookID),
		"book":       derefString(r.Book),
		"chapter":    *r.Chapter,
		"startVerse": *r.StartVerse,
		"endVerse":   derefInt(r.EndVerse),
	}
}

func derefString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}

func derefInt(v *int) int {
	if v == nil {
		return -1
	}
	return *v
}

func (s *server) openRouter(ctx context.Context, path string, body []byte, result any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openRouterURL+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("HTTP-Referer", "https://dailymanna.kwila.cloud")
	req.Header.Set("X-Title", "Daily Manna")
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("OpenRouter returned %s: %s", resp.Status, strings.TrimSpace(string(responseBody)))
	}
	if err := json.Unmarshal(responseBody, result); err != nil {
		return err
	}
	return nil
}

func decodeJSON(w http.ResponseWriter, r *http.Request, value any) error {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBytes)
	err := json.NewDecoder(r.Body).Decode(value)
	if err != nil {
		http.Error(w, "invalid request JSON", http.StatusBadRequest)
	}
	return err
}

func writeBackendError(w http.ResponseWriter, err error) {
	http.Error(w, "backend provider request failed: "+err.Error(), http.StatusBadGateway)
}
func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func audioFormat(filename string) string {
	name := strings.ToLower(filename)
	if strings.HasSuffix(name, ".m4a") {
		return "aac"
	}
	if strings.HasSuffix(name, ".opus") {
		return "ogg"
	}
	for _, format := range []string{"wav", "mp3", "aiff", "aac", "ogg", "flac", "pcm16", "pcm24"} {
		if strings.HasSuffix(name, "."+format) {
			return format
		}
	}
	return "wav"
}
