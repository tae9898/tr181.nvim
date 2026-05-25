#!/usr/bin/env bash
# install.sh - tr181.nvim 설치 스크립트
# Python CLI 설치 + TR-181 XML 데이터 다운로드

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 색상
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${CYAN}  [INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}  [OK]${RESET} $1"; }
err()   { echo -e "${RED}  [ERROR]${RESET} $1"; }

# ─── 설정 ──────────────────────────────────────────────────────────────────────
TR181_XML_URL="https://cwmp-data-models.broadband-forum.org/tr-181-2-20-0-cwmp-full.xml"
CLI_SRC="${SCRIPT_DIR}/python/tr181"
CLI_DEST="${HOME}/.local/bin/tr181"
XML_DEST="${HOME}/.tr181/tr-181.xml"

# ─── 1. Python CLI 설치 ────────────────────────────────────────────────────────
install_cli() {
    info "Installing tr181 CLI..."

    mkdir -p "$(dirname "$CLI_DEST")"
    cp "$CLI_SRC" "$CLI_DEST"
    chmod +x "$CLI_DEST"

    ok "CLI installed: ${CLI_DEST}"
}

# ─── 2. TR-181 XML 다운로드 ────────────────────────────────────────────────────
download_xml() {
    if [[ -f "$XML_DEST" ]]; then
        info "XML already exists: ${XML_DEST}"
        info "To re-download, remove it first: rm ${XML_DEST}"
        return 0
    fi

    info "Downloading TR-181 Device:2.20 XML (~5MB)..."

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        err "curl or wget is required."
        exit 1
    fi

    mkdir -p "$(dirname "$XML_DEST")"

    if command -v curl &>/dev/null; then
        curl -fsSL "$TR181_XML_URL" -o "$XML_DEST"
    else
        wget -q "$TR181_XML_URL" -O "$XML_DEST"
    fi

    if [[ -f "$XML_DEST" ]]; then
        ok "XML downloaded: ${XML_DEST}"
    else
        err "Failed to download XML."
        exit 1
    fi
}

# ─── 3. 검증 ───────────────────────────────────────────────────────────────────
verify() {
    info "Verifying installation..."

    if ! command -v python3 &>/dev/null; then
        err "python3 is required."
        exit 1
    fi

    if "$CLI_DEST" stats 2>/dev/null; then
        ok "tr181 CLI is working."
    else
        err "tr181 CLI failed. Check XML file path."
        exit 1
    fi
}

# ─── 메인 ──────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}  tr181.nvim installer${RESET}"
    echo -e "  ${DIM}TR-181 Device:2.20 Data Model${RESET}"
    echo ""

    install_cli
    download_xml
    verify

    echo ""
    ok "Installation complete!"
    echo ""
    echo -e "  ${DIM}Add to your Neovim config (lazy.nvim):${RESET}"
    echo ""
    echo -e "  ${CYAN}'tae9898/tr181.nvim'${RESET}"
    echo -e "  ${DIM}config = function() require('tr181').setup() end${RESET}"
    echo ""
}

main "$@"
