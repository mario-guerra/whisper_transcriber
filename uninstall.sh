#!/bin/bash

# Local Whisper Transcriber - Uninstaller Script
# Completely removes the transcription system and all installed components

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Stop and unload LaunchAgent
stop_service() {
    log_info "Stopping transcription service..."

    # Unload LaunchAgent if loaded
    if launchctl list | grep -q "com.local.whisper"; then
        launchctl unload "$HOME/Library/LaunchAgents/com.local.whisper.plist" 2>/dev/null || true
        log_success "LaunchAgent unloaded"
    else
        log_info "LaunchAgent not currently loaded"
    fi
}

# Remove LaunchAgent
remove_launch_agent() {
    log_info "Removing LaunchAgent..."

    LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/com.local.whisper.plist"
    if [[ -f "$LAUNCH_AGENT_PATH" ]]; then
        rm -f "$LAUNCH_AGENT_PATH"
        log_success "LaunchAgent plist removed"
    else
        log_info "LaunchAgent plist not found"
    fi
}

# Remove created directories and files
remove_directories() {
    log_info "Removing created directories..."

    # Remove transcript and archive directories (but keep Recordings folder)
    if [[ -d "$HOME/Recordings/archive" ]]; then
        rm -rf "$HOME/Recordings/archive"
        log_success "Archive directory removed"
    fi

    if [[ -d "$HOME/Recordings/transcripts" ]]; then
        rm -rf "$HOME/Recordings/transcripts"
        log_success "Transcripts directory removed"
    fi

    # Remove installed scripts
    if [[ -d "$HOME/.local/bin/whisper-transcriber" ]]; then
        rm -rf "$HOME/.local/bin/whisper-transcriber"
        log_success "Installed scripts removed"
    fi
}

# Remove downloaded Whisper models
remove_models() {
    log_info "Removing downloaded Whisper models..."

    MODELS_DIR="$HOME/.whisper"
    if [[ -d "$MODELS_DIR" ]]; then
        rm -rf "$MODELS_DIR"
        log_success "Whisper models directory removed"
    else
        log_info "No Whisper models directory found"
    fi
}

# Reset configuration file
reset_config() {
    log_info "Resetting configuration file..."

    CONFIG_FILE="$SCRIPT_DIR/config.sh"

    # Reset all the paths that get set by installer
    sed -i.bak 's|^WHISPER_CPP_PATH=.*|WHISPER_CPP_PATH=""|' "$CONFIG_FILE"
    sed -i.bak 's|^FSWATCH_PATH=.*|FSWATCH_PATH=""|' "$CONFIG_FILE"
    sed -i.bak 's|^WHISPER_MODEL_PATH=.*|WHISPER_MODEL_PATH=""|' "$CONFIG_FILE"
    sed -i.bak 's|^PROJECT_ROOT=.*|PROJECT_ROOT=""|' "$CONFIG_FILE"

    # Remove backup file
    rm -f "${CONFIG_FILE}.bak"

    log_success "Configuration reset to defaults"
}

# Remove log files
remove_logs() {
    log_info "Removing log files..."

    if [[ -f "/tmp/local-whisper.log" ]]; then
        rm -f "/tmp/local-whisper.log"
        log_success "Main log file removed"
    fi

    if [[ -f "/tmp/local-whisper.error.log" ]]; then
        rm -f "/tmp/local-whisper.error.log"
        log_success "Error log file removed"
    fi
}

# Optionally uninstall Homebrew packages
uninstall_packages() {
    log_warn "Do you want to uninstall Homebrew packages (fswatch, whisper-cpp)?"
    read -p "This will remove them system-wide. Continue? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstalling Homebrew packages..."

        if brew list fswatch &> /dev/null; then
            brew uninstall fswatch
            log_success "fswatch uninstalled"
        fi

        if brew list whisper-cpp &> /dev/null; then
            brew uninstall whisper-cpp
            log_success "whisper-cpp uninstalled"
        fi

        if brew list terminal-notifier &> /dev/null; then
            brew uninstall terminal-notifier
            log_success "terminal-notifier uninstalled"
        fi
    else
        log_info "Keeping Homebrew packages installed"
    fi
}

# Verify uninstallation
verify_uninstallation() {
    log_info "Verifying uninstallation..."

    local errors=0

    # Check LaunchAgent
    if launchctl list | grep -q "com.local.whisper"; then
        log_error "LaunchAgent still loaded"
        ((errors++))
    fi

    if [[ -f "$HOME/Library/LaunchAgents/com.local.whisper.plist" ]]; then
        log_error "LaunchAgent plist still exists"
        ((errors++))
    fi

    # Check directories
    if [[ -d "$HOME/Recordings/archive" ]]; then
        log_error "Archive directory still exists"
        ((errors++))
    fi

    if [[ -d "$HOME/Recordings/transcripts" ]]; then
        log_error "Transcripts directory still exists"
        ((errors++))
    fi

    # Check installed scripts
    if [[ -d "$HOME/.local/bin/whisper-transcriber" ]]; then
        log_error "Installed scripts directory still exists"
        ((errors++))
    fi

    # Check models
    if [[ -d "$HOME/.whisper" ]]; then
        log_error "Whisper models directory still exists"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "Uninstallation completed successfully!"
        return 0
    else
        log_error "Some components may still be installed ($errors issues found)"
        return 1
    fi
}

# Main uninstallation process
main() {
    log_warn "This will completely remove the Local Whisper Transcriber system."
    log_warn "This includes stopping services, removing files, and resetting configuration."
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled."
        exit 0
    fi

    echo
    log_info "Starting Local Whisper Transcriber uninstallation..."
    echo

    stop_service
    remove_launch_agent
    remove_directories
    remove_models
    reset_config
    remove_logs
    uninstall_packages

    echo
    if verify_uninstallation; then
        echo
        log_success "System completely removed!"
        log_info "You can now run ./install.sh to reinstall with the latest version."
    else
        log_error "Uninstallation may be incomplete. Please check the errors above."
    fi
}

# Run main uninstallation
main "$@"
