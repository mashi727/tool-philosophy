# Foundation - 段階的改善のための基盤

このドキュメントは、ツール標準化における「変更困難な決定事項」を記録します。
これらは最初に決定し、以降は原則として変更しません。

## 1. ディレクトリ構造

```
$HOME/
├── .config/              # XDG Base Directory 準拠
│   ├── tools/           # 自作ツールの設定
│   │   ├── plumbing/    # 配管層スクリプト
│   │   ├── porcelain/   # 陶器層スクリプト
│   │   ├── middleware/  # OS差異吸収層
│   │   └── meta/        # メタデータ（依存関係等）
│   ├── zsh/            # Zsh設定と関数
│   │   ├── functions/   # Zsh関数群
│   │   └── completions/ # 補完定義
│   └── vendor/          # サードパーティツール設定
│
├── .claude/             # Claude Code設定
│   ├── commands/        # カスタムコマンド
│   ├── templates/       # コマンドテンプレート
│   └── CLAUDE.md        # Claude用設定
│
├── .local/
│   ├── bin/             # 実行可能ファイル
│   ├── share/tools/     # 共有データ
│   └── state/tools/     # 状態・ログファイル
│
└── Documents/
    └── tool-philosophy/ # このリポジトリ
        ├── journal/     # YYYY-MM-DD_*.md 形式の記録
        ├── specs/       # 仕様書・設計文書
        └── archive/     # 廃止されたツールの記録
```

## 2. 命名規則

### ファイル名
- 配管層: `plumb-*` (例: `plumb-calc-hash`)
- 中間層: `mid-*` (例: `mid-os-detect`)
- 陶器層: わかりやすい動詞-名詞形 (例: `sync-config`)

### 環境変数
```bash
# グローバル設定
export TOOLS_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/tools"
export TOOLS_BIN="${HOME}/.local/bin"
export TOOLS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/tools"

# 実行時設定
export TOOLS_DEBUG=0        # 0=off, 1=on, 2=verbose
export TOOLS_DRY_RUN=0      # 0=実行, 1=ドライラン
export TOOLS_INTERACTIVE=1  # 0=非対話, 1=対話的
```

## 3. エラーコード規約

```bash
# POSIX/BSD準拠のエラーコード
readonly EX_OK=0           # 成功
readonly EX_USAGE=64       # コマンドライン使用法エラー
readonly EX_DATAERR=65     # 入力データエラー
readonly EX_NOINPUT=66     # 入力ファイルが開けない
readonly EX_UNAVAILABLE=69 # サービス利用不可
readonly EX_SOFTWARE=70    # 内部ソフトウェアエラー
readonly EX_CANTCREAT=73   # 出力ファイル作成不可
readonly EX_CONFIG=78      # 設定エラー
```

## 4. ログフォーマット

### 活動ログ（構造化）
```bash
# ISO8601|PID|LEVEL|TOOL|MESSAGE
2024-01-15T10:30:45+09:00|12345|INFO|sync-config|Started
2024-01-15T10:30:46+09:00|12345|ERROR|sync-config|File not found: config.yml
```

### ログレベル
- `DEBUG`: デバッグ情報
- `INFO`: 通常の情報
- `WARN`: 警告
- `ERROR`: エラー（処理は継続）
- `FATAL`: 致命的エラー（処理中断）

## 5. バージョン管理

### セマンティックバージョニング
- 配管層: `MAJOR.MINOR.PATCH` - 後方互換性を厳密に管理
- 陶器層: `MAJOR.MINOR.PATCH` - ユーザー体験を重視
- 変更時は必ず `CHANGELOG.md` を更新

### バージョンファイル
```bash
$TOOLS_HOME/VERSION           # ツールシステム全体のバージョン
$TOOLS_HOME/plumbing/VERSION  # 配管層のバージョン
```

## 6. メタデータ仕様

### tool-meta.yml
```yaml
name: sync-config
version: 1.0.0
type: porcelain
description: "Synchronize configuration files"
author: "Your Name"
license: "MIT"
dependencies:
  required:
    - command: rsync
      version: ">=3.0"
    - command: sha256sum
  optional:
    - command: fzf
      purpose: "Interactive selection"
platforms:
  - macos
  - wsl2
  - linux
```

## 7. 不変の原則

これらは将来にわたって変更しない核心原則：

1. **テキストファースト**: すべての設定・データはテキスト形式
2. **標準入出力準拠**: stdin/stdout/stderr を正しく使用
3. **非破壊的デフォルト**: `--force` なしにデータを破壊しない
4. **監査可能性**: すべての操作をログに記録
5. **POSIX準拠**: 可能な限りPOSIX標準に従う

## 8. 初期化スクリプト

```bash
#!/usr/bin/env bash
# tools-init.sh - ツール環境の初期化

set -euo pipefail

# 基本ディレクトリの作成
mkdir -p "$HOME/.config/tools"/{plumbing,porcelain,middleware,meta}
mkdir -p "$HOME/.local/"{bin,share/tools,state/tools}

# バージョンファイルの作成
echo "0.1.0" > "$HOME/.config/tools/VERSION"

# 環境変数の設定（.bashrc/.zshrcに追加）
cat >> "$HOME/.bashrc" <<'EOF'
# Tool standardization environment
export TOOLS_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/tools"
export TOOLS_BIN="${HOME}/.local/bin"
export PATH="${TOOLS_BIN}:${PATH}"
EOF

echo "✓ Tool environment initialized"
```

## 改訂履歴

- 2024-11-18: 初版作成