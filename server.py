"""
Whisper transcription HTTP API for VPS + n8n integration.

POST /transcribe  — multipart file upload (field name: file)
GET  /health      — liveness check
"""

import os
import tempfile
from typing import Optional

from fastapi import FastAPI, File, Header, HTTPException, UploadFile

WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "base")
API_KEY = os.environ.get("API_KEY", "")

app = FastAPI(title="HR Interview Whisper API", version="1.0.0")
_model = None


def get_model():
    global _model
    if _model is None:
        import whisper

        _model = whisper.load_model(WHISPER_MODEL)
    return _model


def transcribe_file(local_path: str) -> dict:
    result = get_model().transcribe(local_path)
    text = result["text"].strip()
    return {
        "transcript": text,
        "text": text,
        "language": result.get("language"),
        "segments": [
            {
                "start": segment["start"],
                "end": segment["end"],
                "text": segment["text"].strip(),
            }
            for segment in result.get("segments", [])
        ],
    }


def require_api_key(x_api_key: Optional[str]) -> None:
    if not API_KEY:
        return
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


@app.get("/health")
def health():
    return {"status": "ok", "model": WHISPER_MODEL}


@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    x_api_key: Optional[str] = Header(default=None),
):
    require_api_key(x_api_key)

    suffix = os.path.splitext(file.filename or ".webm")[1] or ".webm"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        local_path = tmp.name

    try:
        return transcribe_file(local_path)
    finally:
        if os.path.exists(local_path):
            os.remove(local_path)
