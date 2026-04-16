#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                              ║
# ║                    KNOWLEDGE RAG — INSTALLER v2.0                            ║
# ║          Local Semantic Search for Claude Code (FastEmbed)                   ║
# ║                                                                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# Installs and configures knowledge-rag with ChromaDB, FastEmbed,
# hybrid search (BM25 + semantic), and MCP integration for Claude Code.
#
# Platform: Linux / macOS
# Requires: Python 3.11 or 3.12, internet connection, ~500MB disk
#
# Usage:
#   ./install.sh                    # Full installation (pip from PyPI)
#   ./install.sh --from-source      # Install from cloned repo
#   ./install.sh --install-path /opt/knowledge-rag
#   ./install.sh --force            # Recreate venv
#
# By Lyon. :) Legal Ne?

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

PYTHON_MIN_VERSION="3.11"
PYTHON_MAX_VERSION="3.13"
EMBEDDING_MODEL="BAAI/bge-small-en-v1.5"
REQUIREMENTS_FILE="requirements.txt"

# Defaults (overridable via flags)
INSTALL_PATH="$HOME/knowledge-rag"
FROM_SOURCE=0
FORCE=0

# ============================================================================
# COLOR HELPERS
# ============================================================================

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${CYAN}[*]${RESET} $1"; }
ok()    { echo -e "${GREEN}[+]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $1"; }
err()   { echo -e "${RED}[-]${RESET} $1"; }
step()  { echo -e "\n${YELLOW}=== $1 ===${RESET}"; }

# ============================================================================
# CLEANUP TRAP
# ============================================================================

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        err "Installation failed (exit code: $exit_code)"
        err "Check the error above and try again."
        echo ""
    fi
    exit $exit_code
}

trap cleanup EXIT

# ============================================================================
# BANNER
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "    ╔═══════════════════════════════════════════════════════════════════╗"
    echo "    ║                                                                   ║"
    echo "    ║   ██╗  ██╗███╗   ██╗ ██████╗ ██╗    ██╗██╗     ███████╗██████╗    ║"
    echo "    ║   ██║ ██╔╝████╗  ██║██╔═══██╗██║    ██║██║     ██╔════╝██╔══██╗   ║"
    echo "    ║   █████╔╝ ██╔██╗ ██║██║   ██║██║ █╗ ██║██║     █████╗  ██║  ██║   ║"
    echo "    ║   ██╔═██╗ ██║╚██╗██║██║   ██║██║███╗██║██║     ██╔══╝  ██║  ██║   ║"
    echo "    ║   ██║  ██╗██║ ╚████║╚██████╔╝╚███╔███╔╝███████╗███████╗██████╔╝   ║"
    echo "    ║   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝ ╚══════╝╚══════╝╚═════╝    ║"
    echo "    ║                                                                   ║"
    echo "    ║                    RAG SYSTEM INSTALLER v2.0                      ║"
    echo "    ║         Local Semantic Search for Claude Code (FastEmbed)         ║"
    echo "    ║                                                                   ║"
    echo "    ╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ============================================================================
# USAGE / HELP
# ============================================================================

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --from-source          Install from cloned repo (requires requirements.txt)"
    echo "  --install-path PATH    Custom install directory (default: ~/knowledge-rag)"
    echo "  --force                Recreate virtual environment from scratch"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                     # pip install from PyPI"
    echo "  $0 --from-source                       # Install from local source"
    echo "  $0 --install-path /opt/knowledge-rag   # Custom path"
    echo "  $0 --force                             # Recreate venv"
    exit 0
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

while [ $# -gt 0 ]; do
    case "$1" in
        --from-source)
            FROM_SOURCE=1
            shift
            ;;
        --install-path)
            if [ -z "$2" ] || [[ "$2" == --* ]]; then
                err "--install-path requires a directory path"
                exit 1
            fi
            INSTALL_PATH="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            err "Unknown option: $1"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
done

# ============================================================================
# PYTHON DETECTION
# ============================================================================

find_python() {
    step "PYTHON DETECTION"

    local candidates=(
        "python3.12"
        "python3.11"
        "/usr/bin/python3.12"
        "/usr/bin/python3.11"
        "/usr/local/bin/python3.12"
        "/usr/local/bin/python3.11"
    )

    # Check Homebrew paths (macOS)
    if [ "$(uname -s)" = "Darwin" ]; then
        candidates+=(
            "/opt/homebrew/bin/python3.12"
            "/opt/homebrew/bin/python3.11"
            "/usr/local/opt/python@3.12/bin/python3.12"
            "/usr/local/opt/python@3.11/bin/python3.11"
        )
    fi

    # Try each candidate
    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" &>/dev/null || [ -x "$cmd" ]; then
            local version
            version=$("$cmd" --version 2>&1 | sed -n 's/.*Python \([0-9]*\.[0-9]*\).*/\1/p')
            if [[ "$version" == "3.12" || "$version" == "3.11" ]]; then
                PYTHON_CMD="$cmd"
                PYTHON_VERSION="$version"
                ok "Python found: $("$cmd" --version 2>&1) at $(command -v "$cmd" 2>/dev/null || echo "$cmd")"
                return 0
            fi
        fi
    done

    # Fallback: check generic python3
    if command -v python3 &>/dev/null; then
        local version
        version=$(python3 --version 2>&1 | sed -n 's/.*Python \([0-9]*\.[0-9]*\).*/\1/p')
        if [[ "$version" == "3.12" || "$version" == "3.11" ]]; then
            PYTHON_CMD="python3"
            PYTHON_VERSION="$version"
            ok "Python found: $(python3 --version 2>&1) at $(command -v python3)"
            return 0
        else
            warn "python3 found but version is $version (need 3.11 or 3.12)"
        fi
    fi

    # Not found — show install instructions
    err "Python 3.11 or 3.12 not found!"
    echo ""
    echo -e "${YELLOW}Install Python 3.12 for your platform:${RESET}"
    echo ""

    case "$(uname -s)" in
        Linux)
            if command -v apt &>/dev/null; then
                echo "  Ubuntu/Debian:"
                echo "    sudo apt update && sudo apt install python3.12 python3.12-venv python3.12-dev"
            fi
            if command -v dnf &>/dev/null; then
                echo "  Fedora/RHEL:"
                echo "    sudo dnf install python3.12 python3.12-devel"
            fi
            if command -v pacman &>/dev/null; then
                echo "  Arch Linux:"
                echo "    sudo pacman -S python"
            fi
            ;;
        Darwin)
            echo "  macOS (Homebrew):"
            echo "    brew install python@3.12"
            ;;
    esac

    echo ""
    echo "  Or use pyenv:"
    echo "    pyenv install 3.12 && pyenv global 3.12"
    echo ""
    echo -e "${RED}NOTE: Python 3.13+ is NOT supported (onnxruntime incompatibility)${RESET}"
    exit 1
}

# ============================================================================
# PROJECT STRUCTURE
# ============================================================================

setup_project_structure() {
    step "PROJECT STRUCTURE"

    if [ ! -d "$INSTALL_PATH" ]; then
        mkdir -p "$INSTALL_PATH"
        ok "Created: $INSTALL_PATH"
    else
        ok "Directory exists: $INSTALL_PATH"
    fi

    local dirs=(
        "mcp_server"
        "documents"
        "documents/security"
        "documents/logscale"
        "documents/development"
        "documents/general"
        "documents/aar"
        "data"
        "data/chroma_db"
        ".claude"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$INSTALL_PATH/$dir"
    done

    ok "Directory structure created"
}

# ============================================================================
# VIRTUAL ENVIRONMENT
# ============================================================================

setup_venv() {
    step "VIRTUAL ENVIRONMENT"

    local venv_path="$INSTALL_PATH/venv"
    local venv_python="$venv_path/bin/python"
    local venv_pip="$venv_path/bin/pip"

    # Create venv if needed
    if [ ! -f "$venv_python" ] || [ "$FORCE" -eq 1 ]; then
        if [ "$FORCE" -eq 1 ] && [ -d "$venv_path" ]; then
            warn "Removing existing venv (--force)..."
            rm -rf "$venv_path"
        fi
        info "Creating virtual environment with $PYTHON_CMD..."
        "$PYTHON_CMD" -m venv "$venv_path"
        ok "Virtual environment created"
    else
        ok "Virtual environment exists"
    fi

    # Upgrade pip
    info "Upgrading pip..."
    "$venv_python" -m pip install --upgrade pip --quiet

    # Install dependencies based on mode
    if [ "$FROM_SOURCE" -eq 1 ]; then
        # --from-source: install from requirements.txt in current/install dir
        local req_file="$INSTALL_PATH/$REQUIREMENTS_FILE"

        # If running from cloned repo, check current dir too
        if [ ! -f "$req_file" ] && [ -f "./$REQUIREMENTS_FILE" ]; then
            req_file="./$REQUIREMENTS_FILE"
        fi

        if [ -f "$req_file" ]; then
            info "Installing dependencies from $REQUIREMENTS_FILE..."
            "$venv_pip" install -r "$req_file" --quiet
            ok "All dependencies installed!"
        else
            err "$REQUIREMENTS_FILE not found at $req_file"
            err "Ensure you are in the cloned repository or use --install-path to point to it."
            exit 1
        fi
    else
        # Default: pip install from PyPI
        info "Installing knowledge-rag from PyPI..."
        "$venv_pip" install knowledge-rag --quiet
        ok "knowledge-rag installed from PyPI!"
    fi

    VENV_PYTHON="$venv_python"
}

# ============================================================================
# INIT (PyPI mode only)
# ============================================================================

run_init() {
    if [ "$FROM_SOURCE" -eq 0 ]; then
        step "PROJECT INITIALIZATION"
        info "Running knowledge-rag init..."
        cd "$INSTALL_PATH"
        "$VENV_PYTHON" -m mcp_server.server init 2>&1 || true
        cd - > /dev/null
        ok "Project initialized (config + presets exported)"
    fi
}

# ============================================================================
# EMBEDDING MODEL PRE-DOWNLOAD
# ============================================================================

install_embedding_model() {
    step "EMBEDDING MODEL (FastEmbed)"

    info "Pre-downloading embedding model: $EMBEDDING_MODEL"
    info "This downloads ~130MB on first run (cached in ~/.cache/fastembed/)"

    if "$VENV_PYTHON" -c "from fastembed import TextEmbedding; TextEmbedding('$EMBEDDING_MODEL')" 2>&1; then
        ok "Embedding model '$EMBEDDING_MODEL' ready!"
    else
        warn "Model pre-download may have failed. The server will retry on first start."
    fi
}

# ============================================================================
# SOURCE FILES CHECK (--from-source only)
# ============================================================================

check_source_files() {
    if [ "$FROM_SOURCE" -eq 0 ]; then
        return
    fi

    step "SOURCE FILES"

    local init_file="$INSTALL_PATH/mcp_server/__init__.py"
    if [ ! -f "$init_file" ]; then
        echo '"""Knowledge RAG MCP Server Package"""' > "$init_file"
    fi

    local files=("config.py" "ingestion.py" "server.py")
    for f in "${files[@]}"; do
        if [ -f "$INSTALL_PATH/mcp_server/$f" ]; then
            ok "Found: mcp_server/$f"
        else
            warn "mcp_server/$f not found — ensure you cloned the repository"
        fi
    done

    if [ -f "$INSTALL_PATH/requirements.txt" ]; then
        ok "Found: requirements.txt"
    else
        warn "requirements.txt not found"
    fi
}

# ============================================================================
# MCP CONFIGURATION
# ============================================================================

setup_mcp_config() {
    step "MCP CONFIGURATION"

    local mcp_entry
    mcp_entry=$(cat <<JSONEOF
{
    "command": "$INSTALL_PATH/venv/bin/python",
    "args": ["-m", "mcp_server.server"],
    "cwd": "$INSTALL_PATH"
}
JSONEOF
)

    # --- Project-level config ---
    local project_mcp_dir="$INSTALL_PATH/.claude"
    local project_mcp_file="$project_mcp_dir/mcp.json"
    mkdir -p "$project_mcp_dir"

    cat > "$project_mcp_file" <<JSONEOF
{
    "mcpServers": {
        "knowledge-rag": {
            "command": "$INSTALL_PATH/venv/bin/python",
            "args": ["-m", "mcp_server.server"],
            "cwd": "$INSTALL_PATH"
        }
    }
}
JSONEOF
    ok "Created: .claude/mcp.json (project)"

    # --- Global config (~/.claude.json) ---
    local global_config="$HOME/.claude.json"

    if command -v jq &>/dev/null; then
        # jq available — proper JSON merge
        if [ -f "$global_config" ]; then
            local tmp_file
            tmp_file=$(mktemp)
            jq --argjson entry "$mcp_entry" \
                '.mcpServers["knowledge-rag"] = $entry' \
                "$global_config" > "$tmp_file" 2>/dev/null

            if [ $? -eq 0 ] && [ -s "$tmp_file" ]; then
                mv "$tmp_file" "$global_config"
                ok "Updated: ~/.claude.json (global — merged with jq)"
            else
                rm -f "$tmp_file"
                warn "jq merge failed, falling back to Python"
                _merge_with_python "$global_config" "$mcp_entry"
            fi
        else
            # No existing file — create fresh
            jq -n --argjson entry "$mcp_entry" \
                '{"mcpServers": {"knowledge-rag": $entry}}' > "$global_config"
            ok "Created: ~/.claude.json (global)"
        fi
    else
        # No jq — use Python for JSON manipulation
        _merge_with_python "$global_config" "$mcp_entry"
    fi
}

_merge_with_python() {
    local config_file="$1"
    local entry_json="$2"

    "$VENV_PYTHON" -c "
import json, sys, os

config_file = '$config_file'
entry = json.loads('''$entry_json''')

if os.path.isfile(config_file):
    try:
        with open(config_file, 'r') as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        data = {}
else:
    data = {}

if 'mcpServers' not in data:
    data['mcpServers'] = {}

data['mcpServers']['knowledge-rag'] = entry

with open(config_file, 'w') as f:
    json.dump(data, f, indent=4)

print('done')
" 2>&1

    if [ $? -eq 0 ]; then
        if [ -f "$config_file" ]; then
            ok "Updated: ~/.claude.json (global — merged with Python)"
        else
            ok "Created: ~/.claude.json (global)"
        fi
    else
        warn "Failed to write ~/.claude.json — configure manually"
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

show_summary() {
    local docs_path="$INSTALL_PATH/documents"

    echo ""
    echo -e "${GREEN}"
    echo "    ╔═══════════════════════════════════════════════════════════════════╗"
    echo "    ║                    INSTALLATION COMPLETE!                         ║"
    echo "    ╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
    echo -e "    ${BOLD}Installation Path:${RESET}  $INSTALL_PATH"
    echo -e "    ${BOLD}Python (venv):${RESET}      $VENV_PYTHON"
    echo -e "    ${BOLD}Python Version:${RESET}     $PYTHON_VERSION"
    echo -e "    ${BOLD}Embedding Model:${RESET}    $EMBEDDING_MODEL (FastEmbed, in-process)"
    echo -e "    ${BOLD}Embedding Cache:${RESET}    ~/.cache/fastembed/"
    echo ""
    echo -e "${CYAN}"
    echo "    ┌─────────────────────────────────────────────────────────────────┐"
    echo "    │ NEXT STEPS                                                      │"
    echo "    ├─────────────────────────────────────────────────────────────────┤"
    echo "    │                                                                 │"
    echo "    │ 1. Add documents to: $docs_path/"
    echo "    │    - security/     -> Security/pentest content                  │"
    echo "    │    - logscale/     -> LogScale/LQL queries                      │"
    echo "    │    - development/  -> Code/dev documentation                    │"
    echo "    │    - aar/          -> After Action Reviews                      │"
    echo "    │    - general/      -> Other documents                           │"
    echo "    │                                                                 │"
    echo "    │ 2. Restart Claude Code to load the MCP server                   │"
    echo "    │    (server auto-indexes documents on startup)                   │"
    echo "    │                                                                 │"
    echo "    │ 3. Available MCP Tools (12):                                    │"
    echo "    │    - search_knowledge    - get_document                         │"
    echo "    │    - reindex_documents   - list_categories                      │"
    echo "    │    - list_documents      - get_index_stats                      │"
    echo "    │    - add_document        - update_document                      │"
    echo "    │    - remove_document     - add_from_url                         │"
    echo "    │    - search_similar      - evaluate_retrieval                   │"
    echo "    │                                                                 │"
    echo "    └─────────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"
    echo ""
    echo -e "    No external services required. FastEmbed runs in-process."
    echo -e "    Just restart Claude Code and start searching."
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_banner

    info "Install path: $INSTALL_PATH"
    info "Platform: $(uname -s) ($(uname -m))"
    if [ "$FROM_SOURCE" -eq 1 ]; then
        info "Mode: from-source (local requirements.txt)"
    else
        info "Mode: pip install (PyPI)"
    fi
    echo ""

    # Step 1: Find Python
    find_python

    # Step 2: Project structure
    if [ "$FROM_SOURCE" -eq 1 ]; then
        # --from-source: use current directory as install path if it has source files
        if [ -f "./mcp_server/server.py" ] && [ "$INSTALL_PATH" = "$HOME/knowledge-rag" ]; then
            INSTALL_PATH="$(pwd)"
            info "Detected source checkout — using current directory: $INSTALL_PATH"
        fi
    fi
    setup_project_structure

    # Step 3: Virtual environment + dependencies
    setup_venv

    # Step 4: Init (PyPI mode — exports config template + presets)
    run_init

    # Step 5: Pre-download embedding model
    install_embedding_model

    # Step 6: Verify source files (--from-source only)
    check_source_files

    # Step 7: MCP configuration
    setup_mcp_config

    # Summary
    show_summary

    echo -e "${GREEN}Installation completed successfully!${RESET}"
    echo ""
}

main
