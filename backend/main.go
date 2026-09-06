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
	"strings"
	"time"
)

const (
	openRouterURL      = "https://openrouter.ai/api/v1"
	transcriptionModel = "nvidia/parakeet-tdt-0.6b-v3"
	recognitionModel   = "openai/gpt-5-mini"
	maxRequestBytes    = 8 << 20
)

type server struct {
	client *http.Client
	apiKey string
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
	apiKey := os.Getenv("OPENROUTER_API_KEY")
	if apiKey == "" {
		log.Fatal("OPENROUTER_API_KEY is required")
	}

	s := &server{client: &http.Client{Timeout: 2 * time.Minute}, apiKey: apiKey}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", s.health)
	mux.HandleFunc("/api/transcribe", s.transcribe)
	mux.HandleFunc("/api/recognize-passage", s.recognizePassage)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Daily Manna API listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, withCORS(mux)))
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
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
	systemPrompt := fmt.Sprintf("You are a Bible passage recognition AI. Given transcribed text from someone reciting a Bible passage, identify which passage they are reciting. The text may contain transcription errors, paraphrasing, or slight variations. Available books: %s. Return a book ID exactly as listed. Respond only with JSON in this format: {\"bookId\":\"Gen\",\"chapter\":1,\"startVerse\":1,\"endVerse\":3}. Only single-chapter passages are supported. If uncertain, return all null values.", strings.Join(req.AvailableBookIDs, ", "))
	body, err := json.Marshal(map[string]any{
		"model":           recognitionModel,
		"temperature":     0.3,
		"response_format": map[string]string{"type": "json_object"},
		"messages":        []map[string]string{{"role": "system", "content": systemPrompt}, {"role": "user", "content": "Identify this Bible passage from the transcribed text:\n\n\"" + req.TranscribedText + "\""}},
	})
	if err != nil {
		http.Error(w, "could not build request", http.StatusInternalServerError)
		return
	}
	var response struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := s.openRouter(r.Context(), "/chat/completions", body, &response); err != nil {
		writeBackendError(w, err)
		return
	}
	if len(response.Choices) == 0 || response.Choices[0].Message.Content == "" {
		http.Error(w, "recognition response was empty", http.StatusBadGateway)
		return
	}
	var result map[string]any
	if err := json.Unmarshal([]byte(response.Choices[0].Message.Content), &result); err != nil {
		http.Error(w, "recognition response was invalid JSON", http.StatusBadGateway)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *server) openRouter(ctx context.Context, path string, body []byte, result any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openRouterURL+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
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
