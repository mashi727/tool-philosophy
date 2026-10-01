# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**The Philosophy of Computer Using** - コンピューター使用における生産性向上のための継続的改善プロジェクト

このリポジトリは、使用するコンピューターにおける自作ツールを含む様々なツールの標準化に関する：
- 考え方（philosophy）
- 理由と背景（rationale and background）
- 時系列的な記録（chronological documentation）

を体系的に記録し、自身の生産性向上を継続的に実現することを目的としています。

### 基本設計思想

**UNIX哲学**と**Gitの実装思想**を参考にした標準化：
- 一つのことを上手くやる（Do One Thing Well）
- テキストストリームを普遍的インターフェースとする
- 早期プロトタイピングと反復的改善
- ポータビリティの重視
- コンポーザビリティ（組み合わせ可能性）の確保

### クロスプラットフォーム対応方針

環境構成と対応レベル：
1. **macOS**: 主要開発環境（完全対応）
2. **WSL2 Ubuntu**: macOSと完全互換性を確保（シェル環境・CLIツール）
3. **Windows Native**: GUI アプリケーションのみ対応（シェル環境は対象外）
4. **iPad (Blink/Terminus)**: SSH/mosh 経由でWSL2/macOSにアクセス

#### 環境別の役割分担
- **macOS / WSL2 Ubuntu**:
  - シェルスクリプト、dotfiles、CLIツールの完全互換
  - 開発環境の統一化
  - tmux による永続セッション管理
- **Windows Native**:
  - VSCode、Docker Desktop などの GUI アプリケーション
  - Electron/Tauri ベースのクロスプラットフォームアプリ
  - WSL2 との連携を前提とした高機能ツール
- **iPad**:
  - Blink Shell による SSH/mosh 接続
  - Tailscale によるセキュアアクセス
  - 緊急時の作業環境として機能

## Repository Structure

Expected content organization:
- **時系列ドキュメント**: ツール導入・標準化の決定事項とその理由を日付順に記録
- **ツール設定ファイル**: 標準化された各種ツールの設定（dotfiles, configurations）
- **実装スクリプト**: 生産性向上のための自作ツール・自動化スクリプト
- **評価と振り返り**: 導入したツールの効果測定と改善記録
- **クロスプラットフォーム対応**: OS別の実装差異と対応方法の記録

## Tool Standardization Guidelines

### 階層化アーキテクチャ

ツールを3層に分離して実装：

```
┌─────────────────────────────────────┐
│  陶器層（Porcelain）                  │ ← ユーザー向けインターフェース
│  - インタラクティブコマンド            │
│  - 統合ツール、ワークフロー自動化      │
├─────────────────────────────────────┤
│  中間層（Middleware）                 │ ← 抽象化とアダプター
│  - OS差異の吸収                      │
│  - 共通インターフェース定義           │
├─────────────────────────────────────┤
│  配管層（Plumbing）                   │ ← 基本的な操作
│  - 原子的操作                        │
│  - 単一責任のユーティリティ           │
└─────────────────────────────────────┘
```

### 対象ツール
- **エディタ**: Vim/Neovim, VSCode, Emacs等の設定標準化
- **ターミナル**: シェル環境（zsh/bash）、ターミナルエミュレータ設定
- **開発ツール**: Git, Docker, 各種言語環境
- **自作ツール**: シェルスクリプト、Python/Go製CLIツール

### 標準化の原則
1. **設定のテキスト化**: すべての設定をテキストファイルで管理（バージョン管理可能）
2. **環境変数の活用**: OS依存部分は環境変数で吸収
3. **モジュール化**: 機能単位での分割と組み合わせ
4. **冪等性**: 何度実行しても同じ結果になる設定・スクリプト
5. **自己文書化**: 設定ファイル内にコメントで意図を明記
6. **階層的実装**: 配管層→中間層→陶器層の順で構築

### 具体的な実装パターン

#### 例：ファイル同期ツールの階層化実装

```bash
# ========== 配管層（Plumbing） ==========
# 単一責任、機械可読な出力

plumb_calc_checksum() {
    # ファイルのチェックサム計算（単一責任）
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

plumb_copy_file() {
    # ファイルコピー（エラーコード返却のみ）
    cp -p "$1" "$2" 2>/dev/null
}

plumb_list_files() {
    # ファイルリスト取得（NULL区切り出力）
    find "$1" -type f -print0 2>/dev/null
}

# ========== 中間層（Middleware） ==========
# OS差異の吸収、共通インターフェース

mid_get_timestamp() {
    case "$(uname -s)" in
        Darwin) stat -f "%m" "$1" ;;
        Linux)  stat -c "%Y" "$1" ;;
    esac
}

mid_ensure_directory() {
    local dir="$1"
    [ -d "$dir" ] || mkdir -p "$dir"
}

# ========== 陶器層（Porcelain） ==========
# ユーザー向け、インタラクティブ

sync_configs() {
    local source="${1:-$HOME/.config}"
    local dest="${2:-$HOME/Dropbox/configs}"

    echo "🔄 Syncing configurations..."
    echo "  Source: $source"
    echo "  Destination: $dest"

    # 中間層と配管層の組み合わせ
    mid_ensure_directory "$dest"

    local count=0
    while IFS= read -r -d '' file; do
        local rel_path="${file#$source/}"
        local dest_file="$dest/$rel_path"

        if plumb_copy_file "$file" "$dest_file"; then
            ((count++))
            echo "  ✓ $rel_path"
        else
            echo "  ✗ $rel_path (failed)" >&2
        fi
    done < <(plumb_list_files "$source")

    echo "📊 Synced $count files successfully"
}
```

### クロスプラットフォーム実装戦略

#### シェル環境（macOS / WSL2 Ubuntu）
```bash
# OS判定の標準パターン（WSL2とネイティブLinuxの区別含む）
if [[ "$(uname -s)" == "Darwin" ]]; then
    OS="macos"
elif [[ "$(uname -s)" == "Linux" ]]; then
    if grep -q microsoft /proc/version 2>/dev/null; then
        OS="wsl2"
    else
        OS="linux"
    fi
fi

# 条件分岐による対応
if [ "$OS" = "macos" ]; then
    # macOS specific
    HOMEBREW_PREFIX="/opt/homebrew"
elif [ "$OS" = "wsl2" ]; then
    # WSL2 Ubuntu specific
    HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi
```

#### GUI アプリケーション（全プラットフォーム対応）
- **Electron/Tauri アプリ**: package.json でビルドターゲットを定義
- **Python GUI（PySide6/PyQt）**: プラットフォーム検出による条件分岐
- **設定の同期**: クラウドストレージまたは Git による設定共有

## Document Preparation

### LaTeX Compilation
For Japanese and English mixed documents:
```bash
lualatex document.tex
```

For Japanese-primary documents:
```bash
lualatex-ja document.tex
```

### LuaLaTeX Font Configuration

Standard font setup for documents in this repository:

```latex
% LuaLaTeX用フォント設定パッケージ
\usepackage{luatexja-fontspec}
\usepackage{amsmath,amssymb}
\usepackage{unicode-math}

% 欧文フォント設定 (Libertinus)
\setmainfont{Libertinus Serif}[
    BoldFont = {Libertinus Serif Bold},
    ItalicFont = {Libertinus Serif Italic},
    BoldItalicFont = {Libertinus Serif Bold Italic}
]
\setsansfont{Libertinus Sans}[
    BoldFont = {Libertinus Sans Bold},
    ItalicFont = {Libertinus Sans Italic}
]
\setmonofont{Libertinus Mono}

% 日本語フォント設定 (原ノ味フォント)
\setmainjfont{HaranoAjiMincho-Regular}[
    BoldFont = {HaranoAjiGothic-Medium},
    ItalicFont = {HaranoAjiMincho-Regular},
    BoldItalicFont = {HaranoAjiGothic-Bold}
]
\setsansjfont{HaranoAjiGothic-Regular}[
    BoldFont = {HaranoAjiGothic-Bold}
]
\setmonojfont{HaranoAjiGothic-Regular}

% 数式フォント設定 (Libertinus Math)
\setmathfont{Libertinus Math}
```

## Output Conventions

- When processing prompt files: Output files should be saved in Markdown format with "_A" suffix replacing any "_P" suffix in the input filename
- Citations and references must include primary sources with proper footnote-style formatting
- For LuaTeX output, all citations must include web URLs and literature references in footnote style

## Language Guidelines

- Primary language follows user's native language (Japanese/English based on context)
- Technical terminology should use professionally correct terms, not colloquial expressions
- Maintain clear distinction between facts and speculation

## Documentation Guidelines

### 時系列記録の形式
- ファイル名: `YYYY-MM-DD_topic.md` 形式で記録
- 各エントリーには以下を含める：
  - 導入・変更したツール名
  - 採用理由と期待される効果
  - 実装方法・設定内容
  - 参考資料・情報源

### ツール評価基準
- **生産性への影響度**: 実際の作業効率改善の度合い
- **学習コスト**: 習得に必要な時間と労力
- **保守性・持続可能性**: 長期的なメンテナンスの容易さ
- **他ツールとの統合性**: UNIX的な組み合わせ可能性
- **クロスプラットフォーム対応度**: macOS/Linux/Windows間での動作互換性

### Gitに学ぶ設計原則

#### 配管（Plumbing）と陶器（Porcelain）の思想
Gitの最も重要な設計思想である「低レベルの堅牢な配管コマンド」と「高レベルの使いやすい陶器コマンド」の分離を採用：

**配管層（Plumbing Layer）**：
- 単一責任の低レベルコマンド
- 機械的に解析可能な出力
- 後方互換性の保証
- エラーハンドリングの明確化

**陶器層（Porcelain Layer）**：
- 人間に優しいインターフェース
- 複数の配管コマンドの組み合わせ
- インタラクティブな操作
- 状況に応じた賢いデフォルト値

#### 実装例
```bash
# 配管層：基本的なファイル操作
plumbing_read_file() {
    cat "$1" 2>/dev/null || echo ""
}

plumbing_write_file() {
    printf "%s" "$2" > "$1"
}

plumbing_file_hash() {
    sha256sum "$1" | cut -d' ' -f1
}

# 陶器層：ユーザー向け設定管理
config_save() {
    local config_file="$1"
    local backup_dir="$HOME/.config/backups"

    # 配管コマンドの組み合わせ
    local hash=$(plumbing_file_hash "$config_file")
    local backup_path="$backup_dir/$(date +%Y%m%d)_${hash:0:8}"

    mkdir -p "$backup_dir"
    plumbing_read_file "$config_file" | plumbing_write_file "$backup_path"

    echo "✓ Configuration saved: ${backup_path##*/}"
}
```

#### その他のGit設計原則
- **コンテンツアドレッシング**: 設定の一意性と再現性
- **不変性**: 一度作成した設定の履歴を保持
- **分散性**: 各環境で独立して動作可能
- **効率性**: 差分管理による効率的な同期

## Implementation Challenges and Solutions

### 既知の課題と対応方針

#### 1. プラットフォーム差異
- **パス区切り文字**: `$HOME` 変数の活用、絶対パス回避
- **改行コード**: Git の `core.autocrlf` 設定で統一
- **実行権限**: `chmod +x` をスクリプト内で明示

#### 2. 依存関係管理
```bash
# 最小限の必須ツールを定義
REQUIRED_COMMANDS="git bash curl"
for cmd in $REQUIRED_COMMANDS; do
    command -v $cmd >/dev/null 2>&1 || {
        echo "Error: $cmd is required but not installed"
        exit 1
    }
done
```

#### 3. 設定のロールバック
```bash
# 設定変更前の自動バックアップ
backup_config() {
    local config_file="$1"
    cp "$config_file" "$config_file.$(date +%Y%m%d_%H%M%S).bak"
}
```

### 測定可能な成功指標
- **導入効果**: タスクごとの所要時間記録と比較
- **エラー削減**: インシデント数の月次集計
- **学習曲線**: 新規ツール習得にかかった実時間記録

## Development Notes

このプロジェクトは0000プレフィックスを使用し、作業環境の基盤となる哲学的・方法論的プロジェクトとして位置づけられています。継続的な改善と記録を通じて、長期的な生産性向上を実現します。

### 改善サイクル
1. **観察**: 現状の作業フローの問題点を記録
2. **仮説**: 改善案の立案と期待効果の定義
3. **実装**: 最小限の実装とテスト
4. **評価**: 定量的指標による効果測定
5. **標準化**: 成功事例の汎用化と文書化