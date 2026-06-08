# HR Interview Transcription API

Self-hosted [OpenAI Whisper](https://github.com/openai/whisper) HTTP API for transcribing HR video interviews. Designed for integration with n8n workflows.

## Features

- Transcribes audio/video files (`.webm`, `.mp4`, `.mp3`, etc.)
- REST API with API key authentication
- Temporary upload files deleted after each request
- nginx reverse proxy on port 8080 (avoids conflicts with other VPS services)

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/transcribe` | Transcribe uploaded file (multipart field: `file`) |

### Request

```bash
curl -X POST "http://YOUR_VPS_IP:8080/transcribe" \
  -H "X-API-Key: YOUR_API_KEY" \
  -F "file=@interview.webm"
```

### Response

```json
{
  "transcript": "Full spoken text...",
  "text": "Full spoken text...",
  "language": "en",
  "segments": [
    { "start": 0.0, "end": 4.2, "text": "Hello..." }
  ]
}
```

## VPS Deployment

### Requirements

- Ubuntu 22.04+
- 4 GB RAM minimum
- ffmpeg, Python 3.10+, nginx

### Install

1. Upload files to the VPS:

```bash
scp -r ./* root@YOUR_VPS_IP:/opt/whisper-api/
```

2. SSH in and run:

```bash
cd /opt/whisper-api
chmod +x install.sh
bash install.sh
```

3. Save the API key printed at the end.

4. Open port 8080 in your firewall (Vultr dashboard or `ufw allow 8080/tcp`).

5. Verify:

```bash
curl http://YOUR_VPS_IP:8080/health
```

## n8n Integration

Add an **HTTP Request** node:

| Setting | Value |
|---------|--------|
| Method | `POST` |
| URL | `http://YOUR_VPS_IP:8080/transcribe` |
| Auth | Header `X-API-Key` |
| Body Content Type | `Form-Data` |
| Body parameter | Name: `file`, Type: Binary, Field: `video` |
| Timeout | `600000` |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_MODEL` | `base` | Whisper model size (`tiny`, `base`, `small`, `medium`) |
| `API_KEY` | (empty) | API key for `X-API-Key` header. Empty = no auth. |

## License

Internal use — Mountainise Inc.
