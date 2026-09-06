package main

import "testing"

func TestAudioFormat(t *testing.T) {
	for _, test := range []struct{ filename, want string }{{"audio.wav", "wav"}, {"audio.m4a", "aac"}, {"audio.opus", "ogg"}, {"audio.unknown", "wav"}} {
		if got := audioFormat(test.filename); got != test.want {
			t.Errorf("audioFormat(%q) = %q, want %q", test.filename, got, test.want)
		}
	}
}
