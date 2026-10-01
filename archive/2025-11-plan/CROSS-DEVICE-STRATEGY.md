# Cross-Device Terminal Strategy - どこからでも同じ環境

## 目標

iPad、macOS、WSL2 Ubuntu から同一の作業環境にアクセスし、シームレスに作業を継続できる環境の構築。

## アーキテクチャ

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iPad (Blink)  │────▶│  WSL2 Ubuntu    │◀────│     macOS       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                        │
         └───────────────────────┼────────────────────────┘
                                 │
                        ┌────────▼────────┐
                        │   Shared State   │
                        │   (Dropbox/Git)  │
                        └─────────────────┘
```

## 1. iPad → WSL2 接続構成

### 推奨アプリケーション構成

```yaml
iPad Apps:
  - Blink Shell:       # 最高のターミナルエミュレータ
      features:
        - mosh support  # 不安定な接続でも継続
        - SSH keys     # ローカル鍵管理
        - tmux integration

  - Tailscale:        # VPN不要のセキュア接続
      purpose: WSL2への直接アクセス

  - Working Copy:     # Git クライアント
      purpose: リポジトリ管理のバックアップ
```

### WSL2 側の設定

```bash
# /etc/ssh/sshd_config の設定
Port 2222                    # Windows SSHと競合回避
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no    # パスワード認証無効化
X11Forwarding yes
AllowUsers yourusername

# systemd でSSHD自動起動（WSL2 + systemd）
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Windows ポートフォワーディング

```powershell
# 管理者権限のPowerShell
# WSL2のIPアドレス取得
$wsl_ip = (wsl hostname -I).trim()

# ポートフォワーディング設定
netsh interface portproxy add v4tov4 `
    listenport=2222 `
    listenaddress=0.0.0.0 `
    connectport=2222 `
    connectaddress=$wsl_ip

# ファイアウォール例外追加
New-NetFirewallRule -DisplayName "WSL2 SSH" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 2222 `
    -Action Allow
```

## 2. 統一環境の実現

### tmux による永続セッション

```bash
# ~/.config/tmux/tmux.conf
# 統一設定で全環境共通の操作性

# プレフィックスキー
set -g prefix C-a
unbind C-b

# ペイン分割
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# セッション永続化プラグイン
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# 自動保存・復元
set -g @continuum-boot 'on'
set -g @continuum-restore 'on'
set -g @resurrect-dir '~/.local/state/tmux/resurrect'

# ステータスライン
set -g status-left '#[fg=green]#H #[fg=black]• '
set -g status-right '#[fg=yellow]#(echo $TOOLS_OS) #[fg=white]%Y-%m-%d %H:%M'
```

### 環境同期スクリプト

```bash
#!/usr/bin/env bash
# ~/.local/bin/sync-environment

# 環境検出
detect_environment() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "macos"
    elif grep -q microsoft /proc/version 2>/dev/null; then
        echo "wsl2"
    elif [[ "$(uname -o)" == "GNU/Linux" ]]; then
        echo "linux"
    fi
}

CURRENT_ENV=$(detect_environment)

# Dropbox 経由の状態同期
SYNC_DIR="$HOME/Dropbox/terminal-state"
STATE_FILE="$SYNC_DIR/$CURRENT_ENV.state"

# 現在の状態を保存
save_state() {
    mkdir -p "$SYNC_DIR"

    # tmux セッション情報
    tmux list-sessions -F "#{session_name}" > "$STATE_FILE.tmux" 2>/dev/null

    # 現在のディレクトリ
    pwd > "$STATE_FILE.pwd"

    # 環境変数
    env | grep "^TOOLS_" > "$STATE_FILE.env"

    # 最終更新
    date -Iseconds > "$STATE_FILE.timestamp"
}

# 他環境の状態を復元
restore_state() {
    local target_env="${1:-macos}"
    local target_file="$SYNC_DIR/$target_env.state"

    if [ -f "$target_file.pwd" ]; then
        cd "$(cat "$target_file.pwd")" 2>/dev/null || true
    fi

    if [ -f "$target_file.env" ]; then
        source "$target_file.env"
    fi

    echo "Restored state from $target_env"
}

# メイン処理
case "${1:-save}" in
    save)
        save_state
        echo "State saved for $CURRENT_ENV"
        ;;
    restore)
        restore_state "${2:-macos}"
        ;;
    *)
        echo "Usage: $0 {save|restore [environment]}"
        ;;
esac
```

## 3. mosh によるモバイル接続最適化

### インストールと設定

```bash
# 全環境でインストール
# macOS
brew install mosh

# WSL2 Ubuntu
sudo apt-get install mosh

# mosh-server のポート範囲設定
# UDP 60000-61000 を開放
```

### iPad (Blink) での接続設定

```javascript
// Blink Shell の .blink/config.js
host "wsl2" {
  hostname = "your-windows-ip"
  port = 2222
  user = "yourusername"
  mosh = true
  moshPort = "60000:61000"
  moshPrediction = "adaptive"
}

host "mac" {
  hostname = "your-mac.local"
  user = "yourusername"
  mosh = true
}
```

## 4. Tailscale によるセキュアアクセス

### セットアップ

```bash
# WSL2 Ubuntu
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# macOS
brew install tailscale
tailscale up

# iPad
# App Store から Tailscale をインストール
```

### 直接接続設定

```bash
# Tailscale のMagic DNS使用
# wsl2.tail-scale.ts.net でアクセス可能に

# ~/.ssh/config に追加
Host wsl2-ts
    HostName wsl2.tail-scale.ts.net
    User yourusername
    Port 2222
```

## 5. ファイル同期戦略

### 作業ファイルの同期

```bash
# リアルタイム同期が必要なディレクトリ
~/Documents/projects/  # Dropbox
~/Documents/notes/     # Dropbox

# Git で管理するディレクトリ
~/repos/              # 各リポジトリ
~/.config/            # dotfiles
```

### 同期スクリプト

```bash
#!/usr/bin/env bash
# ~/.local/bin/sync-workspace

# Dropbox の同期状態確認
check_dropbox() {
    if command -v dropbox &> /dev/null; then
        dropbox status
    else
        echo "Dropbox not installed"
    fi
}

# Git リポジトリの同期
sync_repos() {
    local repos_dir="$HOME/repos"

    for repo in "$repos_dir"/*/.git; do
        repo_path="${repo%/.git}"
        echo "Syncing ${repo_path##*/}..."

        (cd "$repo_path" && {
            git fetch --all
            git status --short
        })
    done
}

# dotfiles の同期
sync_dotfiles() {
    cd "$HOME/repos/dotfiles" || return

    # 変更をコミット
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "Auto-sync from $(hostname) at $(date -Iseconds)"
        git push
    fi

    # 最新を取得
    git pull --rebase
}

# メイン実行
echo "🔄 Syncing workspace..."
check_dropbox
sync_repos
sync_dotfiles
echo "✅ Sync complete"
```

## 6. Neovim のリモート編集

### Neovim Remote 設定

```bash
# WSL2/macOS で Neovim をサーバーとして起動
nvim --listen ~/.cache/nvim/server.pipe

# iPad から接続
# Blink Shell 内で
nvim --remote-ui --server ~/.cache/nvim/server.pipe
```

### VS Code Remote 代替案

```bash
# code-server のインストール（WSL2）
curl -fsSL https://code-server.dev/install.sh | sh

# 起動
code-server --bind-addr 0.0.0.0:8080 --auth none

# iPad Safari でアクセス
# http://wsl2.tail-scale.ts.net:8080
```

## 7. 実装チェックリスト

### Phase 1: 基本接続（1週間）
- [ ] WSL2 で SSH サーバー設定
- [ ] Windows ポートフォワーディング
- [ ] iPad Blink Shell で接続テスト
- [ ] 公開鍵認証の設定

### Phase 2: 環境統一（2週間）
- [ ] tmux 設定の統一
- [ ] zsh/bash 設定の同期
- [ ] Neovim 設定の共有
- [ ] カラーテーマの統一

### Phase 3: 同期機構（1週間）
- [ ] Dropbox 設定
- [ ] Git 自動同期スクリプト
- [ ] 状態保存・復元スクリプト

### Phase 4: 最適化（継続的）
- [ ] mosh 導入
- [ ] Tailscale 設定
- [ ] パフォーマンスチューニング

## 8. トラブルシューティング

### WSL2 の IP アドレスが変わる問題

```bash
# 自動更新スクリプト（Windows タスクスケジューラで実行）
$wsl_ip = (wsl hostname -I).trim()
netsh interface portproxy set v4tov4 `
    listenport=2222 `
    connectaddress=$wsl_ip
```

### tmux セッションが残る問題

```bash
# クリーンアップスクリプト
tmux list-sessions | grep -v attached | cut -d: -f1 | xargs -I {} tmux kill-session -t {}
```

### 文字化け対策

```bash
# 全環境で UTF-8 を強制
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

## まとめ

この構成により：
- **iPad から WSL2/macOS へシームレスにアクセス**
- **tmux による永続的な作業セッション**
- **Dropbox/Git による設定と状態の同期**
- **mosh/Tailscale による安定した接続**

が実現され、デバイスや場所を問わず同一の作業環境を維持できます。