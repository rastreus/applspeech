#!/usr/bin/env bash
set -euo pipefail

# ralph-codex-chunked.sh — Run S02 in smaller memory-friendly chunks
# Each chunk is a focused task that completes quickly

# Add homebrew, pnpm, node and nvm to PATH
export PATH="$HOME/homebrew/bin:$HOME/Library/pnpm:$HOME/.nvm/versions/node/v24.13.1/bin:$HOME/.pnpm/global/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.3-codex}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
log_success() { echo -e "${GREEN}✓ ${NC}$1"; }
log_error() { echo -e "${RED}✗ ${NC}$1"; }

# Chunk definitions - each is a focused task
# S02 chunks (complete)
CHUNK1_TASK="Implement SpeechFileTranscriber.swift - the actual transcription logic using SpeechTranscriber + SpeechAnalyzer APIs"
CHUNK2_TASK="Wire transcribe command into ApplSpeech.swift using CommandParser"
CHUNK3_TASK="Add tests for transcription and verify build passes"

# S03 chunks (JSON output)
S03_CHUNK1_TASK="Add --format json flag and implement JSON output for transcribe command"
S03_CHUNK2_TASK="Add tests for JSON output format"

# S05 chunks (URL transcription)
S05_CHUNK1_TASK="Add URL detection and download logic for remote audio files"
S05_CHUNK2_TASK="Add network error handling and tests for URL transcription"

# S06 chunks (Telegram source)
S06_CHUNK1_TASK="Add Telegram audio source support for downloading voice messages"

# S07 chunks (stdin pipe)
S07_CHUNK1_TASK="Add stdin/pipe support for audio input"

# S08 chunks (SpeechAnalyzer)
S08_CHUNK1_TASK="Add SpeechAnalyzer voice analysis output"

# S09 chunks (CLI polish)
S09_CHUNK1_TASK="CLI polish - version, verbose, config file support"

show_chunks() {
    echo "Available chunks for S02-transcribe-file:"
    echo "  1: $CHUNK1_TASK"
    echo "  2: $CHUNK2_TASK"
    echo "  3: $CHUNK3_TASK"
    echo ""
    echo "Available chunks for S03-json-output:"
    echo "  s01: $S03_CHUNK1_TASK"
    echo "  s02: $S03_CHUNK2_TASK"
    echo ""
    echo "Available chunks for S05-url-transcription:"
    echo "  u01: $S05_CHUNK1_TASK"
    echo "  u02: $S05_CHUNK2_TASK"
    echo ""
    echo "Available chunks for S06-telegram-source:"
    echo "  t01: $S06_CHUNK1_TASK"
    echo ""
    echo "Available chunks for S07-stdin-pipe:"
    echo "  p01: $S07_CHUNK1_TASK"
    echo ""
    echo "Available chunks for S08-speechanalyzer:"
    echo "  a01: $S08_CHUNK1_TASK"
    echo ""
    echo "Available chunks for S09-cli-polish:"
    echo "  z01: $S09_CHUNK1_TASK"
}

get_chunk_task() {
    case $1 in
        1) echo "$CHUNK1_TASK" ;;
        2) echo "$CHUNK2_TASK" ;;
        3) echo "$CHUNK3_TASK" ;;
        s01) echo "$S03_CHUNK1_TASK" ;;
        s02) echo "$S03_CHUNK2_TASK" ;;
        u01) echo "$S05_CHUNK1_TASK" ;;
        u02) echo "$S05_CHUNK2_TASK" ;;
        t01) echo "$S06_CHUNK1_TASK" ;;
        p01) echo "$S07_CHUNK1_TASK" ;;
        a01) echo "$S08_CHUNK1_TASK" ;;
        z01) echo "$S09_CHUNK1_TASK" ;;
        *) echo "" ;;
    esac
}

run_chunk() {
    local chunk=$1
    local task
    task=$(get_chunk_task "$chunk")
    
    [ -z "$task" ] && log_error "Unknown chunk: $chunk" && exit 1
    
    # Determine story prefix
    local story
    case $chunk in
        s01|s02) story="S03" ;;
        u01|u02) story="S05" ;;
        t01) story="S06" ;;
        p01) story="S07" ;;
        a01) story="S08" ;;
        z01) story="S09" ;;
        *) story="S02" ;;
    esac
    
    log_info "Running chunk $chunk: $task"
    
    # Build minimal context
    local ctx
    ctx=$(mktemp -t "applspeech-chunk-$chunk-XXXXXX")
    
    cat > "$ctx" << EOF
# applspeech Chunk $chunk

## Task
$task

## Constraints
- TCR: edit → build → test → commit
- Use --disable-sandbox for swift build/test
- Keep changes focused and small
- Commit after each successful step

## Current Files (already exist)
- Sources/ApplSpeech/ApplSpeech.swift (main entry, needs updating)
- Sources/ApplSpeech/Commands/CommandParser.swift (parsing, returns ApplSpeechCommand)
- Sources/ApplSpeech/Transcription/FileTranscribing.swift (protocol only)
- Sources/ApplSpeech/Transcription/SupportedAudioFormat.swift
- Sources/ApplSpeech/Transcription/TranscriptionError.swift
- Sources/ApplSpeech/Transcription/SpeechAuthorization.swift
- Tests/ApplSpeechTests/CommandParserTests.swift
- Tests/ApplSpeechTests/CLIHelpTests.swift

## Key API (Speech framework, macOS 26.0+)
SpeechTranscriber(locale:locale, preset:.transcription) 
SpeechAnalyzer(inputAudioFile:modules:finishAfterFile:)
transcriber.results is an AsyncSequence of SpeechTranscriber.Result
Result.text is AttributedString, convert to String

## Protocol
1. Read relevant existing files
2. Make focused change
3. swift build --disable-sandbox
4. swift test --disable-sandbox
5. jj desc -m "chore($story): $task"
6. jj new

## Output
Report: what you changed, build/test result, commit hash
EOF

    log_info "Context: $(wc -l < "$ctx") lines"
    
    # Run Codex with the chunk task (show errors)
    # Note: reasoning effort set in ~/.codex/config.toml (currently "high")
    codex exec --full-auto --model "$CODEX_MODEL" --add-dir .git --add-dir "$HOME/.cache" - < "$ctx" 2>&1
    
    local result=$?
    rm -f "$ctx"
    
    if [ $result -eq 0 ]; then
        log_success "Chunk $chunk completed"
    else
        log_error "Chunk $chunk failed (exit $result)"
    fi
    
    return $result
}

main() {
    cd "$SCRIPT_DIR"
    
    case "${1:-}" in
        1|2|3) run_chunk "$1" ;;
        s01|s02) run_chunk "$1" ;;
        u01|u02) run_chunk "$1" ;;
        t01) run_chunk "$1" ;;
        p01) run_chunk "$1" ;;
        a01) run_chunk "$1" ;;
        z01) run_chunk "$1" ;;
        list) show_chunks ;;
        *) echo "Usage: $0 [1|2|3|s01|s02|u01|u02|t01|p01|a01|z01|list]"
           echo ""
           show_chunks
           ;;
    esac
}

main "$@"
