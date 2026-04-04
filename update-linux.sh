#!/usr/bin/env bash
# go2mine hashfarm-agent — Atualizador Linux
# Uso: sudo bash update-linux.sh
set -euo pipefail

SERVICE_NAME="hashfarm-agent"

# Detecta o diretório de instalação pelo arquivo do serviço systemd
INSTALL_DIR=$(grep -oP '(?<=WorkingDirectory=).*' /etc/systemd/system/${SERVICE_NAME}.service 2>/dev/null || echo "/opt/hashfarm-agent")
SERVICE_USER=$(grep -oP '(?<=User=).*' /etc/systemd/system/${SERVICE_NAME}.service 2>/dev/null || echo "hashfarm")
DOWNLOAD_URL="https://github.com/jefsp/hashfarm-downloads/releases/latest/download/hashfarm-agent-linux.tar.gz"
TMP_FILE="/tmp/hashfarm-agent-update.tar.gz"
TMP_DIR="/tmp/hashfarm-agent-update"

RESET='\033[0m'; BOLD='\033[1m'
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
ok()   { echo -e "${GREEN}✔${RESET}  $*"; }
info() { echo -e "${CYAN}→${RESET}  $*"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $*"; }
die()  { echo -e "${RED}✖${RESET}  $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && die "Execute como root: sudo bash $0"

echo -e "\n${BOLD}  go2mine hashfarm-agent — Atualização Linux${RESET}\n"

info "1/5  Parando o agente..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
ok "Agente parado"

info "2/5  Baixando nova versão..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_FILE" || die "Falha ao baixar. Verifique sua conexão."
ok "Download concluído"

info "3/5  Extraindo arquivos..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
tar -xzf "$TMP_FILE" -C "$TMP_DIR" --strip-components=1
ok "Extração concluída"

info "4/5  Atualizando arquivos (config.toml e hashfarm.db preservados)..."
cp -r "$TMP_DIR/agent" "$INSTALL_DIR/"
cp "$TMP_DIR/requirements.txt" "$INSTALL_DIR/"
[[ -f "$TMP_DIR/install-linux.sh"   ]] && cp "$TMP_DIR/install-linux.sh"   "$INSTALL_DIR/"
[[ -f "$TMP_DIR/uninstall-linux.sh" ]] && cp "$TMP_DIR/uninstall-linux.sh" "$INSTALL_DIR/"
[[ -f "$TMP_DIR/update-linux.sh"    ]] && cp "$TMP_DIR/update-linux.sh"    "$INSTALL_DIR/"

info "  Verificando virtualenv..."
if [[ ! -f "$INSTALL_DIR/venv/bin/pip" ]]; then
    warn "Virtualenv não encontrado — recriando..."
    PYTHON=""
    for cmd in python3.12 python3.11 python3.10 python3.9 python3; do
        if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys; assert sys.version_info >= (3,9)" 2>/dev/null; then
            PYTHON="$cmd"; break
        fi
    done
    [[ -z "$PYTHON" ]] && die "Python 3.9+ não encontrado. Instale com: sudo apt install python3 python3-venv"
    "$PYTHON" -m venv "$INSTALL_DIR/venv"
fi

info "  Atualizando dependências Python..."
"$INSTALL_DIR/venv/bin/pip" install --quiet --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install --quiet --upgrade -r "$INSTALL_DIR/requirements.txt"

chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
rm -rf "$TMP_DIR" "$TMP_FILE"
ok "Arquivos atualizados"

info "5/5  Reiniciando o agente..."
systemctl start "$SERVICE_NAME"
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Agente reiniciado com sucesso!"
else
    warn "Verifique o status: journalctl -u $SERVICE_NAME -n 20"
fi

NEW_VERSION=$(grep '__version__' "$INSTALL_DIR/agent/__init__.py" 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "desconhecida")
echo -e "\n${BOLD}${GREEN}  Atualização concluída! → v${NEW_VERSION}${RESET}"
echo -e "  Acesse https://app.go2mine.com para confirmar que o agente está online.\n"
