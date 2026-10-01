# GitHub CLI Integration - gh コマンドを活用した効率化

## 概要

GitHub CLI (`gh`) を活用することで、ターミナルから離れることなく GitHub の各種操作を実行できます。

## 1. 初期設定

### インストールと認証

```bash
# インストール
brew install gh  # macOS
sudo apt install gh  # Ubuntu/WSL2

# 認証
gh auth login

# 認証状態確認
gh auth status
```

### 設定カスタマイズ

```bash
# デフォルトエディタ設定
gh config set editor nvim

# デフォルトブラウザ設定
gh config set browser "open -a 'Google Chrome'"

# ページャー設定
gh config set pager less
```

## 2. リポジトリ管理

### リポジトリ作成

```bash
# プライベートリポジトリ作成
gh repo create my-project --private --clone

# テンプレートから作成
gh repo create my-app --template=user/template-repo --clone

# 組織配下に作成
gh repo create org-name/project --team=dev-team --private
```

### リポジトリ操作

```bash
# リポジトリ情報表示
gh repo view

# ブラウザで開く
gh repo view --web

# フォーク作成
gh repo fork owner/repo --clone

# リポジトリ削除（注意！）
gh repo delete owner/repo --confirm
```

## 3. PR ワークフロー

### PR 作成

```bash
# 基本的なPR作成
gh pr create --title "Add feature" --body "Description"

# ドラフトPR作成
gh pr create --draft --title "WIP: New feature"

# テンプレート使用
gh pr create --template=pull_request_template.md

# レビュアー指定
gh pr create --reviewer @user1,@user2

# ラベル付き
gh pr create --label bug,priority-high
```

### PR 管理

```bash
# PR一覧表示
gh pr list

# 自分がレビュアーのPR
gh pr list --search "review-requested:@me"

# PR詳細表示
gh pr view 123

# PR差分表示
gh pr diff 123

# PRチェックアウト
gh pr checkout 123

# PRマージ
gh pr merge 123 --squash --delete-branch
```

### PR レビュー

```bash
# レビュー承認
gh pr review 123 --approve

# コメント付きレビュー
gh pr review 123 --comment --body "Looks good, minor suggestions..."

# 変更要求
gh pr review 123 --request-changes --body "Please fix..."
```

## 4. Issue 管理

```bash
# Issue作成
gh issue create --title "Bug report" --label bug

# Issue一覧
gh issue list --assignee @me

# Issue詳細
gh issue view 42

# Issueクローズ
gh issue close 42 --comment "Fixed in PR #123"

# Issue再オープン
gh issue reopen 42
```

## 5. GitHub Actions

```bash
# ワークフロー一覧
gh workflow list

# ワークフロー実行
gh workflow run ci.yml

# 実行状況確認
gh run list

# ログ表示
gh run view 12345 --log

# 失敗したジョブの再実行
gh run rerun 12345 --failed
```

## 6. Release 管理

```bash
# リリース作成
gh release create v1.0.0 \
  --title "Version 1.0.0" \
  --notes "Release notes" \
  --target main

# アセット付きリリース
gh release create v1.0.0 \
  ./dist/*.zip \
  --title "Version 1.0.0"

# リリース一覧
gh release list

# 最新リリースダウンロード
gh release download --pattern "*.tar.gz"
```

## 7. Gist 管理

```bash
# Gist作成
gh gist create file.txt --public

# 複数ファイルのGist
gh gist create *.md --desc "Documentation files"

# Gist編集
gh gist edit <gist-id>

# Gist一覧
gh gist list --limit 10
```

## 8. 便利な Zsh 関数

```bash
# ~/.config/zsh/functions/github/gh-clone-org

gh-clone-org() {
    # 組織の全リポジトリをクローン
    local org="$1"
    local repos=$(gh repo list "$org" --limit 100 --json name -q '.[].name')

    for repo in $repos; do
        if [[ ! -d "$repo" ]]; then
            gh repo clone "$org/$repo"
        fi
    done
}

# ~/.config/zsh/functions/github/gh-pr-quick

gh-pr-quick() {
    # 素早くPR作成（最後のコミットメッセージを使用）
    local title=$(git log -1 --pretty=%B | head -1)
    local body=$(git log -1 --pretty=%B | tail -n +3)

    gh pr create --title "$title" --body "$body"
}

# ~/.config/zsh/functions/github/gh-cleanup-branches

gh-cleanup-branches() {
    # マージ済みブランチの削除
    gh pr list --state merged --json headRefName -q '.[].headRefName' | \
    while read branch; do
        git branch -d "$branch" 2>/dev/null && echo "Deleted: $branch"
    done
}

# ~/.config/zsh/functions/github/gh-sync-fork

gh-sync-fork() {
    # フォークを上流と同期
    local upstream=$(gh repo view --json parent -q '.parent.owner.login + "/" + .parent.name')

    if [[ -n "$upstream" ]]; then
        git fetch upstream
        git checkout main
        git merge upstream/main
        git push origin main
    fi
}
```

## 9. エイリアス設定

```bash
# ~/.config/gh/config.yml に追加
aliases:
  prs: pr list --author @me
  issues: issue list --assignee @me
  ci: workflow run ci.yml
  release-notes: |
    !gh api repos/:owner/:repo/releases/generate-notes \
      -f tag_name="$1" \
      -f target_commitish=main \
      --jq .body
```

## 10. CI/CD 統合

```yaml
# .github/workflows/auto-merge.yml
name: Auto-merge Dependabot PRs

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  auto-merge:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Auto-merge
        run: gh pr merge --auto --squash "${{ github.event.pull_request.number }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## まとめ

GitHub CLI を活用することで：
- ターミナルから離れずに GitHub 操作が完結
- スクリプト化による自動化が容易
- API を直接使うより簡潔な記述
- クロスプラットフォーム対応

これにより、開発ワークフローの大幅な効率化が実現できます。