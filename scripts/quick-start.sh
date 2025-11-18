#!/usr/bin/env bash
# quick-start.sh - 既存環境から標準化環境への最速移行スクリプト
set -euo pipefail

# ========================================
# Configuration
# ========================================
REPOS_DIR="${HOME}/repos"
BACKUP_DIR="${HOME}/Desktop/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========================================
# Helper Functions
# ========================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

confirm() {
    read -p "$(echo -e ${YELLOW}"$1 (y/N): "${NC})" response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ========================================
# Pre-flight Checks
# ========================================
preflight_check() {
    log_info "実行前チェック..."

    # Check required commands
    local missing_commands=()
    for cmd in git gh gpg tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "必要なコマンドがインストールされていません: ${missing_commands[*]}"
        log_info "brew install ${missing_commands[*]}"
        exit 1
    fi

    # Check GitHub CLI auth
    if ! gh auth status &>/dev/null; then
        log_warn "GitHub CLI が認証されていません"
        log_info "実行: gh auth login"
        exit 1
    fi

    log_success "チェック完了"
}

# ========================================
# Backup Current Configuration
# ========================================
create_backup() {
    log_info "現在の設定をバックアップ中..."

    mkdir -p "$BACKUP_DIR"

    # Backup existing configs
    for dir in ~/.config ~/.ssh ~/.zshrc ~/.gitconfig; do
        if [ -e "$dir" ]; then
            log_info "バックアップ: $dir"
            cp -r "$dir" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done

    # Backup existing tools
    if [ -d ~/works/git/tools ]; then
        log_info "既存ツールをバックアップ中..."
        tar czf "$BACKUP_DIR/tools-backup.tar.gz" ~/works/git/tools
    fi

    log_success "バックアップ完了: $BACKUP_DIR"
}

# ========================================
# Create Repository Structure
# ========================================
setup_repositories() {
    log_info "リポジトリ構造を作成中..."

    mkdir -p "$REPOS_DIR"
    cd "$REPOS_DIR"

    # Create main dotfiles repository
    if [ ! -d "dotfiles" ]; then
        log_info "dotfilesリポジトリを作成中..."
        gh repo create dotfiles --private --clone --description "Personal dotfiles and tools"

        cd dotfiles

        # Create directory structure
        mkdir -p core/{plumbing,middleware,lib}
        mkdir -p shell/zsh/{functions/{dev,productivity,remote,media,pdf},completions}
        mkdir -p editors/{nvim,vscode}
        mkdir -p terminal/{wezterm,tmux}
        mkdir -p claude/commands/{dev,review,debug}
        mkdir -p tools/{integrated,standalone}
        mkdir -p docker/{luatex,whisper}
        mkdir -p scripts/{install,backup,sync}
        mkdir -p ssh/public_keys
        mkdir -p git
        mkdir -p tests

        log_success "ディレクトリ構造作成完了"
    else
        log_warn "dotfilesリポジトリは既に存在します"
    fi

    # Create secure repository
    if [ ! -d "$REPOS_DIR/dotfiles-secure" ]; then
        if confirm "機密情報用のプライベートリポジトリを作成しますか？"; then
            gh repo create dotfiles-secure --private --clone --description "Encrypted sensitive configurations"

            cd dotfiles-secure

            # Initialize git-secret
            if command -v git-secret &> /dev/null; then
                git secret init
                git secret tell $(git config user.email)

                mkdir -p secrets/{tokens,ssh/keys,credentials}

                log_success "セキュアリポジトリ作成完了"
            else
                log_warn "git-secret がインストールされていません"
                log_info "実行: brew install git-secret"
            fi
        fi
    fi
}

# ========================================
# Migrate Existing Tools
# ========================================
migrate_tools() {
    log_info "既存ツールを移行中..."

    cd "$REPOS_DIR/dotfiles"

    # Migrate tools from ~/works/git/tools
    if [ -d ~/works/git/tools ]; then
        log_info "既存ツールディレクトリから移行..."

        # Priority tools
        for tool in luatex-docker-remote rehearsal-workflow markdown-uploader; do
            if [ -d ~/works/git/tools/$tool ]; then
                log_info "移行中: $tool"
                cp -r ~/works/git/tools/$tool tools/integrated/ 2>/dev/null || true
            fi
        done

        # Other tools
        for tool in ~/works/git/tools/*; do
            if [ -d "$tool" ]; then
                tool_name=$(basename "$tool")
                if [ ! -d "tools/integrated/$tool_name" ] && [ ! -d "tools/standalone/$tool_name" ]; then
                    log_info "移行中: $tool_name"
                    cp -r "$tool" tools/standalone/
                fi
            fi
        done
    fi

    # Migrate Zsh functions
    if [ -d ~/.config/zsh/functions ]; then
        log_info "Zsh関数を移行中..."

        # PDF functions
        cp ~/.config/zsh/functions/pdf-*.zsh shell/zsh/functions/pdf/ 2>/dev/null || true

        # Media functions
        cp ~/.config/zsh/functions/convert-*.zsh shell/zsh/functions/media/ 2>/dev/null || true
        cp ~/.config/zsh/functions/*video*.zsh shell/zsh/functions/media/ 2>/dev/null || true

        # Other functions
        cp ~/.config/zsh/functions/*.zsh shell/zsh/functions/productivity/ 2>/dev/null || true
    fi

    log_success "ツール移行完了"
}

# ========================================
# Migrate Configuration Files
# ========================================
migrate_configs() {
    log_info "設定ファイルを移行中..."

    cd "$REPOS_DIR/dotfiles"

    # Neovim configuration
    if [ -d ~/.config/nvim ]; then
        log_info "Neovim設定を移行中..."
        cp -r ~/.config/nvim/* editors/nvim/ 2>/dev/null || true
    fi

    # Wezterm configuration
    if [ -d ~/.config/wezterm ] || [ -f ~/.wezterm.lua ]; then
        log_info "Wezterm設定を移行中..."
        [ -f ~/.wezterm.lua ] && cp ~/.wezterm.lua terminal/wezterm/
        [ -d ~/.config/wezterm ] && cp -r ~/.config/wezterm/* terminal/wezterm/ 2>/dev/null || true
    fi

    # Git configuration
    if [ -f ~/.gitconfig ]; then
        log_info "Git設定を移行中..."
        # Remove sensitive information
        grep -v -E "token|password|credential" ~/.gitconfig > git/.gitconfig
    fi

    # SSH configuration (public only)
    if [ -d ~/.ssh ]; then
        log_info "SSH公開設定を移行中..."
        [ -f ~/.ssh/config ] && cp ~/.ssh/config ssh/
        cp ~/.ssh/*.pub ssh/public_keys/ 2>/dev/null || true
    fi

    # Zsh configuration
    if [ -f ~/.zshrc ]; then
        log_info "Zsh設定を移行中..."
        cp ~/.zshrc shell/zsh/.zshrc.backup
    fi

    log_success "設定ファイル移行完了"
}

# ========================================
# Create Installation Scripts
# ========================================
create_install_scripts() {
    log_info "インストールスクリプトを作成中..."

    cd "$REPOS_DIR/dotfiles"

    # Create Makefile
    cat > Makefile << 'MAKEFILE_END'
.PHONY: all install test clean backup help

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')

all: install

install:
	@echo "🚀 Installing dotfiles for $(OS)..."
	@./scripts/install/main.sh

test:
	@echo "🧪 Running tests..."
	@shellcheck scripts/**/*.sh 2>/dev/null || echo "shellcheck not installed"

clean:
	@echo "🧹 Cleaning..."
	@find . -name "*.zwc" -delete
	@find . -name ".DS_Store" -delete

backup:
	@echo "💾 Creating backup..."
	@tar czf ../dotfiles-backup-$$(date +%Y%m%d).tar.gz .

help:
	@echo "Available targets:"
	@echo "  make install - Install dotfiles"
	@echo "  make test    - Run tests"
	@echo "  make clean   - Clean temporary files"
	@echo "  make backup  - Create backup"
MAKEFILE_END

    # Create main install script
    mkdir -p scripts/install
    cat > scripts/install/main.sh << 'INSTALL_END'
#!/usr/bin/env bash
set -euo pipefail

echo "📦 Installing dotfiles..."

# Create symlinks
echo "Creating symbolic links..."

# Zsh
[ -d ~/.config ] || mkdir -p ~/.config
ln -sfn "$(pwd)/shell/zsh" ~/.config/zsh

# Neovim
ln -sfn "$(pwd)/editors/nvim" ~/.config/nvim

# Git
ln -sfn "$(pwd)/git/.gitconfig" ~/.gitconfig

echo "✅ Installation complete!"
echo "Please restart your shell or run: source ~/.zshrc"
INSTALL_END

    chmod +x scripts/install/main.sh

    log_success "インストールスクリプト作成完了"
}

# ========================================
# Initial Git Commit
# ========================================
initial_commit() {
    log_info "初期コミットを作成中..."

    cd "$REPOS_DIR/dotfiles"

    # Create .gitignore
    cat > .gitignore << 'GITIGNORE_END'
# Compiled files
*.zwc
*.zwc.old

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/

# Sensitive files
*.secret
*.key
*.pem

# Temporary files
*.tmp
*.bak
*.backup
GITIGNORE_END

    # Add and commit
    git add -A
    git commit -m "feat: Initial migration from existing dotfiles

- Migrate tools from ~/works/git/tools
- Migrate Zsh functions and configurations
- Add installation scripts and Makefile
- Setup directory structure following UNIX philosophy"

    git push origin main

    log_success "初期コミット完了"
}

# ========================================
# Main Execution
# ========================================
main() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Dotfiles Migration Quick Start${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    preflight_check

    if confirm "現在の設定をバックアップしますか？"; then
        create_backup
    fi

    setup_repositories
    migrate_tools
    migrate_configs
    create_install_scripts

    if confirm "Gitにコミット＆プッシュしますか？"; then
        initial_commit
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ 移行完了！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "次のステップ:"
    echo "1. cd $REPOS_DIR/dotfiles"
    echo "2. make install"
    echo "3. source ~/.zshrc"
    echo ""
    echo "詳細: https://github.com/$(gh api user -q .login)/dotfiles"
}

# Run main function
main "$@"