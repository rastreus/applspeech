#!/usr/bin/env bash
set -euo pipefail

# ralph-codex.sh — Optimized for minimal context pollution
# Focus: Compact context, JSON output, only essential info

# Add homebrew to PATH
export PATH="$HOME/homebrew/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
PROMPT_FILE="$SCRIPT_DIR/PROMPT.md"
SKILL_DIR="$SCRIPT_DIR/.agents/skills"

# Codex configuration - OPTIMIZED
CODEX_MODEL="${CODEX_MODEL:-gpt-5.3-codex}"
CODEX_OUTPUT_FILE="$SCRIPT_DIR/.ralph-codex-output.json"
CODEX_OUTPUTS_DIR="$SCRIPT_DIR/.codex-outputs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
log_success() { echo -e "${GREEN}✓ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠ ${NC}$1"; }
log_error() { echo -e "${RED}✗ ${NC}$1"; }
log_codex() { echo -e "${CYAN}🤖 ${NC}$1"; }

# Check prerequisites (minimal)
check_prerequisites() {
    for cmd in codex jq jj swift; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd not found"
            exit 1
        fi
    done
    log_success "Prerequisites OK"
}

get_next_story() {
    local story
    story=$(jq -r '.stories[] | select(.passes == false) | .id' "$PRD_FILE" | head -1)
    [ -z "$story" ] && return 1
    echo "$story"
}

show_story() {
    local id=$1
    local title desc
    title=$(jq -r ".stories[] | select(.id == \"$id\") | .title" "$PRD_FILE")
    desc=$(jq -r ".stories[] | select(.id == \"$id\") | .description" "$PRD_FILE")
    echo "  $id — $title"
    echo "  $desc"
}

# OPTIMIZED: Build COMPACT context
build_context_file() {
    local story_id=$1
    local ctx=$2
    
    # Compact header
    cat > "$ctx" << EOF
# applspeech Iteration

## Story: $story_id

EOF

    # Just the essentials from progress.txt (last 10 lines)
    cat >> "$ctx" << EOF
## Recent Progress
$(tail -10 "$PROGRESS_FILE" 2>/dev/null || echo "No progress yet")

EOF

    # Key patterns only (not full AGENTS.md)
    cat >> "$ctx" << EOF
## Key Patterns (§12)
$(grep -A50 "^## §12" "$AGENTS_FILE" | head -30 || echo "None yet")

EOF

    # Story details
    cat >> "$ctx" << EOF
## Assignment
$(jq -r ".stories[] | select(.id == \"$story_id\")" "$PRD_FILE")

EOF

    # Compact protocol reminder
    cat >> "$ctx" << 'EOF'

## Protocol
1. Orient: Read progress + patterns
2. Plan: TCR steps
3. Implement: jj desc → edit → swift build && swift test → jj new/jj restore
4. Verify: swift build -c release && swift test --verbose
5. Extract: Any discoveries? Update §12 and commit
6. Complete: prd.json passes=true, progress.txt, jj new

## Output
Respond with:
- TCR Plan (brief)
- Implementation (what changed, pass/fail)
- Discoveries (if any for §12)
- Completion (prd.json updated)

EOF
}

# OPTIMIZED: Use JSON output, suppress verbose streaming
invoke_codex() {
    local story_id=$1
    local ctx=$2
    
    log_codex "Running iteration: $story_id"
    
    mkdir -p "$CODEX_OUTPUTS_DIR"
    local ts=$(date +%s)
    
    # Use --json for structured output, redirect stderr to suppress noise
    codex exec \
        --full-auto \
        --model "$CODEX_MODEL" \
        --add-dir .git \
        --add-dir .jj \
        --add-dir "$HOME/.cache" \
        --json \
        -o "$CODEX_OUTPUT_FILE" \
        - < "$ctx" 2>/dev/null
    
    # Show just the final message, not full transcript
    if [ -f "$CODEX_OUTPUT_FILE" ]; then
        local final_msg
        final_msg=$(cat "$CODEX_OUTPUT_FILE")
        # Extract just the final assistant message from JSON if possible
        echo "$final_msg" | head -c 2000
        cp "$CODEX_OUTPUT_FILE" "$CODEX_OUTPUTS_DIR/${story_id}-${ts}.json"
    fi
}

# Check for AGENTS.md update (compounding)
check_discovery() {
    local story_id=$1
    if jj st 2>&1 | grep -q "AGENTS.md"; then
        log_success "Discovery captured"
        jj desc -m "docs(agents): compound $story_id"
        jj new
    fi
}

verify_completion() {
    local story_id=$1
    
    # Check prd.json
    local passes
    passes=$(jq -r ".stories[] | select(.id == \"$story_id\") | .passes" "$PRD_FILE")
    [ "$passes" != "true" ] && log_warning "prd.json not updated" && return 1
    
    # Verify build
    swift build && swift build -c release && swift test --verbose
}

run_iteration() {
    local story_id
    story_id=$(get_next_story) || { log_success "All done!"; return 0; }
    
    show_story "$story_id"
    
    local ctx
    ctx=$(mktemp -t "applspeech-ctx-XXXXXX")
    build_context_file "$story_id" "$ctx"
    
    log_info "Context: $(wc -l < "$ctx") lines (compact)"
    
    invoke_codex "$story_id" "$ctx"
    
    echo ""
    verify_completion "$story_id" && log_success "$story_id done" || log_error "$story_id failed"
    check_discovery "$story_id"
    
    rm -f "$ctx" "$CODEX_OUTPUT_FILE"
}

show_status() {
    local total complete
    total=$(jq '.stories | length' "$PRD_FILE")
    complete=$(jq '[.stories[] | select(.passes == true)] | length' "$PRD_FILE")
    echo "applspeech: $complete/$total complete"
    [ $((total - complete)) -gt 0 ] && show_story "$(get_next_story)"
}

main() {
    cd "$SCRIPT_DIR"
    check_prerequisites
    
    case "${1:-run}" in
        run) run_iteration ;;
        status) show_status ;;
        next) get_next_story ;;
        *) echo "Usage: $0 [run|status|next]" ;;
    esac
}

main "$@"
