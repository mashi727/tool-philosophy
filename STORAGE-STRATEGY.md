# Storage Strategy - Dropbox と Git の使い分け戦略

## 基本方針

GitリポジトリはDropbox外で管理し、作業ファイルと成果物をDropboxで同期する。

## 推奨ディレクトリ構造

```bash
# ローカル（Dropbox外）- Git管理
~/repos/                           # すべてのGitリポジトリ
├── dotfiles/                     # 設定ファイル
├── dotfiles-secure/              # 暗号化された機密情報
├── infrastructure/               # サーバー設定
└── tools/                        # 自作ツール群

# Dropbox - ファイル同期
~/Dropbox/
├── 01_Projects/                  # プロジェクト管理
│   ├── 00_Works/                # 作業ファイル
│   │   ├── documents/           # 文書作成
│   │   ├── presentations/       # プレゼン資料
│   │   └── exports/            # エクスポート済み成果物
│   └── archive/                 # アーカイブ
├── 02_Settings/                  # 設定バックアップ（Git以外）
│   ├── app-preferences/         # アプリ設定
│   ├── licenses/               # ライセンスファイル
│   └── fonts/                  # カスタムフォント
└── 03_Backups/                   # 定期バックアップ
    ├── git-bundles/             # Gitバンドルバックアップ
    └── config-snapshots/        # 設定スナップショット
```

## Git と Dropbox の役割分担

### Git で管理すべきもの

1. **ソースコード**
   - スクリプト、プログラム
   - 設定ファイル（dotfiles）
   - ドキュメント（Markdown）

2. **バージョン管理が重要なもの**
   - 変更履歴の追跡が必要
   - ブランチ・マージが必要
   - コラボレーションが必要

### Dropbox で管理すべきもの

1. **バイナリファイル**
   - 画像、動画、音声
   - PDFなどの成果物
   - Office文書

2. **大容量ファイル**
   - データセット
   - バックアップアーカイブ
   - メディアファイル

3. **即座の同期が必要なもの**
   - 作業中のメモ
   - 共有ドキュメント
   - 一時ファイル

## 実装パターン

### パターン1: Git + Dropbox エクスポート

```bash
#!/usr/bin/env bash
# Git で開発 → 成果物を Dropbox へエクスポート

# LaTeX プロジェクトの例
cd ~/repos/my-paper
make pdf  # PDFを生成
cp output/*.pdf ~/Dropbox/01_Projects/00_Works/papers/

# ツールのリリースビルド
cd ~/repos/my-tool
make build
cp -r dist/* ~/Dropbox/01_Projects/00_Works/releases/
```

### パターン2: Dropbox → Git インポート

```bash
#!/usr/bin/env bash
# Dropbox の作業ファイルを Git にインポート

# ドキュメントの Git 管理開始
cd ~/Dropbox/01_Projects/00_Works/documents/project-x
git init
git add -A
git commit -m "Initial import from Dropbox"

# リモートリポジトリへ移行
git remote add origin git@github.com:user/project-x.git
git push -u origin main

# 元ファイルを Git 管理に切り替え
mv ~/Dropbox/01_Projects/00_Works/documents/project-x ~/repos/
ln -s ~/repos/project-x ~/Dropbox/01_Projects/00_Works/documents/
```

### パターン3: Git Bundle バックアップ

```bash
#!/usr/bin/env bash
# Git リポジトリを Dropbox にバックアップ（bundle形式）

backup_git_to_dropbox() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local backup_dir="$HOME/Dropbox/03_Backups/git-bundles"
    local date=$(date +%Y%m%d)

    mkdir -p "$backup_dir"

    cd "$repo_path"
    git bundle create "$backup_dir/${repo_name}-${date}.bundle" --all

    echo "✓ Backed up $repo_name to Dropbox"
}

# 全リポジトリをバックアップ
for repo in ~/repos/*/; do
    backup_git_to_dropbox "$repo"
done
```

## 同期設定の最適化

### Dropbox の選択的同期

```bash
# .dropboxignore の設定例
# Dropbox に同期しないパターン

# Git 関連
.git/
*.git

# ビルド成果物
node_modules/
__pycache__/
*.pyc
.venv/

# 一時ファイル
*.tmp
*.swp
.DS_Store

# 大容量の依存関係
vendor/
bower_components/
```

### Git の Dropbox 除外

```bash
# ~/.gitconfig_global

[core]
    # Dropbox 内では Git を初期化しない
    excludesfile = ~/.gitignore_global

# ~/.gitignore_global
.dropbox
.dropbox.cache/
Icon\r
```

## シンボリックリンクの活用

```bash
# Dropbox 内から Git リポジトリを参照

# プロジェクトドキュメントのリンク
ln -s ~/repos/project/docs ~/Dropbox/01_Projects/00_Works/project-docs

# 最新ビルドのリンク
ln -s ~/repos/tool/dist/latest ~/Dropbox/01_Projects/00_Works/tools/latest-build

# 設定ファイルの参照
ln -s ~/repos/dotfiles/configs ~/Dropbox/02_Settings/active-configs
```

## 自動化スクリプト

### 日次バックアップ

```bash
#!/usr/bin/env bash
# ~/repos/dotfiles/scripts/daily-backup.sh

# Git の変更を Dropbox にバックアップ
daily_backup() {
    local backup_dir="$HOME/Dropbox/03_Backups/daily/$(date +%Y-%m-%d)"
    mkdir -p "$backup_dir"

    # 各リポジトリの状態を保存
    for repo in ~/repos/*/; do
        repo_name=$(basename "$repo")
        cd "$repo"

        # 未コミットの変更を保存
        if [[ -n $(git status --porcelain) ]]; then
            git stash push -m "Daily backup $(date +%Y-%m-%d)"
            git stash show -p > "$backup_dir/${repo_name}-stash.patch"
            git stash pop
        fi

        # 現在のブランチ情報
        git branch -v > "$backup_dir/${repo_name}-branches.txt"
    done
}

# cron で毎日実行
# 0 23 * * * /Users/username/repos/dotfiles/scripts/daily-backup.sh
```

## トラブルシューティング

### 問題: Dropbox 同期の遅延
**解決策**: Git push 後に明示的に同期
```bash
git push && dropbox sync
```

### 問題: シンボリックリンクが機能しない
**解決策**: ハードリンクまたはスクリプトで同期
```bash
rsync -av ~/repos/project/output/ ~/Dropbox/01_Projects/output/
```

### 問題: .git ディレクトリが同期された
**解決策**: 即座に削除して Git bundle で復旧
```bash
rm -rf ~/Dropbox/project/.git
cd ~/Dropbox/03_Backups/git-bundles/
git clone project-latest.bundle ~/repos/project-recovered
```

## まとめ

### DO ✅
- Git リポジトリは `~/repos/` に配置
- 成果物のみ Dropbox に配置
- Git bundle でバックアップ
- シンボリックリンクで連携

### DON'T ❌
- Dropbox 内で `git init` しない
- .git ディレクトリを同期しない
- 大容量バイナリを Git 管理しない
- 同一ファイルを両方で管理しない

この戦略により、Git の強力なバージョン管理と Dropbox の便利な同期機能を、それぞれの長所を活かして使い分けることができます。