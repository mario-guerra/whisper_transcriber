#!/bin/bash

# Local Whisper Transcriber - Watch and Transcribe Script
# Monitors a folder for new MP3 files and transcribes them using whisper.cpp

# Don't exit on errors - we want the service to keep running
set -uo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Only log messages at or above the configured log level
    case "$LOG_LEVEL" in
        "DEBUG") ;;
        "INFO") [[ "$level" == "DEBUG" ]] && return ;;
        "WARN") [[ "$level" =~ ^(DEBUG|INFO)$ ]] && return ;;
        "ERROR") [[ "$level" =~ ^(DEBUG|INFO|WARN)$ ]] && return ;;
    esac

    echo "[$timestamp] [$level] $message" >&2
}

# Validate configuration
validate_config || {
    log "ERROR" "Configuration validation failed"
    exit 1
}

log "INFO" "Starting Local Whisper Transcriber"
log "INFO" "Watching folder: $WATCH_FOLDER"
log "INFO" "Archive folder: $ARCHIVE_FOLDER"
log "INFO" "Transcript folder: $TRANSCRIPT_FOLDER"
log "INFO" "Whisper model: $WHISPER_MODEL"

# Function to check if a file is complete (not being written to)
# Uses multiple methods to ensure file is truly complete
is_file_complete() {
    local file_path="$1"
    local max_wait=300  # Maximum 5 minutes wait
    local check_interval=5  # Check every 5 seconds
    local checks=$((max_wait / check_interval))
    
    log "INFO" "Waiting for file to complete: $(basename "$file_path")"

    for ((i=1; i<=checks; i++)); do
        if [[ ! -f "$file_path" ]]; then
            log "WARN" "File no longer exists: $file_path"
            return 1
        fi

        # Method 1: Check if file is open by any process (macOS)
        local open_count=$(lsof "$file_path" 2>/dev/null | grep -v COMMAND | wc -l | tr -d ' ')
        if [[ "$open_count" -gt 0 ]]; then
            log "DEBUG" "File still open by process (check $i/$checks)"
            sleep $check_interval
            continue
        fi

        # Method 2: Check file modification time (hasn't been modified in FILE_STABILITY_TIME seconds)
        if [[ "$(uname)" == "Darwin" ]]; then
            local mod_time=$(stat -f %m "$file_path" 2>/dev/null)
        else
            local mod_time=$(stat -c %Y "$file_path" 2>/dev/null)
        fi
        local current_time=$(date +%s)
        local time_diff=$((current_time - mod_time))
        
        if [[ $time_diff -lt $FILE_STABILITY_TIME ]]; then
            log "DEBUG" "File modified ${time_diff}s ago, waiting for ${FILE_STABILITY_TIME}s stability"
            sleep $check_interval
            continue
        fi

        # Both checks passed - file is complete
        log "INFO" "File confirmed complete: $(basename "$file_path")"
        return 0
    done

    log "ERROR" "File completion timeout after ${max_wait}s: $(basename "$file_path")"
    return 1
}

# Function to generate Markdown transcript
generate_markdown_transcript() {
    local input_file="$1"
    local output_file="$2"
    local filename=$(basename "$input_file" .mp3)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    log "DEBUG" "Generating Markdown transcript for: $input_file"

    cat > "$output_file" << EOF
# Audio Transcript: $filename

**File:** $filename.mp3
**Transcribed:** $timestamp
**Model:** $WHISPER_MODEL

## Transcript

EOF
}

# Function to transcribe an MP3 file
transcribe_file() {
    local input_file="$1"
    local filename=$(basename "$input_file" .mp3)
    local temp_transcript="/tmp/${filename}_transcript.txt"
    local markdown_file="$TRANSCRIPT_FOLDER/${filename}.md"

    log "INFO" "Starting transcription of: $filename.mp3"

    # Generate initial Markdown structure
    generate_markdown_transcript "$input_file" "$markdown_file"

    # Run whisper.cpp transcription
    # Note: whisper.cpp typically outputs to stdout, we'll capture it
    log "DEBUG" "Running whisper.cpp on: $input_file"

    # Build whisper command with optional flags
    local whisper_cmd="$WHISPER_CPP_PATH"
    local whisper_args=(
        "--model" "$WHISPER_MODEL_PATH"
        "--file" "$input_file"
        "--output-file" "$temp_transcript"
        "--language" "en"
        "--threads" "4"
    )

    # Add timestamp format
    if [[ "$ENABLE_TIMESTAMPS" == "true" ]]; then
        case "$TIMESTAMP_FORMAT" in
            "srt")
                whisper_args+=("--output-srt")
                ;;
            "vtt")
                whisper_args+=("--output-vtt")
                ;;
            *)
                whisper_args+=("--output-txt")
                ;;
        esac
    else
        whisper_args+=("--output-txt")
    fi

    if ! "$whisper_cmd" "${whisper_args[@]}" 2>/dev/null; then
        log "ERROR" "Whisper transcription failed for: $filename.mp3"
        rm -f "$temp_transcript"
        return 1
    fi

    # Check if transcription output exists (whisper-cli adds extension)
    local output_ext=".txt"
    if [[ "$ENABLE_TIMESTAMPS" == "true" ]]; then
        case "$TIMESTAMP_FORMAT" in
            "srt") output_ext=".srt" ;;
            "vtt") output_ext=".vtt" ;;
        esac
    fi

    if [[ -f "${temp_transcript}${output_ext}" ]]; then
        temp_transcript="${temp_transcript}${output_ext}"
    elif [[ ! -f "$temp_transcript" ]]; then
        log "ERROR" "No transcription output generated for: $filename.mp3"
        log "DEBUG" "Looked for: ${temp_transcript}${output_ext}"
        return 1
    fi

    # Perform speaker diarization if enabled
    local diarization_file="/tmp/${filename}_diarization.json"
    if [[ "$ENABLE_SPEAKER_DIARIZATION" == "true" ]] && command -v python3 &>/dev/null; then
        log "INFO" "Performing speaker diarization..."
        
        local diarize_script="$PROJECT_ROOT/diarize_speakers.py"
        if [[ ! -f "$diarize_script" ]]; then
            diarize_script="$SCRIPT_DIR/diarize_speakers.py"
        fi
        
        if [[ -f "$diarize_script" ]]; then
            local diarize_args=("$input_file" "$diarization_file")
            [[ -n "$MIN_SPEAKERS" ]] && diarize_args+=("$MIN_SPEAKERS")
            [[ -n "$MAX_SPEAKERS" ]] && diarize_args+=("$MAX_SPEAKERS")
            
            if python3 "$diarize_script" "${diarize_args[@]}" 2>&1 | tee -a /tmp/diarization.log; then
                log "INFO" "Speaker diarization completed"
            else
                log "WARN" "Speaker diarization failed, continuing without speaker labels"
                rm -f "$diarization_file"
            fi
        else
            log "WARN" "Diarization script not found, skipping speaker identification"
        fi
    fi

    # Merge transcript with speaker labels if diarization was successful
    if [[ -f "$diarization_file" ]]; then
        log "INFO" "Merging transcript with speaker labels..."
        local temp_merged="/tmp/${filename}_merged.txt"
        
        # Use Python to merge the transcript with speaker labels
        python3 -c "
import json
import sys

# Load diarization data
with open('$diarization_file', 'r') as f:
    diarization = json.load(f)

# Read transcript
with open('$temp_transcript', 'r') as f:
    transcript_lines = f.readlines()

# Simple merging: add speaker labels to transcript
# This is a basic implementation - could be improved with better alignment
print('## Transcript with Speaker Labels\n')
for segment in diarization['segments']:
    start_time = int(segment['start'])
    end_time = int(segment['end'])
    speaker = segment['speaker']
    print(f'**[{start_time//60:02d}:{start_time%60:02d} - {end_time//60:02d}:{end_time%60:02d}] {speaker}:**')
    print()

print('\n## Full Transcript\n')
for line in transcript_lines:
    print(line, end='')
" > "$temp_merged" 2>/dev/null || cat "$temp_transcript" > "$temp_merged"
        
        temp_transcript="$temp_merged"
    fi

    # Append transcript content to Markdown file
    echo "" >> "$markdown_file"
    cat "$temp_transcript" >> "$markdown_file"
    echo "" >> "$markdown_file"
    echo "---" >> "$markdown_file"
    echo "*Transcribed using Local Whisper Transcriber*" >> "$markdown_file"
    [[ "$ENABLE_SPEAKER_DIARIZATION" == "true" ]] && echo "*Speaker identification powered by pyannote.audio*" >> "$markdown_file"

    # Clean up temp files
    rm -f "$temp_transcript" "${temp_transcript}.txt" "${temp_transcript}.srt" "${temp_transcript}.vtt" "$diarization_file" "/tmp/${filename}_merged.txt" 2>/dev/null || true

    log "INFO" "Transcription completed: $filename.mp3 -> ${filename}.md"
    
    # Send macOS notification
    log "INFO" "Sending notification..."
    
    # Try multiple notification methods
    # Method 1: terminal-notifier (most reliable)
    local notifier_path="/opt/homebrew/bin/terminal-notifier"
    if [[ -x "$notifier_path" ]]; then
        "$notifier_path" \
            -title "Transcription Complete" \
            -message "Click to open: ${filename}.md" \
            -sound "Glass" \
            -group "whisper-transcriber" \
            -open "file://$TRANSCRIPT_FOLDER" \
            -activate "com.apple.finder" &
    fi
    
    # Method 2: Also try AppleScript as backup
    /usr/bin/osascript -e "display notification \"${filename}.md\" with title \"Transcription Complete\"" 2>/dev/null &
    
    # Method 3: Play sound to indicate completion
    /usr/bin/afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
}

# Function to process a new MP3 file
process_file() {
    local file_path="$1"

    # Wrap everything in error handling to prevent crashes
    {
        # Skip if not an MP3 file
        if [[ "${file_path##*.}" != "mp3" ]]; then
            return 0
        fi

        log "INFO" "New MP3 file detected: $(basename "$file_path")"

        # Wait for file to be complete
        if ! is_file_complete "$file_path"; then
            log "WARN" "Skipping incomplete file: $(basename "$file_path")"
            return 0
        fi

        local filename=$(basename "$file_path" .mp3)

        # Check if we've already processed this file
        if [[ -f "$TRANSCRIPT_FOLDER/${filename}.md" ]]; then
            log "INFO" "Transcript already exists, skipping: ${filename}.mp3"
            return 0
        fi

        # Transcribe the file
        if transcribe_file "$file_path"; then
            # Move original file to archive
            local archive_path="$ARCHIVE_FOLDER/$(basename "$file_path")"
            if mv "$file_path" "$archive_path" 2>/dev/null; then
                log "INFO" "Archived processed file: $(basename "$file_path")"
            else
                log "ERROR" "Failed to archive file: $(basename "$file_path")"
            fi
        else
            log "ERROR" "Transcription failed for: $(basename "$file_path")"
        fi
    } || {
        log "ERROR" "Unexpected error processing file: $(basename "$file_path" 2>/dev/null || echo "$file_path")"
        return 0
    }
}

# Function to process existing files in the watch folder
process_existing_files() {
    log "INFO" "Processing existing MP3 files in watch folder..."

    # Only process MP3 files directly in the watch folder, not in subdirectories
    find "$WATCH_FOLDER" -maxdepth 1 -name "*.mp3" -type f | while read -r file; do
        log "DEBUG" "Found existing file: $file"
        process_file "$file"
    done

    log "INFO" "Finished processing existing files"
}

# Create necessary directories
mkdir -p "$ARCHIVE_FOLDER"
mkdir -p "$TRANSCRIPT_FOLDER"

# Process any existing files first
process_existing_files

# Start watching the folder
log "INFO" "Starting folder monitoring with fswatch..."

# Function to check for unprocessed files periodically
check_unprocessed_files() {
    while true; do
        sleep 60  # Check every minute
        
        # Find MP3 files without corresponding transcripts (with error handling)
        {
            find "$WATCH_FOLDER" -maxdepth 1 -name "*.mp3" -type f 2>/dev/null | while read -r file; do
                filename=$(basename "$file" .mp3)
                if [[ ! -f "$TRANSCRIPT_FOLDER/${filename}.md" ]]; then
                    log "INFO" "Found unprocessed file: $(basename "$file")"
                    process_file "$file" || true
                fi
            done
        } || {
            log "ERROR" "Error in periodic file check, will retry in 60 seconds"
        }
    done
}

# Start background checker for unprocessed files
check_unprocessed_files &
CHECKER_PID=$!

# Trap to clean up background process on exit
trap "kill $CHECKER_PID 2>/dev/null" EXIT

# Watch for file system events (with automatic restart on failure)
while true; do
    log "INFO" "Starting fswatch monitoring..."
    
    "$FSWATCH_PATH" \
        --recursive \
        --event Created \
        --event Updated \
        --event MovedTo \
        "$WATCH_FOLDER" 2>&1 | while read -r event; do

        # fswatch outputs lines like: /path/to/file.mp3 Created
        file_path=$(echo "$event" | awk '{print $1}')
        event_type=$(echo "$event" | awk '{print $2}')

        log "DEBUG" "File event: $event_type on $file_path"

        # Process the file (with error handling)
        process_file "$file_path" || true
    done
    
    # If fswatch exits, log it and restart after a delay
    log "ERROR" "fswatch exited unexpectedly, restarting in 5 seconds..."
    sleep 5
done
