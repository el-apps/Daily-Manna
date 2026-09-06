# Daily Manna API

This small Go service proxies the AI operations used by Recitation mode. The
Flutter app calls this service; the OpenRouter credential remains server-side.

## Run locally

```sh
OPENROUTER_API_KEY=... go run .
```

The server listens on `:8080` by default. Set `PORT` to change it.

## Endpoints

- `GET /api/health`
- `POST /api/transcribe` with `{ "audioBase64": "...", "filename": "audio.wav" }`
- `POST /api/recognize-passage` with `{ "transcribedText": "...", "availableBookIds": ["Gen"] }`

Configure the Flutter app with `--dart-define=DAILY_MANNA_API_URL=...` when
using a different API host. Production defaults to
`https://dailymanna.kwila.cloud/api`.
