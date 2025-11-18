# Git Repository Best Practices - 最終統合版

## リポジトリ構成戦略

### 推奨：3層リポジトリアーキテクチャ

```
repos/
├── dotfiles/           # 公開可能な設定（Public or Private）
├── dotfiles-secure/    # 機密情報（Private + 暗号化）
└── infrastructure/     # サーバー・Docker設定（Private）
```

## 1. メインリポジトリ：dotfiles

### リポジトリ構造

```bash
dotfiles/
├── .github/
│   ├── workflows/
│   │   ├── test.yml         # CI/CD テスト
│   │   └── sync.yml         # 自動同期
│   └── CODEOWNERS          # レビュー責任者
│
├── core/                     # 基盤層（POSIX準拠）
│   ├── plumbing/            # 原子的操作
│   │   ├── plumb-calc-hash
│   │   ├── plumb-os-detect
│   │   └── plumb-file-ops
│   ├── middleware/          # OS差異吸収
│   │   ├── mid-package-manager
│   │   └── mid-path-resolver
│   └── lib/                 # 共通ライブラリ
│       └── common.sh
│
├── shell/                    # シェル設定
│   ├── zsh/
│   │   ├── .zshrc
│   │   ├── .zshenv
│   │   ├── functions/       # Zsh関数
│   │   │   ├── dev/
│   │   │   ├── productivity/
│   │   │   └── remote/     # GPU/LaTeX処理
│   │   └── completions/
│   ├── bash/
│   │   ├── .bashrc
│   │   └── .bash_profile
│   └── common/              # 共通設定
│       ├── aliases.sh
│       └── exports.sh
│
├── editors/                  # エディタ設定
│   ├── nvim/
│   │   ├── init.lua
│   │   └── lua/
│   ├── vscode/
│   │   ├── settings.json
│   │   └── keybindings.json
│   └── vim/
│       └── .vimrc
│
├── terminal/                 # ターミナル設定
│   ├── wezterm/
│   │   └── wezterm.lua
│   ├── tmux/
│   │   └── tmux.conf
│   └── alacritty/
│       └── alacritty.yml
│
├── claude/                   # Claude Code設定
│   ├── commands/            # カスタムコマンド
│   │   ├── dev/
│   │   ├── review/
│   │   └── debug/
│   ├── templates/
│   └── CLAUDE.md
│
├── git/                      # Git設定
│   ├── .gitconfig
│   ├── .gitignore_global
│   └── hooks/               # グローバルフック
│
├── ssh/                      # SSH公開設定のみ
│   ├── config
│   └── public_keys/
│
├── docker/                   # Docker設定
│   ├── luatex/
│   │   ├── Dockerfile
│   │   └── docker-compose.yml
│   ├── whisper/
│   └── dev-env/
│
├── scripts/                  # インストール・管理スクリプト
│   ├── install.sh           # メインインストーラー
│   ├── bootstrap-mac.sh    # macOS初期設定
│   ├── bootstrap-wsl.sh    # WSL2初期設定
│   └── update.sh            # 更新スクリプト
│
├── docs/                     # ドキュメント
│   ├── README.md
│   ├── SETUP.md
│   └── TROUBLESHOOTING.md
│
├── tests/                    # テストスイート
│   ├── test-shell.sh
│   ├── test-functions.sh
│   └── test-compatibility.sh
│
├── Makefile                  # タスク自動化
├── .envrc                    # direnv設定
└── VERSION                   # バージョン情報
```

### Makefile による管理

```makefile
# Makefile
.PHONY: all install update test clean backup

# デフォルトタスク
all: install

# OS検出
UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
    OS := macos
else ifeq ($(shell grep -q microsoft /proc/version 2>/dev/null && echo wsl),wsl)
    OS := wsl
else
    OS := linux
endif

# インストール
install:
	@echo "🚀 Installing dotfiles for $(OS)..."
	@./scripts/install.sh
	@$(MAKE) link-configs
	@$(MAKE) install-packages
	@$(MAKE) post-install

# 設定ファイルのリンク
link-configs:
	@echo "🔗 Creating symbolic links..."
	@mkdir -p ~/.config
	@ln -sfn $(PWD)/shell/zsh ~/.config/zsh
	@ln -sfn $(PWD)/editors/nvim ~/.config/nvim
	@ln -sfn $(PWD)/terminal/wezterm ~/.config/wezterm
	@ln -sfn $(PWD)/claude ~/.claude
	@ln -sfn $(PWD)/git/.gitconfig ~/.gitconfig

# パッケージインストール
install-packages:
ifeq ($(OS),macos)
	@brew bundle --file=./Brewfile
else ifeq ($(OS),wsl)
	@sudo apt-get update && sudo apt-get install -y $$(cat packages-ubuntu.txt)
endif

# 更新
update:
	@echo "📦 Updating dotfiles..."
	@git pull --rebase
	@$(MAKE) install

# テスト実行
test:
	@echo "🧪 Running tests..."
	@shellcheck core/**/*.sh shell/**/*.sh scripts/*.sh
	@./tests/test-shell.sh
	@./tests/test-functions.sh
	@./tests/test-compatibility.sh

# クリーンアップ
clean:
	@echo "🧹 Cleaning up..."
	@find . -name "*.zwc" -delete
	@find . -name ".DS_Store" -delete
	@rm -rf ~/.config/zsh/.zcompdump*

# バックアップ
backup:
	@echo "💾 Creating backup..."
	@tar czf ~/dotfiles-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		--exclude='.git' \
		--exclude='*.zwc' \
		.

# ヘルプ
help:
	@echo "Available targets:"
	@echo "  install   - Install dotfiles"
	@echo "  update    - Update dotfiles"
	@echo "  test      - Run tests"
	@echo "  clean     - Clean temporary files"
	@echo "  backup    - Create backup"
```

## 2. セキュアリポジトリ：dotfiles-secure

### 構造と暗号化戦略

```bash
dotfiles-secure/
├── .gitsecret/              # git-secret設定
├── secrets/
│   ├── tokens/              # APIトークン
│   │   ├── openai.env.gpg
│   │   ├── notion.env.gpg
│   │   └── anthropic.env.gpg
│   ├── ssh/                 # SSH秘密鍵
│   │   ├── keys/
│   │   │   ├── id_ed25519.gpg
│   │   │   └── id_rsa.gpg
│   │   └── known_hosts.gpg
│   └── credentials/         # その他認証情報
│       ├── aws/
│       ├── gcp/
│       └── database/
│
├── scripts/
│   ├── encrypt.sh           # 暗号化スクリプト
│   ├── decrypt.sh           # 復号化スクリプト
│   └── rotate-keys.sh       # 鍵ローテーション
│
└── README.md                # セキュリティ手順書
```

### セキュリティ実装

```bash
#!/usr/bin/env bash
# scripts/secure-setup.sh

# GPG鍵の確認
check_gpg_key() {
    if ! gpg --list-secret-keys | grep -q "$GPG_EMAIL"; then
        echo "⚠️  GPG key not found for $GPG_EMAIL"
        echo "Generate one with: gpg --gen-key"
        exit 1
    fi
}

# git-secret の初期化
init_git_secret() {
    cd ~/repos/dotfiles-secure
    git secret init
    git secret tell "$GPG_EMAIL"
}

# ファイルの暗号化
encrypt_secrets() {
    # トークンファイルを追加
    find secrets/tokens -name "*.env" -exec git secret add {} \;

    # SSH鍵を追加
    find secrets/ssh/keys -type f ! -name "*.pub" -exec git secret add {} \;

    # 暗号化実行
    git secret hide
}

# 自動復号化フック
install_decrypt_hook() {
    cat > .git/hooks/post-checkout <<'EOF'
#!/bin/sh
git secret reveal -f
EOF
    chmod +x .git/hooks/post-checkout
}
```

## 3. インフラリポジトリ：infrastructure

### Docker環境とサーバー設定

```bash
infrastructure/
├── docker/
│   ├── services/
│   │   ├── luatex/
│   │   ├── whisper-gpu/
│   │   └── jupyter-ml/
│   └── docker-compose.yml
│
├── servers/
│   ├── workstation/         # Windows WSL2設定
│   │   ├── setup.sh
│   │   └── services/
│   ├── coreserver/          # 本番サーバー
│   │   ├── nginx/
│   │   └── deploy/
│   └── homelab/            # ホームラボ
│
├── ansible/                  # 構成管理
│   ├── playbooks/
│   ├── inventory/
│   └── roles/
│
└── terraform/               # インフラ as Code
    ├── modules/
    └── environments/
```

## 4. ブランチ戦略

### Git Flow の簡略版

```
main
  ├── develop
  │     ├── feature/zsh-functions
  │     ├── feature/claude-commands
  │     └── feature/gpu-integration
  └── hotfix/urgent-fix
```

### ブランチ命名規則

```bash
feature/   # 新機能追加
fix/       # バグ修正
refactor/  # リファクタリング
docs/      # ドキュメント更新
test/      # テスト追加
```

## 5. コミットメッセージ規約

### Conventional Commits 形式

```bash
# 形式
<type>(<scope>): <subject>

# 例
feat(zsh): Add GPU status monitoring function
fix(ssh): Correct workstation hostname resolution
docs(setup): Update WSL2 installation guide
refactor(core): Simplify OS detection logic
perf(zsh): Optimize function loading with zcompile
test(functions): Add tests for remote compilation

# スコープ例
- core      # 基盤層
- zsh       # Zsh関数・設定
- claude    # Claude Codeコマンド
- docker    # Docker環境
- ssh       # SSH設定
- terminal  # ターミナル設定
```

## 6. CI/CD パイプライン

### GitHub Actions 設定

```yaml
# .github/workflows/main.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]

    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          if [[ "${{ matrix.os }}" == "ubuntu-latest" ]]; then
            sudo apt-get update
            sudo apt-get install -y shellcheck
          else
            brew install shellcheck
          fi

      - name: Run shellcheck
        run: make test

      - name: Test installation
        run: |
          ./scripts/install.sh --dry-run

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Check for secrets
        run: |
          # 秘密情報の検出
          ! grep -r "secret_\|api_key\|password" --include="*.sh" --include="*.md"

      - name: Check file permissions
        run: |
          # SSH鍵のパーミッション確認
          find . -name "id_*" -not -name "*.pub" -exec test ! -f {} \;
```

## 7. タグとリリース戦略

### セマンティックバージョニング

```bash
# バージョンタグ
v1.0.0    # メジャー：後方互換性のない変更
v1.1.0    # マイナー：後方互換性のある機能追加
v1.1.1    # パッチ：バグ修正

# リリース作成
git tag -a v1.0.0 -m "Initial stable release"
git push origin v1.0.0

# 自動リリースノート生成
git log v0.9.0..v1.0.0 --pretty=format:"- %s" > CHANGELOG.md
```

## 8. セットアップ手順

### 初回セットアップ

```bash
#!/usr/bin/env bash
# Quick Start with GitHub CLI

# 1. 必要なツールのインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git gpg git-secret gh

# 2. GitHub CLI認証
gh auth login

# 3. GPG鍵の生成
gpg --gen-key

# 4. リポジトリの作成とクローン
mkdir -p ~/repos
cd ~/repos

# GitHub上にリポジトリ作成
gh repo create dotfiles --private --clone
gh repo create dotfiles-secure --private --clone
gh repo create infrastructure --private --clone

# 5. インストール実行
cd dotfiles
make install

# 6. 秘密情報の復号化
cd ../dotfiles-secure
git secret reveal

# 7. 検証
make test
```

## 9. トラブルシューティング

### よくある問題と解決策

```bash
# 問題: シンボリックリンクが壊れている
find ~ -type l ! -exec test -e {} \; -print | xargs rm

# 問題: Zsh関数が読み込まれない
rm -f ~/.zcompdump*
compinit -u

# 問題: GPG鍵が見つからない
gpg --list-keys
git secret tell $EMAIL

# 問題: SSH接続が遅い
ssh -o ConnectTimeout=10 -o ServerAliveInterval=60 hostname
```

## 10. ベストプラクティスまとめ

### DOs ✅

1. **階層化**: 配管・中間・陶器層の明確な分離
2. **暗号化**: 機密情報は必ず暗号化
3. **自動化**: Makefile/スクリプトで再現性確保
4. **テスト**: CI/CDで品質保証
5. **文書化**: README/コメントの充実

### DON'Ts ❌

1. **機密情報の直接コミット禁止**
2. **バイナリファイルの追加を避ける**
3. **OS固有の処理をcore層に書かない**
4. **force pushの禁止（main/develop）**
5. **巨大ファイルの追加を避ける**

## まとめ

この構成により：
- **保守性**: 明確な構造と命名規則
- **セキュリティ**: 機密情報の適切な管理
- **可搬性**: クロスプラットフォーム対応
- **拡張性**: 段階的な機能追加が容易
- **再現性**: 自動化による環境構築

が実現され、長期的に持続可能な dotfiles 管理が可能になります。