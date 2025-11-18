#!/usr/bin/env bash
# sync-dotfiles.sh - dotfiles の更新を全デバイスに適用

set -euo pipefail

# ========================================
# Configuration
# ========================================

# デバイスリスト（環境に応じて編集）
DEVICES=(
    "mac:localhost"           # ローカルMac
    "wsl:wsl.local"          # WSL2 Ubuntu
    "workstation:workstation.tail-scale.ts.net"  # GPU Workstation
)

# リポジトリパス
DOTFILES_DIR="$HOME/repos/dotfiles"

# ログファイル
LOG_DIR="$HOME/.local/state/dotfiles"
LOG_FILE="$LOG_DIR/sync-$(date +%Y%m%d-%H%M%S).log"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========================================
# Helper Functions
# ========================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# ========================================
# Sync Functions
# ========================================

# ローカルリポジトリを最新に更新
update_local() {
    log_info "ローカルリポジトリを更新中..."

    cd "$DOTFILES_DIR"

    # 現在の状態を保存
    if [[ -n $(git status --porcelain) ]]; then
        log_warn "未コミットの変更があります"
        git stash push -m "Auto-stash before sync $(date +%Y%m%d-%H%M%S)"
        STASHED=true
    else
        STASHED=false
    fi

    # 最新を取得
    git fetch origin

    # ローカルとリモートの差分確認
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u})

    if [ "$LOCAL" = "$REMOTE" ]; then
        log_info "既に最新です"
        return 0
    fi

    # 更新を適用
    log_info "更新を適用中..."
    git pull --rebase origin main

    # インストール実行
    if [ -f Makefile ]; then
        make install
    fi

    # スタッシュを復元
    if [ "$STASHED" = true ]; then
        git stash pop || log_warn "スタッシュの復元に失敗しました"
    fi

    log_success "ローカル更新完了: $(git rev-parse --short HEAD)"
}

# リモートデバイスを更新
sync_remote_device() {
    local device_name="$1"
    local device_host="$2"

    log_info "[$device_name] 同期開始..."

    # SSH接続テスト
    if ! ssh -o ConnectTimeout=5 "$device_host" "echo 'Connected'" &>/dev/null; then
        log_error "[$device_name] 接続できません"
        return 1
    fi

    # リモートで更新実行
    ssh "$device_host" << 'REMOTE_SCRIPT'
        set -euo pipefail

        DOTFILES_DIR="$HOME/repos/dotfiles"

        # リポジトリ存在確認
        if [ ! -d "$DOTFILES_DIR" ]; then
            echo "Error: dotfiles directory not found"
            exit 1
        fi

        cd "$DOTFILES_DIR"

        # 更新前のバージョン
        OLD_VERSION=$(git rev-parse --short HEAD)

        # 未コミットの変更を保存
        if [[ -n $(git status --porcelain) ]]; then
            git stash push -m "Auto-stash before remote sync"
            STASHED=true
        else
            STASHED=false
        fi

        # 更新を取得
        git fetch origin
        git pull --rebase origin main

        # 新しいバージョン
        NEW_VERSION=$(git rev-parse --short HEAD)

        # 変更があった場合のみインストール実行
        if [ "$OLD_VERSION" != "$NEW_VERSION" ]; then
            if [ -f Makefile ]; then
                make install
            fi
            echo "Updated: $OLD_VERSION -> $NEW_VERSION"
        else
            echo "Already up to date: $NEW_VERSION"
        fi

        # スタッシュを復元
        if [ "$STASHED" = true ]; then
            git stash pop 2>/dev/null || echo "Stash restore failed"
        fi

        # Zsh関数の再コンパイル
        if [ -d "$HOME/.config/zsh/functions" ]; then
            find "$HOME/.config/zsh/functions" -name "*.zsh" -exec zcompile {} \; 2>/dev/null || true
        fi

        # サービスのリロード（必要に応じて）
        if command -v tmux &>/dev/null && tmux list-sessions &>/dev/null; then
            tmux source-file ~/.tmux.conf 2>/dev/null || true
        fi
REMOTE_SCRIPT

    if [ $? -eq 0 ]; then
        log_success "[$device_name] 同期完了"
    else
        log_error "[$device_name] 同期失敗"
        return 1
    fi
}

# すべてのデバイスを同期
sync_all_devices() {
    local failed_devices=()

    for device_entry in "${DEVICES[@]}"; do
        IFS=':' read -r name host <<< "$device_entry"

        if [ "$host" = "localhost" ]; then
            continue  # ローカルは既に更新済み
        fi

        if ! sync_remote_device "$name" "$host"; then
            failed_devices+=("$name")
        fi
    done

    if [ ${#failed_devices[@]} -gt 0 ]; then
        log_warn "以下のデバイスで同期に失敗しました: ${failed_devices[*]}"
        return 1
    fi

    return 0
}

# 同期状態を確認
check_sync_status() {
    log_info "同期状態を確認中..."

    cd "$DOTFILES_DIR"
    local local_version=$(git rev-parse --short HEAD)

    echo -e "\n${GREEN}=== Sync Status ===${NC}"
    echo -e "Repository: $(git remote get-url origin)"
    echo -e "Local Version: $local_version\n"

    for device_entry in "${DEVICES[@]}"; do
        IFS=':' read -r name host <<< "$device_entry"

        if [ "$host" = "localhost" ]; then
            echo -e "${name}: $local_version (local)"
        else
            if version=$(ssh -o ConnectTimeout=5 "$host" \
                "cd ~/repos/dotfiles 2>/dev/null && git rev-parse --short HEAD" 2>/dev/null); then
                if [ "$version" = "$local_version" ]; then
                    echo -e "${name}: $version ${GREEN}✓${NC}"
                else
                    echo -e "${name}: $version ${YELLOW}(outdated)${NC}"
                fi
            else
                echo -e "${name}: ${RED}unreachable${NC}"
            fi
        fi
    done
    echo ""
}

# ========================================
# Main Execution
# ========================================

main() {
    # ログディレクトリ作成
    mkdir -p "$LOG_DIR"

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Dotfiles Sync${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # 引数処理
    case "${1:-sync}" in
        sync)
            # 通常の同期
            update_local
            sync_all_devices
            check_sync_status
            ;;
        status)
            # 状態確認のみ
            check_sync_status
            ;;
        force)
            # 強制同期（スタッシュを破棄）
            log_warn "強制同期モード"
            cd "$DOTFILES_DIR"
            git reset --hard origin/main
            update_local
            sync_all_devices
            ;;
        *)
            echo "Usage: $0 [sync|status|force]"
            echo "  sync   - 通常の同期（デフォルト）"
            echo "  status - 同期状態の確認"
            echo "  force  - 強制同期（ローカル変更を破棄）"
            exit 1
            ;;
    esac

    log_info "ログファイル: $LOG_FILE"
}

# エラーハンドリング
trap 'log_error "エラーが発生しました (line $LINENO)"' ERR

# 実行
main "$@"