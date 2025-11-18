#!/usr/bin/env bash
# unified-setup.sh - 統合環境セットアップスクリプト

set -euo pipefail

# ========================================
# 設定
# ========================================

REPOS_DIR="${HOME}/repos"
DOTFILES_REPO="https://github.com/yourusername/dotfiles.git"
SECRETS_REPO="git@github.com:yourusername/dotfiles-secret.git"
SERVER_REPO="git@github.com:yourusername/server-configs.git"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ========================================
# ヘルパー関数
# ========================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed"
        return 1
    fi
}

# ========================================
# 前提条件チェック
# ========================================

log_info "Checking prerequisites..."

required_commands=(git gpg age uv rsync)
for cmd in "${required_commands[@]}"; do
    check_command "$cmd" || exit 1
done

# ========================================
# ディレクトリ構造作成
# ========================================

log_info "Creating directory structure..."

mkdir -p "${REPOS_DIR}"
mkdir -p "${HOME}/.config"/{tools,tokens,age}
mkdir -p "${HOME}/.local/"{bin,share/tools,state/tools}
mkdir -p "${HOME}/.ssh/keys"/{personal,work}

# ========================================
# リポジトリクローン
# ========================================

log_info "Cloning repositories..."

# メインの dotfiles
if [ ! -d "${REPOS_DIR}/dotfiles" ]; then
    git clone "$DOTFILES_REPO" "${REPOS_DIR}/dotfiles"
fi

# 秘密情報（プライベートリポジトリ）
if [ ! -d "${REPOS_DIR}/dotfiles-secret" ]; then
    git clone "$SECRETS_REPO" "${REPOS_DIR}/dotfiles-secret"
fi

# サーバー設定
if [ ! -d "${REPOS_DIR}/server-configs" ]; then
    git clone "$SERVER_REPO" "${REPOS_DIR}/server-configs"
fi

# ========================================
# XDG 設定のリンク
# ========================================

log_info "Setting up XDG configurations..."

# シンボリックリンク作成関数
create_symlink() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ]; then
        log_info "Backing up existing $target"
        mv "$target" "${target}.backup.$(date +%Y%m%d)"
    fi

    ln -sf "$source" "$target"
    log_success "Linked $source -> $target"
}

# XDG 設定のリンク
for dir in nvim wezterm zsh git; do
    if [ -d "${REPOS_DIR}/dotfiles/configs/${dir}" ]; then
        create_symlink \
            "${REPOS_DIR}/dotfiles/configs/${dir}" \
            "${HOME}/.config/${dir}"
    fi
done

# ========================================
# SSH 設定
# ========================================

log_info "Setting up SSH configuration..."

# SSH config のリンク
create_symlink \
    "${REPOS_DIR}/dotfiles/configs/ssh/config" \
    "${HOME}/.ssh/config"

# SSH 鍵の復号化（git-secret 使用時）
if [ -d "${REPOS_DIR}/dotfiles-secret/.gitsecret" ]; then
    cd "${REPOS_DIR}/dotfiles-secret"
    git secret reveal

    # 秘密鍵のコピー
    cp -n ssh/id_* "${HOME}/.ssh/keys/personal/" 2>/dev/null || true

    # パーミッション設定
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh/keys"/**/*
    chmod 644 "${HOME}/.ssh/keys"/**/*.pub
fi

# ========================================
# トークン管理
# ========================================

log_info "Setting up token management..."

# トークンの復号化と設置
if [ -d "${REPOS_DIR}/dotfiles-secret/tokens" ]; then
    for token_file in "${REPOS_DIR}/dotfiles-secret/tokens"/*.env.gpg; do
        if [ -f "$token_file" ]; then
            basename=$(basename "$token_file" .gpg)
            gpg --decrypt "$token_file" > "${HOME}/.config/tokens/${basename}"
        fi
    done
fi

# トークンロードスクリプトの作成
cat > "${HOME}/.config/tools/load-tokens.sh" <<'EOF'
#!/usr/bin/env bash
# Auto-load tokens

TOKENS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tokens"

if [ -d "$TOKENS_DIR" ]; then
    for env_file in "$TOKENS_DIR"/*.env; do
        [ -f "$env_file" ] && source "$env_file"
    done
fi
EOF

chmod +x "${HOME}/.config/tools/load-tokens.sh"

# ========================================
# Python 環境設定
# ========================================

log_info "Setting up Python environments..."

# uv の設定
mkdir -p "${HOME}/.config/uv"
cat > "${HOME}/.config/uv/config.toml" <<'EOF'
[global]
index-url = "https://pypi.org/simple"
python-preference = "managed"

[virtualenv]
prompt = "({project_name})"
EOF

# グローバル Python バージョン
echo "3.12" > "${HOME}/.python-version"

# ========================================
# シェル設定の更新
# ========================================

log_info "Updating shell configuration..."

# zshrc に追加
if ! grep -q "load-tokens.sh" "${HOME}/.zshrc" 2>/dev/null; then
    cat >> "${HOME}/.zshrc" <<'EOF'

# Tool standardization environment
export TOOLS_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/tools"
export TOOLS_BIN="${HOME}/.local/bin"
export PATH="${TOOLS_BIN}:${PATH}"

# Load tokens
source "${HOME}/.config/tools/load-tokens.sh"

# Python (uv)
export UV_CONFIG_FILE="${HOME}/.config/uv/config.toml"
EOF
fi

# ========================================
# サーバー同期設定
# ========================================

log_info "Setting up server sync..."

# 同期スクリプトのリンク
if [ -f "${REPOS_DIR}/server-configs/sync.sh" ]; then
    create_symlink \
        "${REPOS_DIR}/server-configs/sync.sh" \
        "${HOME}/.local/bin/sync-server"
    chmod +x "${HOME}/.local/bin/sync-server"
fi

# ========================================
# 検証
# ========================================

log_info "Verifying installation..."

# チェック項目
checks=(
    "[ -d ${HOME}/.config/tools ]"
    "[ -f ${HOME}/.ssh/config ]"
    "[ -f ${HOME}/.config/tools/load-tokens.sh ]"
)

failed=0
for check in "${checks[@]}"; do
    if eval "$check"; then
        log_success "✓ $check"
    else
        log_error "✗ $check"
        ((failed++))
    fi
done

# ========================================
# 完了
# ========================================

if [ $failed -eq 0 ]; then
    log_success "Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your shell or run: source ~/.zshrc"
    echo "2. Verify SSH keys: ssh-add -l"
    echo "3. Test token loading: echo \$NOTION_API_KEY"
    echo "4. Sync server configs: sync-server"
else
    log_error "Setup completed with $failed errors"
    exit 1
fi