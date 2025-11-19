#!/bin/bash

# Local Whisper Transcriber - Installer Script
# Automated setup for the complete transcription system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This installer is designed for macOS only."
        exit 1
    fi
    log_info "macOS detected: $(sw_vers -productVersion)"
}

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed"
    else
        log_info "Homebrew already installed"
    fi
}

# Install required dependencies
install_dependencies() {
    log_info "Installing dependencies..."

    # Update Homebrew (don't fail if this fails)
    if brew update; then
        log_info "Homebrew updated"
    else
        log_warn "Homebrew update failed - continuing anyway"
    fi

    # Install fswatch
    if ! brew list fswatch &> /dev/null; then
        log_info "Installing fswatch..."
        if brew install fswatch; then
            log_success "fswatch installed"
        else
            log_error "Failed to install fswatch"
            exit 1
        fi
    else
        log_info "fswatch already installed"
    fi

    # Install whisper.cpp
    if ! brew list whisper-cpp &> /dev/null; then
        log_info "Installing whisper.cpp..."
        if brew install whisper-cpp; then
            log_success "whisper.cpp installed"
        else
            log_error "Failed to install whisper-cpp"
            exit 1
        fi
    else
    log_info "whisper.cpp already installed"
fi

# Install terminal-notifier for notifications
log_info "Installing terminal-notifier for notifications..."
if ! brew list terminal-notifier &>/dev/null; then
    if brew install terminal-notifier 2>&1; then
        log_success "terminal-notifier installed"
    else
        log_warn "Failed to install terminal-notifier, notifications may not work"
    fi
else
    log_info "terminal-notifier already installed"
fi
}

# Download Whisper model files
download_whisper_models() {
    log_info "Downloading Whisper model files..."

    # Source config to get WHISPER_MODEL
    source "$SCRIPT_DIR/config.sh"

    # Create models directory if it doesn't exist
    MODELS_DIR="$HOME/.whisper"
    if ! mkdir -p "$MODELS_DIR"; then
        log_error "Failed to create models directory: $MODELS_DIR"
        exit 1
    fi
    log_info "Models directory: $MODELS_DIR"

    # Determine model filename based on WHISPER_MODEL
    case "$WHISPER_MODEL" in
        "base")
            MODEL_FILE="ggml-base.bin"
            MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
            ;;
        "small")
            MODEL_FILE="ggml-small.bin"
            MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
            ;;
        "medium")
            MODEL_FILE="ggml-medium.bin"
            MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"
            ;;
        "large")
            MODEL_FILE="ggml-large.bin"
            MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin"
            ;;
        *)
            log_error "Unknown Whisper model: $WHISPER_MODEL"
            log_info "Available models: base, small, medium, large"
            exit 1
            ;;
    esac

    MODEL_PATH="$MODELS_DIR/$MODEL_FILE"

    # Check if model already exists
    if [[ -f "$MODEL_PATH" ]]; then
        log_info "Whisper model $WHISPER_MODEL already downloaded"
    else
        log_info "Downloading $WHISPER_MODEL model (this may take a few minutes)..."
        if command -v curl &> /dev/null; then
            if ! curl -L -o "$MODEL_PATH" "$MODEL_URL"; then
                log_error "Failed to download model using curl"
                rm -f "$MODEL_PATH"
                exit 1
            fi
        elif command -v wget &> /dev/null; then
            if ! wget -O "$MODEL_PATH" "$MODEL_URL"; then
                log_error "Failed to download model using wget"
                rm -f "$MODEL_PATH"
                exit 1
            fi
        else
            log_error "Neither curl nor wget found. Please install one of them."
            exit 1
        fi
        log_success "Downloaded $WHISPER_MODEL model to $MODEL_PATH"
    fi

    # Update config with model path
    log_info "Updating config with model path: $MODEL_PATH"
    if ! sed -i.bak "s|^WHISPER_MODEL_PATH=.*|WHISPER_MODEL_PATH=\"$MODEL_PATH\"|" "$CONFIG_FILE"; then
        log_error "Failed to update WHISPER_MODEL_PATH in config"
        exit 1
    fi
    rm -f "${CONFIG_FILE}.bak"

    log_success "Whisper model configured"
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."

    # Default directories from config
    mkdir -p "$HOME/Recordings"
    mkdir -p "$HOME/Recordings/archive"
    mkdir -p "$HOME/Recordings/transcripts"

    log_success "Directories created"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# Update configuration with actual paths
update_config() {
    log_info "Updating configuration..."

    # Ensure Homebrew bin directory is in PATH
    HOMEBREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
    log_info "Homebrew prefix: $HOMEBREW_PREFIX"
    export PATH="$HOMEBREW_PREFIX/bin:$PATH"
    log_info "Updated PATH: $PATH"

    # Try to find executables directly first
    FSWATCH_PATH=""
    WHISPER_CPP_PATH=""

    # Check common Homebrew locations
    for prefix in "$HOMEBREW_PREFIX" "/usr/local" "/opt/homebrew"; do
        if [[ -x "$prefix/bin/fswatch" ]] && [[ -z "$FSWATCH_PATH" ]]; then
            FSWATCH_PATH="$prefix/bin/fswatch"
        fi
        if [[ -x "$prefix/bin/whisper-cli" ]] && [[ -z "$WHISPER_CPP_PATH" ]]; then
            WHISPER_CPP_PATH="$prefix/bin/whisper-cli"
        fi
    done

    # Fallback to which command
    if [[ -z "$FSWATCH_PATH" ]]; then
        FSWATCH_PATH=$(which fswatch 2>/dev/null || echo "")
    fi
    if [[ -z "$WHISPER_CPP_PATH" ]]; then
        WHISPER_CPP_PATH=$(which whisper-cli 2>/dev/null || echo "")
    fi

    if [[ -z "$FSWATCH_PATH" ]]; then
        log_error "Could not find fswatch executable"
        log_error "Checked locations: $HOMEBREW_PREFIX/bin/fswatch, /usr/local/bin/fswatch, /opt/homebrew/bin/fswatch"
        exit 1
    fi

    if [[ -z "$WHISPER_CPP_PATH" ]]; then
        log_error "Could not find whisper-cli executable"
        log_error "Checked locations: $HOMEBREW_PREFIX/bin/whisper-cli, /usr/local/bin/whisper-cli, /opt/homebrew/bin/whisper-cli"
        exit 1
    fi

    log_info "Found fswatch at: $FSWATCH_PATH"
    log_info "Found whisper-cli at: $WHISPER_CPP_PATH"

    # Update config.sh with actual paths
    if ! sed -i.bak "s|^FSWATCH_PATH=.*|FSWATCH_PATH=\"$FSWATCH_PATH\"|" "$CONFIG_FILE"; then
        log_error "Failed to update FSWATCH_PATH in config"
        exit 1
    fi

    if ! sed -i.bak "s|^WHISPER_CPP_PATH=.*|WHISPER_CPP_PATH=\"$WHISPER_CPP_PATH\"|" "$CONFIG_FILE"; then
        log_error "Failed to update WHISPER_CPP_PATH in config"
        exit 1
    fi

    if ! sed -i.bak "s|^PROJECT_ROOT=.*|PROJECT_ROOT=\"$SCRIPT_DIR\"|" "$CONFIG_FILE"; then
        log_error "Failed to update PROJECT_ROOT in config"
        exit 1
    fi

    # Remove backup file
    rm -f "${CONFIG_FILE}.bak"

    log_success "Configuration updated"
}

# Install scripts to permanent location
install_scripts() {
    log_info "Installing scripts to permanent location..."

    # Create installation directory
    INSTALL_DIR="$HOME/.local/bin/whisper-transcriber"
    mkdir -p "$INSTALL_DIR"

    # Copy scripts to permanent location
    cp "$SCRIPT_DIR/watch_and_transcribe.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/config.sh" "$INSTALL_DIR/"

    # Make scripts executable
    chmod +x "$INSTALL_DIR/watch_and_transcribe.sh"
    chmod +x "$INSTALL_DIR/config.sh"

    log_success "Scripts installed to: $INSTALL_DIR"
}

# Install LaunchAgent
install_launch_agent() {
    log_info "Installing LaunchAgent..."

    INSTALL_DIR="$HOME/.local/bin/whisper-transcriber"
    LAUNCH_AGENT_SRC="$SCRIPT_DIR/launch_agents/com.local.whisper.plist"
    LAUNCH_AGENT_TMP="$SCRIPT_DIR/com.local.whisper.plist.tmp"
    LAUNCH_AGENT_DST="$HOME/Library/LaunchAgents/com.local.whisper.plist"

    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$HOME/Library/LaunchAgents"

    log_info "Creating LaunchAgent plist from: $LAUNCH_AGENT_SRC"
    log_info "Installing to: $LAUNCH_AGENT_DST"

    # Update the plist with actual paths (pointing to permanent installation)
    if ! sed "s|/path/to/watch_and_transcribe.sh|$INSTALL_DIR/watch_and_transcribe.sh|g; s|/path/to/project|$INSTALL_DIR|g" "$LAUNCH_AGENT_SRC" > "$LAUNCH_AGENT_TMP"; then
        log_error "Failed to create temporary LaunchAgent plist"
        return 1
    fi

    # Verify the temp file was created
    if [[ ! -f "$LAUNCH_AGENT_TMP" ]]; then
        log_error "Temporary LaunchAgent plist was not created"
        return 1
    fi

    # Copy to destination
    if ! cp "$LAUNCH_AGENT_TMP" "$LAUNCH_AGENT_DST"; then
        log_error "Failed to copy LaunchAgent plist to: $LAUNCH_AGENT_DST"
        rm -f "$LAUNCH_AGENT_TMP"
        return 1
    fi

    # Remove extended attributes that might cause issues
    xattr -c "$LAUNCH_AGENT_DST" 2>/dev/null || true

    # Clean up temp file
    rm -f "$LAUNCH_AGENT_TMP"

    # Verify the destination file exists
    if [[ ! -f "$LAUNCH_AGENT_DST" ]]; then
        log_error "LaunchAgent plist was not created at: $LAUNCH_AGENT_DST"
        return 1
    fi

    log_success "LaunchAgent installed to: $LAUNCH_AGENT_DST"
}

# Load and start the LaunchAgent
start_service() {
    log_info "Starting transcription service..."

    LAUNCH_AGENT_DST="$HOME/Library/LaunchAgents/com.local.whisper.plist"
    DOMAIN="gui/$(id -u)"

    # Try to bootout if already loaded (modern macOS)
    log_info "Removing any existing LaunchAgent..."
    launchctl bootout "$DOMAIN/com.local.whisper" 2>/dev/null || true

    # Bootstrap the LaunchAgent (modern macOS)
    log_info "Loading LaunchAgent with bootstrap..."
    if launchctl bootstrap "$DOMAIN" "$LAUNCH_AGENT_DST" 2>&1 | tee /tmp/launchctl_bootstrap.log; then
        log_success "LaunchAgent bootstrapped successfully"
    else
        log_warn "Bootstrap may have failed, trying legacy load method..."
        # Fallback to legacy load method
        if launchctl load "$LAUNCH_AGENT_DST" 2>&1; then
            log_success "LaunchAgent loaded with legacy method"
        else
            log_error "Failed to load LaunchAgent with both methods"
            log_info "Check /tmp/launchctl_bootstrap.log for details"
            return 1
        fi
    fi

    # Give it a moment to start
    sleep 3

    # Verify it's running
    if launchctl list | grep -q "com.local.whisper"; then
        log_success "LaunchAgent is running"
    else
        log_warn "LaunchAgent may not be running yet"
        log_info "Check logs: tail -f /tmp/local-whisper.error.log"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    # Check if executables exist
    if [[ ! -x "$FSWATCH_PATH" ]]; then
        log_error "fswatch not found at: $FSWATCH_PATH"
        return 1
    fi

    if [[ ! -x "$WHISPER_CPP_PATH" ]]; then
        log_error "whisper-cpp not found at: $WHISPER_CPP_PATH"
        return 1
    fi

    # Check if directories exist
    if [[ ! -d "$HOME/Recordings" ]]; then
        log_error "Watch directory not created"
        return 1
    fi

    if [[ ! -d "$HOME/Recordings/archive" ]]; then
        log_error "Archive directory not created"
        return 1
    fi

    if [[ ! -d "$HOME/Recordings/transcripts" ]]; then
        log_error "Transcripts directory not created"
        return 1
    fi

    # Check if service is actually running by checking logs
    local max_retries=5
    local retry_count=0
    local service_running=false

    log_info "Checking if transcription service started..."

    while [[ $retry_count -lt $max_retries ]]; do
        # Check if the service has written to the log file
        if [[ -f "/tmp/local-whisper.error.log" ]] && grep -q "Starting folder monitoring with fswatch" "/tmp/local-whisper.error.log" 2>/dev/null; then
            service_running=true
            break
        fi
        ((retry_count++))
        if [[ $retry_count -lt $max_retries ]]; then
            log_info "Waiting for service to start... (attempt $retry_count/$max_retries)"
            sleep 2
        fi
    done

    if [[ "$service_running" == "true" ]]; then
        log_success "Transcription service is running!"
        log_info "Service logs: /tmp/local-whisper.error.log"
        log_info "Drop MP3 files into: $HOME/Recordings"
        log_info "Transcripts will appear in: $HOME/Recordings/transcripts"
    else
        log_warn "Could not verify service started from logs"
        log_info "Check manually: tail -f /tmp/local-whisper.error.log"
        log_info "Check LaunchAgent: launchctl list | grep whisper"
    fi

    log_success "Installation completed successfully"
    return 0
}

# Main installation process
main() {
    log_info "Starting Local Whisper Transcriber installation..."
    echo

    check_macos
    check_homebrew
    install_dependencies
    download_whisper_models
    create_directories
    update_config
    install_scripts
    install_launch_agent
    start_service

    echo
    if verify_installation; then
        echo
        log_success "Installation completed successfully!"
        echo
        log_info "The transcription service is now running and will:"
        log_info "  - Monitor: $HOME/Recordings"
        log_info "  - Archive to: $HOME/Recordings/archive"
        log_info "  - Output transcripts to: $HOME/Recordings/transcripts"
        echo
        log_info "Drop MP3 files into the Recordings folder to start transcribing!"
        log_info "View logs at: /tmp/local-whisper.log"
    else
        log_error "Installation verification failed. Please check the errors above."
        exit 1
    fi
}

# Run main installation
main "$@"
