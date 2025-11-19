# Local Whisper Transcriber

A fully local, lightweight, automated transcription system for MP3 recordings that runs entirely on your macOS machine using OpenAI's Whisper model.

## Features

- 🏠 **Fully Local**: No cloud uploads, everything runs on your machine
- 👀 **Automatic Monitoring**: Watches a folder for new MP3 recordings
- ⚡ **Real-time Processing**: Transcribes files as soon as recording is complete
- 📝 **Markdown Output**: Generates clean Markdown transcripts
- ⏱️ **Timestamps & Speakers**: Optional timestamps and speaker diarization
- 🔔 **macOS Notifications**: Get notified when transcriptions complete
- 🔄 **Auto-archiving**: Moves processed files to archive folder
- 🔋 **Low Resource Usage**: Minimal CPU usage when idle
- 🚀 **Auto-start**: Runs automatically at login via macOS LaunchAgent
- 🛡️ **Rock-Solid**: Automatic error recovery and restart on failures
- 🎯 **VS Code Integration**: Designed for seamless analysis with GitHub Copilot

## Quick Start

### 1. Install

Run the automated installer:

```bash
git clone <repository-url>
cd local-whisper-transcriber
chmod +x install.sh
./install.sh
```

The installer will:
- Install Homebrew (if needed)
- Install `fswatch`, `whisper.cpp`, and `terminal-notifier`
- Download the selected Whisper model (may take several minutes)
- **Install scripts to `~/.local/bin/whisper-transcriber/`** (permanent location)
- Create required directories (`~/Recordings`, `~/Recordings/archive`, `~/Recordings/transcripts`)
- Configure the system with timestamps and speaker detection
- Install and start the macOS LaunchAgent service
- Verify everything is working

**After installation, you can safely delete the project directory** - all scripts are installed to a permanent location.

### 2. Start Transcribing

Simply drop MP3 files into your `~/Recordings` folder. The system will automatically:
1. Detect the new file instantly (via fswatch)
2. Wait for the recording to complete (file stability check)
3. Transcribe using Whisper with timestamps and speaker detection
4. **Send you a notification** when complete
5. **Click the notification** to open the transcripts folder
6. Save the transcript as Markdown in `~/Recordings/transcripts/`
7. Move the MP3 to `~/Recordings/archive/`

### 3. Get Notified & View Transcripts

When transcription completes:
- 🔔 You'll receive a **macOS notification**
- 🔊 You'll hear a **Glass sound**
- 👆 **Click the notification** to open the transcripts folder in Finder
- 📝 Transcripts appear as Markdown files in `~/Recordings/transcripts/`

**First-time notification setup:** The first time you get a notification, macOS will ask for permission. Click "Allow" to enable notifications.

## Requirements

- **macOS** (Apple Silicon recommended)
- **Homebrew** (installed automatically if missing)
- **4GB+ RAM** (for medium Whisper model)
- **MP3 recordings** (other formats not supported)

## Installation Details

### Automated Installation

The `install.sh` script handles everything automatically. It installs:

- `fswatch`: Folder monitoring utility (event-driven file detection)
- `whisper.cpp`: Local Whisper implementation (AI transcription)
- `terminal-notifier`: macOS notification utility (completion alerts)

### Manual Installation

If you prefer manual setup:

1. Install dependencies:
   ```bash
   brew install fswatch whisper-cpp terminal-notifier
   ```

2. Create directories:
   ```bash
   mkdir -p ~/Recordings ~/Recordings/archive ~/Projects/my-vscode-repo/transcripts
   ```

3. Configure paths in `config.sh`

4. Install LaunchAgent:
   ```bash
   cp launch_agents/com.local.whisper.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.local.whisper.plist
   ```

## Configuration

Edit `config.sh` to customize:

```bash
# Folder paths
WATCH_FOLDER="$HOME/Recordings"           # Monitor this folder
ARCHIVE_FOLDER="$HOME/Recordings/archive" # Move processed files here
TRANSCRIPT_FOLDER="$HOME/Recordings/transcripts" # Output location

# Whisper model (base/small/medium/large)
WHISPER_MODEL="base"                      # Smaller = faster, larger = more accurate

# File detection
FILE_STABILITY_TIME=2                     # Seconds to wait before processing

# Transcription options
ENABLE_TIMESTAMPS=true                    # Include timestamps in transcript
ENABLE_DIARIZATION=true                   # Enable speaker detection (stereo audio only)
TIMESTAMP_FORMAT="srt"                    # Format: srt, vtt, or txt
```

### Transcription Features

#### Timestamps
When `ENABLE_TIMESTAMPS=true`, transcripts include timing information:
- **srt**: SubRip format with numbered segments and timestamps (e.g., `00:01:23,456 --> 00:01:25,789`)
- **vtt**: WebVTT format for web video players
- **txt**: Plain text without timestamps

#### Speaker Diarization
When `ENABLE_DIARIZATION=true`, the system attempts to identify different speakers:
- **Requirements**: Stereo audio with speakers on separate channels
- **Output**: Labels speakers as "Speaker 0", "Speaker 1", etc.
- **Note**: Works best with recordings where each speaker is on a dedicated audio channel

**Example with timestamps and speakers:**
```
1
00:00:00,000 --> 00:00:03,500
[Speaker 0] Welcome to today's meeting.

2
00:00:03,500 --> 00:00:07,200
[Speaker 1] Thanks for having me. Let's discuss the project.
```

### Whisper Models

| Model | Size | Download | Accuracy | Speed |
|-------|------|----------|----------|-------|
| **base** | ~75MB | Fast | Good | Fastest |
| **small** | ~250MB | Medium | Better | Fast |
| **medium** | ~500MB | Slow | High | Medium |
| **large** | ~1GB | Slowest | Best | Slowest |

*Download times depend on your internet connection*

## How It Works

### File Detection
The system uses `fswatch` to monitor the watch folder for new files. When an MP3 is detected, it waits for the file to stabilize (no changes for `FILE_STABILITY_TIME` seconds) before processing. This ensures recordings are complete before transcription begins.

### Transcription Process
1. **Input**: MP3 file in watch folder
2. **Processing**: `whisper.cpp` transcribes audio to text
3. **Output**: Markdown file with transcript
4. **Archiving**: Original MP3 moved to archive folder

### Markdown Format
Transcripts are saved as clean Markdown:

```markdown
# Audio Transcript: meeting_notes

**File:** meeting_notes.mp3
**Transcribed:** 2024-01-15 14:30:22
**Model:** base

## Transcript

[Full transcription text here]

---
*Transcribed using Local Whisper Transcriber*
```

## Monitoring & Logs

### Service Status
Check if the service is running:
```bash
launchctl list | grep com.local.whisper
```

### View Logs
```bash
tail -f /tmp/local-whisper.log
tail -f /tmp/local-whisper.error.log
```

### Restart Service
```bash
launchctl unload ~/Library/LaunchAgents/com.local.whisper.plist
launchctl load ~/Library/LaunchAgents/com.local.whisper.plist
```

## Troubleshooting

### Service Not Starting
1. Check logs: `cat /tmp/local-whisper.error.log`
2. Verify dependencies: `which fswatch whisper-cpp`
3. Check LaunchAgent: `launchctl list com.local.whisper`

### Transcription Failing
1. Verify MP3 file integrity
2. Check available disk space
3. Try smaller Whisper model in config
4. Check logs for specific errors

### High CPU Usage
- The service should be idle when no files are being processed
- If constantly using CPU, check for file system issues
- Restart the service: `launchctl unload/load`

### Files Not Processing
- Ensure MP3 files are placed directly in watch folder (not in subdirectories)
- Check file permissions (files must be readable)
- Verify file isn't still being written to (system waits for file stability)
- Check logs for processing messages: `tail -f /tmp/local-whisper.error.log`

### Notifications Not Appearing

If you don't receive notifications:

1. **Check notification permissions:**
   - Go to System Settings → Notifications
   - Look for "terminal-notifier" in the list
   - Ensure "Allow Notifications" is enabled

2. **Check Focus/Do Not Disturb:**
   - Notifications may be silenced by Focus mode
   - Check the Control Center for active Focus modes

3. **Verify terminal-notifier is installed:**
   ```bash
   which terminal-notifier
   # Should output: /opt/homebrew/bin/terminal-notifier
   ```

4. **Test manually:**
   ```bash
   terminal-notifier -title "Test" -message "Testing notifications"
   ```

5. **Check the logs:**
   ```bash
   tail -f /tmp/local-whisper.error.log
   # Look for "Sending notification..." message
   ```

**Note:** You should at least hear the Glass sound even if visual notifications don't appear.

## Project Structure

### Source Repository
```
local-whisper-transcriber/
├── README.md                    # This file
├── install.sh                   # Automated installer
├── uninstall.sh                 # Uninstaller
├── watch_and_transcribe.sh      # Main monitoring script (template)
├── config.sh                    # Configuration settings (template)
└── launch_agents/
    └── com.local.whisper.plist  # macOS LaunchAgent configuration (template)
```

### Installed Location (after running install.sh)
```
~/.local/bin/whisper-transcriber/
├── watch_and_transcribe.sh      # Main monitoring script
└── config.sh                    # Configuration with actual paths

~/Library/LaunchAgents/
└── com.local.whisper.plist      # LaunchAgent (points to installed scripts)

~/.whisper/
└── ggml-base.bin                # Downloaded Whisper model

~/Recordings/
├── archive/                     # Processed MP3s moved here
├── transcripts/                 # Generated transcripts appear here
└── [your MP3 files]
```

## Development

### Local Testing
Run the script manually for testing:
```bash
./watch_and_transcribe.sh
```

### Modifying Configuration
Edit `config.sh` and restart the service.

### Adding Features
- Modify `watch_and_transcribe.sh` for new functionality
- Update `config.sh` for new settings
- Test changes locally before redeploying

## Security & Privacy

- ✅ **No cloud uploads**: Everything stays local
- ✅ **No data collection**: No telemetry or external communication
- ✅ **File isolation**: Processed files moved to archive
- ✅ **Local models**: Whisper runs entirely on device

## Performance Notes

- **Base model**: ~10-15 seconds per minute of audio
- **Small model**: ~20-30 seconds per minute
- **Medium model**: ~40-60 seconds per minute
- **Large model**: ~80-120 seconds per minute

Processing time depends on:
- Audio length and quality
- CPU performance (Apple Silicon recommended)
- Available RAM
- Whisper model size

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. See LICENSE file for details.

## Support

- Check the logs: `/tmp/local-whisper.log`
- Verify configuration in `config.sh`
- Test with a small MP3 file first
- Ensure adequate free disk space (>2x MP3 file size)

---

**Happy transcribing! 🎙️➡️📝**
