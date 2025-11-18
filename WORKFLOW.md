# Workflow - リポジトリ更新と運用環境への適用

## 概要

dotfiles の更新から本番環境への適用まで、安全で効率的なワークフローを定義します。

## ワークフロー図

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   開発      │────▶│   テスト    │────▶│   本番      │
│  (feature)  │     │  (develop)  │     │   (main)    │
└─────────────┘     └─────────────┘     └─────────────┘
      ↓                   ↓                   ↓
   ローカル            ステージング         全デバイス
   テスト              環境テスト           自動適用
```

## 1. 日常的な更新フロー

### 1.1 小規模な変更（関数追加、設定微調整）

```bash
# 1. 作業ブランチ作成
cd ~/repos/dotfiles
git checkout -b feature/add-new-function

# 2. 変更実施
vim shell/zsh/functions/productivity/new-function.zsh

# 3. ローカルテスト
source shell/zsh/functions/productivity/new-function.zsh
new-function test  # 動作確認

# 4. コミット
git add -A
git commit -m "feat(zsh): Add new-function for improved workflow"

# 5. メインブランチへマージ
git checkout main
git merge --no-ff feature/add-new-function
git push

# 6. 他デバイスへ適用
ssh mac "cd ~/repos/dotfiles && git pull && make install"
ssh wsl "cd ~/repos/dotfiles && git pull && make install"
```

### 1.2 設定ファイルの更新

```bash
# 1. 直接編集（緊急時）
cd ~/repos/dotfiles
vim editors/nvim/init.lua

# 2. 即座にテスト
nvim  # 動作確認

# 3. 問題なければコミット
git add -A
git commit -m "fix(nvim): Fix syntax highlighting issue"
git push

# 4. 自動同期（後述のhookで自動化可能）
```

## 2. 大規模な変更フロー

### 2.1 新ツール追加

```bash
# 1. developブランチで開発
git checkout develop
git checkout -b feature/new-tool

# 2. ツール追加
mkdir -p tools/standalone/my-new-tool
cp -r ~/workspace/my-new-tool/* tools/standalone/my-new-tool/

# 3. ドキュメント作成
cat > tools/standalone/my-new-tool/README.md << 'EOF'
# My New Tool
## Installation
## Usage
## Dependencies
EOF

# 4. テスト追加
cat > tests/test-my-new-tool.sh << 'EOF'
#!/usr/bin/env bash
# Test script
EOF

# 5. ステージング環境でテスト
docker run -it -v $(pwd):/dotfiles ubuntu:22.04 bash
cd /dotfiles && make test

# 6. PR作成
gh pr create --title "feat: Add my-new-tool" \
  --body "Add new tool for X functionality"

# 7. レビュー後マージ
gh pr merge --squash
```

## 3. 自動適用システム

### 3.1 Git Hooks を使用した自動更新

```bash
# ~/.config/dotfiles-updater/post-merge
#!/usr/bin/env bash
# Git pull 後に自動実行されるフック

echo "🔄 Applying dotfiles updates..."

# Zsh関数の再コンパイル
zcompile ~/.config/zsh/.zshrc
find ~/.config/zsh/functions -name "*.zsh" -exec zcompile {} \;

# tmuxリロード
tmux source-file ~/.tmux.conf 2>/dev/null || true

# 通知
echo "✅ Dotfiles updated successfully"
```

### 3.2 定期同期スクリプト

```bash
#!/usr/bin/env bash
# ~/repos/dotfiles/scripts/sync-all.sh

sync_dotfiles() {
    local host="$1"

    echo "🔄 Syncing to $host..."

    ssh "$host" << 'REMOTE_SCRIPT'
        cd ~/repos/dotfiles

        # 現在の状態を保存
        git stash push -m "Auto-stash before sync $(date +%Y%m%d-%H%M%S)"

        # 最新を取得
        git pull --rebase

        # インストール実行
        make install

        # スタッシュを復元（ローカル変更がある場合）
        git stash pop 2>/dev/null || true

        # 再起動が必要なサービスをリロード
        systemctl --user daemon-reload 2>/dev/null || true

        echo "✅ Sync complete on $(hostname)"
REMOTE_SCRIPT
}

# 全デバイスに適用
for host in mac wsl workstation; do
    sync_dotfiles "$host" &
done

wait
echo "✅ All devices synced"
```

### 3.3 Cron による自動更新

```bash
# crontab -e で追加
# 毎日午前3時に自動更新
0 3 * * * ~/repos/dotfiles/scripts/auto-update.sh

# auto-update.sh
#!/usr/bin/env bash
LOG_FILE="$HOME/.local/state/dotfiles-update.log"

{
    echo "=== Update started at $(date) ==="

    cd ~/repos/dotfiles

    # 更新チェック
    git fetch

    if [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]; then
        # 更新あり
        git pull --rebase
        make install
        echo "✅ Updated to $(git rev-parse --short HEAD)"
    else
        echo "ℹ️  Already up to date"
    fi

    echo "=== Update finished at $(date) ==="
    echo ""
} >> "$LOG_FILE" 2>&1
```

## 4. ロールバック戦略

### 4.1 即座のロールバック

```bash
# 問題が発生した場合
cd ~/repos/dotfiles

# 直前のコミットに戻る
git revert HEAD
git push

# または特定バージョンに戻る
git checkout v1.2.3
make install
```

### 4.2 バックアップからの復旧

```bash
# 定期バックアップから復旧
cd ~/repos
tar xzf ~/Dropbox/Backups/dotfiles-20240315.tar.gz
cd dotfiles
make install
```

## 5. CI/CD パイプライン

### 5.1 GitHub Actions 設定

```yaml
# .github/workflows/ci.yml
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
          if [ "$RUNNER_OS" == "macOS" ]; then
            brew install shellcheck
          else
            sudo apt-get update
            sudo apt-get install -y shellcheck
          fi

      - name: Run tests
        run: make test

      - name: Test installation
        run: make install DESTDIR=/tmp/test-install

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v3

      - name: Create release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: |
            scripts/install.sh
            scripts/quick-start.sh
```

### 5.2 自動デプロイトリガー

```bash
# タグプッシュで自動リリース
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0

# 全デバイスへ通知
for host in mac wsl workstation; do
    ssh "$host" "notify-send 'Dotfiles Update' 'Version 1.2.0 available'"
done
```

## 6. ブランチ戦略

### メインブランチ
- `main`: 安定版（全デバイスで使用）
- `develop`: 開発版（テスト環境で使用）
- `feature/*`: 機能開発
- `hotfix/*`: 緊急修正

### ブランチルール

```bash
# GitHub でブランチ保護設定
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["continuous-integration"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'
```

## 7. 監視とログ

### 7.1 更新ログの確認

```bash
# 最近の更新を確認
cd ~/repos/dotfiles
git log --oneline -10

# 特定ファイルの変更履歴
git log -p shell/zsh/functions/

# 差分確認
git diff HEAD~1
```

### 7.2 適用状態の確認

```bash
#!/usr/bin/env bash
# ~/repos/dotfiles/scripts/check-status.sh

check_device_status() {
    local host="$1"

    echo "Checking $host..."
    ssh "$host" "cd ~/repos/dotfiles && git rev-parse --short HEAD"
}

echo "=== Dotfiles Status ==="
echo "Local: $(cd ~/repos/dotfiles && git rev-parse --short HEAD)"

for host in mac wsl workstation; do
    echo "$host: $(check_device_status $host)"
done
```

## 8. トラブルシューティング

### 同期の競合

```bash
# マージコンフリクトの解決
git status  # 競合ファイル確認
vim <conflicted-file>  # 手動解決
git add <conflicted-file>
git commit
```

### 破損時の復旧

```bash
# Git リポジトリの修復
cd ~/repos/dotfiles
git fsck --full
git gc --prune=now

# 完全リセット（最終手段）
cd ~/repos
mv dotfiles dotfiles.broken
gh repo clone dotfiles
```

## 9. ベストプラクティス

### DO ✅
1. 小さく頻繁にコミット
2. 意味のあるコミットメッセージ
3. テストしてからプッシュ
4. 定期的なバックアップ
5. 変更ログの記録

### DON'T ❌
1. mainブランチへの直接プッシュ（大規模変更時）
2. テストなしの自動更新
3. 機密情報のコミット
4. 巨大ファイルの追加
5. 履歴の書き換え（force push）

## 10. 運用メトリクス

### 追跡すべき指標

```bash
# 更新頻度
git log --since="1 month ago" --oneline | wc -l

# 最もよく変更されるファイル
git log --pretty=format: --name-only | sort | uniq -c | sort -rn | head -10

# コントリビューター統計
git shortlog -sn

# リポジトリサイズ
du -sh .git
```

## まとめ

このワークフローにより：
- **開発→テスト→本番** の段階的な適用
- **自動化** による運用負荷の軽減
- **ロールバック** による安全性の確保
- **監視** による状態の可視化

が実現され、安全で効率的なdotfiles管理が可能になります。