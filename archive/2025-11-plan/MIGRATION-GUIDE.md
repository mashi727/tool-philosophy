# Migration Guide - 既存環境から標準化環境への移行

## 現状分析

### 既存のリソース
- **ツール群**: `~/works/git/tools/` (17個のツール)
- **Zsh関数**: `~/.config/zsh/functions/` (約20個の関数)
- **アプリ設定**: `~/.config/` 配下の各種設定

### デバイス環境
- **メイン**: MacBook Pro (日常開発)
- **サブ**: iPad Pro 13" (軽装時)
- **計算機**: Windows Workstation + WSL2 (GPU処理)

## 移行計画

### Phase 1: 環境準備（Day 1）

```bash
# 1. バックアップ作成
tar czf ~/Desktop/backup-$(date +%Y%m%d).tar.gz \
  ~/.config \
  ~/works/git/tools \
  ~/.ssh \
  ~/.zshrc

# 2. リポジトリ作成（Dropbox外）
mkdir -p ~/repos
cd ~/repos

# メインリポジトリ
gh repo create dotfiles --private --clone
gh repo create dotfiles-secure --private --clone

# 3. GPG設定
gpg --gen-key
cd dotfiles-secure && git secret init
```

### Phase 2: 基本構造の構築（Day 2）

```bash
cd ~/repos/dotfiles

# ディレクトリ構造作成
cat > setup-structure.sh << 'EOF'
#!/usr/bin/env bash
mkdir -p core/{plumbing,middleware,lib}
mkdir -p shell/zsh/functions/{dev,productivity,remote,media,pdf}
mkdir -p shell/zsh/completions
mkdir -p editors/{nvim,vscode}
mkdir -p terminal/{wezterm,tmux}
mkdir -p claude/commands/{dev,review,debug}
mkdir -p tools/{integrated,standalone}
mkdir -p docker/{luatex,whisper,services}
mkdir -p scripts/{install,backup,sync}
mkdir -p tests
EOF

chmod +x setup-structure.sh && ./setup-structure.sh
```

### Phase 3: ツール移行（Day 3-5）

#### 優先度別移行リスト

**最優先（毎日使用）**
```bash
# 1. rehearsal-workflow
cp -r ~/works/git/tools/rehearsal-workflow tools/integrated/
cp ~/.config/zsh/functions/rehearsal-* shell/zsh/functions/remote/

# 2. luatex-docker-remote
cp -r ~/works/git/tools/luatex-docker-remote tools/integrated/
cp ~/.config/zsh/functions/luatex-* shell/zsh/functions/remote/

# 3. PDF処理群
cp ~/.config/zsh/functions/pdf-*.zsh shell/zsh/functions/pdf/
```

**中優先（週次使用）**
```bash
# メディア処理
cp -r ~/works/git/tools/movie-viewer tools/standalone/
cp -r ~/works/git/tools/video-chapter-splitter tools/standalone/
cp ~/.config/zsh/functions/convert-*.zsh shell/zsh/functions/media/

# テキスト処理
cp -r ~/works/git/tools/markdown-uploader tools/standalone/
cp -r ~/works/git/tools/deepl-cli tools/standalone/
```

**低優先（特定用途）**
```bash
# アーカイブ・バックアップ
cp -r ~/works/git/tools/finale-backup tools/standalone/
cp -r ~/works/git/tools/fb-video-downloader tools/standalone/
```

### Phase 4: 設定ファイル統合（Day 6）

```bash
# Neovim設定
cp -r ~/.config/nvim/* ~/repos/dotfiles/editors/nvim/

# Wezterm設定
cp ~/.config/wezterm/* ~/repos/dotfiles/terminal/wezterm/

# Git設定（機密情報確認）
cp ~/.gitconfig ~/repos/dotfiles/git/
grep -E "token|password|key" ~/.gitconfig  # 確認

# SSH設定（公開鍵のみ）
cp ~/.ssh/config ~/repos/dotfiles/ssh/
cp ~/.ssh/*.pub ~/repos/dotfiles/ssh/public_keys/
```

### Phase 5: 機密情報の分離（Day 7）

```bash
cd ~/repos/dotfiles-secure

# SSH秘密鍵
cp ~/.ssh/id_* secrets/ssh/keys/
git secret add secrets/ssh/keys/id_*

# トークン類
cat > secrets/tokens/github.env << EOF
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
EOF
git secret add secrets/tokens/*.env

# 暗号化
git secret hide
```

### Phase 6: インストールスクリプト作成（Day 8）

```bash
cd ~/repos/dotfiles

cat > Makefile << 'EOF'
.PHONY: all install test clean backup

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')

all: install

install:
	@echo "🚀 Installing dotfiles..."
	@./scripts/install/main.sh
	@$(MAKE) link
	@$(MAKE) compile

link:
	@echo "🔗 Creating symlinks..."
	@./scripts/install/symlinks.sh

compile:
	@echo "⚡ Compiling Zsh functions..."
	@zcompile shell/zsh/.zshrc
	@find shell/zsh/functions -name "*.zsh" -exec zcompile {} \;

test:
	@echo "🧪 Running tests..."
	@shellcheck scripts/**/*.sh
	@./tests/run-all.sh

backup:
	@echo "💾 Creating backup..."
	@./scripts/backup/create-bundle.sh

clean:
	@echo "🧹 Cleaning..."
	@find . -name "*.zwc" -delete
	@find . -name ".DS_Store" -delete
EOF
```

### Phase 7: テストと切り替え（Day 9-10）

```bash
# 1. ドライラン
cd ~/repos/dotfiles
make test

# 2. 段階的切り替え
mv ~/.config ~/.config.backup
ln -s ~/repos/dotfiles/shell/zsh ~/.config/zsh

# 3. 動作確認
source ~/.zshrc
type luatex-remote  # 関数確認
which nvim          # パス確認

# 4. 完全切り替え
make install
```

## クイックスタートコマンド

最小限の移行を今すぐ始めるためのコマンド：

```bash
# 一括実行スクリプト
curl -fsSL https://github.com/mashi727/tool-philosophy/raw/main/scripts/quick-start.sh | bash
```

または手動実行：

```bash
# Step 1: リポジトリ準備
mkdir -p ~/repos && cd ~/repos
gh repo create dotfiles --private --clone

# Step 2: 基本構造作成
cd dotfiles
mkdir -p shell/zsh/functions tools scripts

# Step 3: 最重要ツールのみ移行
cp -r ~/works/git/tools/luatex-docker-remote tools/
cp ~/.config/zsh/functions/*.zsh shell/zsh/functions/

# Step 4: 初回コミット
git add -A
git commit -m "feat: Initial migration from existing tools"
git push

# Step 5: シンボリックリンク作成
ln -sfn ~/repos/dotfiles/shell/zsh ~/.config/zsh-new
```

## チェックリスト

### 移行前
- [ ] 完全バックアップ作成済み
- [ ] GPG鍵生成済み
- [ ] GitHub CLI認証済み
- [ ] 作業時間確保（2-3時間）

### 移行中
- [ ] リポジトリ作成（dotfiles, dotfiles-secure）
- [ ] ディレクトリ構造作成
- [ ] ツール移行（優先度順）
- [ ] 設定ファイル移行
- [ ] 機密情報分離・暗号化
- [ ] インストールスクリプト作成

### 移行後
- [ ] 基本コマンド動作確認
- [ ] SSH接続テスト
- [ ] エディタ起動確認
- [ ] リモートコンパイル確認
- [ ] iPad接続確認

## トラブルシューティング

### 問題: Zsh関数が見つからない
```bash
# FPATHの確認
echo $FPATH

# 再コンパイル
rm ~/.zcompdump*
autoload -U compinit && compinit
```

### 問題: シンボリックリンクが壊れた
```bash
# 既存リンクの削除
find ~ -type l ! -exec test -e {} \; -delete

# 再作成
cd ~/repos/dotfiles && make link
```

### 問題: GPG復号化エラー
```bash
# GPG鍵の確認
gpg --list-secret-keys

# git-secretの再設定
cd ~/repos/dotfiles-secure
git secret tell $(git config user.email)
git secret reveal
```

## 成果物と次のステップ

### 完了後の成果物
- 標準化されたツール環境
- バージョン管理された設定
- 暗号化された機密情報
- 自動インストールシステム

### 継続的改善
1. CI/CD の追加（GitHub Actions）
2. テストカバレッジの向上
3. ドキュメントの充実
4. パフォーマンス最適化

## サポート

問題が発生した場合：
1. journal/ディレクトリに記録を残す
2. GitHubのIssueで管理
3. ロールバック手順の確認