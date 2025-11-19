#!/bin/bash

# Configuration file for Local Whisper Transcriber
# Modify these paths according to your setup

# Folder to monitor for new MP3 recordings
WATCH_FOLDER="$HOME/Recordings"

# Folder to store processed/archived MP3 files
ARCHIVE_FOLDER="$HOME/Recordings/archive"

# Folder to output Markdown transcripts
TRANSCRIPT_FOLDER="$HOME/Recordings/transcripts"

# Whisper model to use (options: base, small, medium, large)
# Note: larger models provide better accuracy but require more resources
WHISPER_MODEL="base"

# Path to whisper.cpp executable (will be set by installer)
WHISPER_CPP_PATH="/opt/homebrew/bin/whisper-cli"

# Path to fswatch executable (will be set by installer)
FSWATCH_PATH="/opt/homebrew/bin/fswatch"

# Path to Whisper model file (will be set by installer)
WHISPER_MODEL_PATH="/Users/mguerra/.whisper/ggml-base.bin"

# File completion detection settings
# Time in seconds to wait after last modification before considering file complete
# This is checked AFTER the file is no longer open by any process
FILE_STABILITY_TIME=10

# Transcription options
# Enable timestamps in transcript (true/false)
ENABLE_TIMESTAMPS=true

# Output format for timestamps (srt, vtt, or txt)
# srt: SubRip format with timestamps
# vtt: WebVTT format with timestamps
# txt: Plain text (no timestamps)
TIMESTAMP_FORMAT="srt"

# AI-based speaker identification using pyannote.audio
# Enable speaker diarization (true/false)
# NOTE: Currently disabled due to pyannote.audio compatibility with PyTorch 2.9+
# Will be enabled automatically once pyannote.audio is updated
ENABLE_SPEAKER_DIARIZATION=false

# Speaker diarization settings (optional, leave empty for auto-detection)
MIN_SPEAKERS=""  # Minimum number of speakers (e.g., 2)
MAX_SPEAKERS=""  # Maximum number of speakers (e.g., 4)

# Log level (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL="INFO"

# Project root directory (set by installer)
PROJECT_ROOT="/Users/mguerra/_Code/whisper_transcriber"

# Validate configuration
validate_config() {
    if [[ ! -d "$WATCH_FOLDER" ]]; then
        echo "ERROR: Watch folder does not exist: $WATCH_FOLDER"
        return 1
    fi

    if [[ ! -d "$ARCHIVE_FOLDER" ]]; then
        echo "ERROR: Archive folder does not exist: $ARCHIVE_FOLDER"
        return 1
    fi

    if [[ ! -d "$TRANSCRIPT_FOLDER" ]]; then
        echo "ERROR: Transcript folder does not exist: $TRANSCRIPT_FOLDER"
        return 1
    fi

    if [[ -z "$WHISPER_CPP_PATH" ]] || [[ ! -f "$WHISPER_CPP_PATH" ]]; then
        echo "ERROR: Whisper.cpp executable not found at: $WHISPER_CPP_PATH"
        return 1
    fi

    if [[ -z "$FSWATCH_PATH" ]] || [[ ! -f "$FSWATCH_PATH" ]]; then
        echo "ERROR: fswatch executable not found at: $FSWATCH_PATH"
        return 1
    fi

    if [[ -z "$WHISPER_MODEL_PATH" ]] || [[ ! -f "$WHISPER_MODEL_PATH" ]]; then
        echo "ERROR: Whisper model file not found at: $WHISPER_MODEL_PATH"
        return 1
    fi

    return 0
}
