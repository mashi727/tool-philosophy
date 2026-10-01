# Security Strategy - 機密情報とツール設定の管理

## 概要

公開可能な設定と機密情報を分離し、セキュアかつ実用的な管理を実現する。

## 1. 情報分類とリポジトリ分離

### Level 1: 公開可能（dotfiles）
- エディタ設定
- シェル設定
- XDG設定（機密情報を除く）
- SSH公開鍵とconfig
- ツールの一般設定

### Level 2: 限定公開（dotfiles-private）
- 個人的な設定
- 業務関連の非機密設定
- プロジェクト固有設定

### Level 3: 機密（dotfiles-secret）
- APIトークン
- SSH秘密鍵
- パスワード
- サーバー認証情報

## 2. 暗号化戦略

### 方法A: git-secret使用（推奨）

```bash
# 初期設定
brew install git-secret
cd ~/repos/dotfiles-secret

# git-secret初期化
git secret init

# GPG鍵の追加
git secret tell your-email@example.com

# ファイルの暗号化
git secret add tokens/notion.env
git secret hide  # 暗号化実行

# 復号化
git secret reveal
```

### 方法B: age暗号化（シンプル）

```bash
# age のインストール
brew install age

# 鍵生成
age-keygen -o ~/.config/age/keys.txt

# 暗号化
age -r $(age-keygen -y ~/.config/age/keys.txt) \
    -o tokens/notion.env.age \
    tokens/notion.env

# 復号化
age -d -i ~/.config/age/keys.txt \
    tokens/notion.env.age > tokens/notion.env
```

## 3. SSH鍵管理

### ディレクトリ構造

```bash
~/.ssh/
├── config              # dotfilesで管理
├── known_hosts        # 自動生成
├── authorized_keys    # サーバー側
├── keys/              # 秘密鍵用ディレクトリ
│   ├── personal/
│   │   ├── id_ed25519
│   │   └── id_ed25519.pub
│   └── work/
│       ├── id_rsa
│       └── id_rsa.pub
└── .gitignore         # keys/を除外
```

### SSH config 例

```ssh
# ~/.ssh/config
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/keys/personal/id_ed25519

Host coreserver
    HostName your-server.com
    User your-username
    IdentityFile ~/.ssh/keys/work/id_rsa
    Port 22
```

## 4. トークン管理

### 環境変数ファイル構造

```bash
# ~/.config/tokens/notion.env
export NOTION_API_KEY="secret_xxxxxxxxxxxxx"
export NOTION_DATABASE_ID="xxxxxxxxxxxxx"

# ~/.config/tokens/openai.env
export OPENAI_API_KEY="sk-xxxxxxxxxxxxx"
```

### 自動ロードスクリプト

```bash
# ~/.config/tools/load-tokens.sh
#!/usr/bin/env bash

TOKENS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tokens"

# 復号化されたトークンファイルをロード
if [ -d "$TOKENS_DIR" ]; then
    for env_file in "$TOKENS_DIR"/*.env; do
        [ -f "$env_file" ] && source "$env_file"
    done
fi

# ~/.zshrc に追加
source ~/.config/tools/load-tokens.sh
```

## 5. Python環境管理

### uv を使用した仮想環境管理

```bash
# プロジェクトテンプレート
project-template/
├── .python-version    # Python バージョン指定
├── pyproject.toml     # 依存関係定義
├── uv.lock           # ロックファイル（Git管理）
└── .venv/            # 仮想環境（.gitignore）
```

### グローバル設定

```bash
# ~/.config/uv/config.toml
[global]
index-url = "https://pypi.org/simple"
python-preference = "managed"  # uv管理のPython優先

[virtualenv]
prompt = "({project_name}-py{python_version})"
```

### プロジェクト初期化スクリプト

```bash
#!/usr/bin/env bash
# init-python-project.sh

project_name="$1"
python_version="${2:-3.12}"

# プロジェクトディレクトリ作成
mkdir -p "$project_name"
cd "$project_name"

# Python バージョン設定
echo "$python_version" > .python-version

# uv 初期化
uv venv
uv pip install -e .

# 基本的な pyproject.toml 作成
cat > pyproject.toml <<EOF
[project]
name = "$project_name"
version = "0.1.0"
requires-python = ">=${python_version}"
dependencies = []

[build-system]
requires = ["setuptools>=61", "wheel"]
build-backend = "setuptools.build_meta"
EOF
```

## 6. サーバー設定同期

### coreserver 管理構造

```bash
~/repos/server-configs/
├── coreserver/
│   ├── nginx/         # Web サーバー設定
│   ├── systemd/       # サービス設定
│   ├── scripts/       # 管理スクリプト
│   └── deploy.sh      # デプロイスクリプト
└── backup/
    └── backup.sh      # バックアップスクリプト
```

### 同期スクリプト例

```bash
#!/usr/bin/env bash
# sync-to-server.sh

SERVER="coreserver"
REMOTE_PATH="/home/user/configs"

# 設定ファイルの同期（rsync使用）
rsync -avz \
    --exclude='.git' \
    --exclude='*.secret' \
    ./coreserver/ \
    "${SERVER}:${REMOTE_PATH}/"

# リモートでの設定適用
ssh "$SERVER" "cd $REMOTE_PATH && ./apply-configs.sh"
```

## 7. バックアップとリカバリ

### 自動バックアップスクリプト

```bash
#!/usr/bin/env bash
# backup-secrets.sh

BACKUP_DIR="$HOME/Dropbox/backups/secrets"
DATE=$(date +%Y%m%d)

# 暗号化してバックアップ
tar czf - ~/.ssh/keys ~/.config/tokens | \
    age -r $(cat ~/.config/age/keys.txt | grep "public key:" | cut -d: -f2) \
    > "$BACKUP_DIR/secrets-$DATE.tar.gz.age"
```

### リカバリ手順

```bash
# 1. dotfiles のクローン
git clone https://github.com/username/dotfiles.git

# 2. 秘密情報の復号化
git clone https://github.com/username/dotfiles-secret.git
cd dotfiles-secret
git secret reveal  # または age -d

# 3. 設置スクリプト実行
./install.sh
```

## 8. セキュリティチェックリスト

- [ ] 秘密鍵は暗号化されているか
- [ ] .gitignore で機密ファイルを除外しているか
- [ ] トークンは環境変数経由で使用しているか
- [ ] SSH設定で鍵認証を強制しているか
- [ ] 定期的なローテーションを行っているか
- [ ] バックアップは暗号化されているか

## 9. 実装優先順位

1. **Phase 1**: 基本的な dotfiles 整備
2. **Phase 2**: SSH 設定の移行
3. **Phase 3**: トークン管理の実装
4. **Phase 4**: Python 環境の標準化
5. **Phase 5**: サーバー設定の統合