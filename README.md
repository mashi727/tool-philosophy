# The Philosophy of Computer Using

コンピューター使用における生産性向上のための哲学と標準化戦略を記録するリポジトリ

## 概要

このリポジトリは、自作ツールを含む様々なツールの標準化に関する：
- 考え方（Philosophy）
- 理由と背景（Rationale and Background）
- 時系列的な記録（Chronological Documentation）
- 実装戦略（Implementation Strategy）

を体系的に記録し、継続的な生産性向上を実現することを目的としています。

## 基本思想

- **UNIX哲学**: 一つのことを上手くやる、テキストストリームを基本とする
- **Gitの配管と陶器**: 低レベルの堅牢な基盤と高レベルの使いやすいインターフェースの分離
- **クロスプラットフォーム**: macOS、WSL2 Ubuntu、iPadからの統一的なアクセス

## ドキュメント構成

### コア文書（必読）
1. [`FOUNDATION.md`](FOUNDATION.md) - 基盤となる決定事項と原則
2. [`MIGRATION-GUIDE.md`](MIGRATION-GUIDE.md) - 既存環境からの具体的な移行手順
3. [`GIT-REPOSITORY-BEST-PRACTICES.md`](GIT-REPOSITORY-BEST-PRACTICES.md) - リポジトリ構成と管理

### 専門戦略
- [`STORAGE-STRATEGY.md`](STORAGE-STRATEGY.md) - Dropbox/Git使い分け戦略
- [`SECURITY-STRATEGY.md`](SECURITY-STRATEGY.md) - 機密情報の暗号化管理
- [`WORKSTATION-INTEGRATION.md`](WORKSTATION-INTEGRATION.md) - GPU/Docker活用
- [`CROSS-DEVICE-STRATEGY.md`](CROSS-DEVICE-STRATEGY.md) - iPad/WSL2統合

### 実装詳細
- [`EXTENDED-TOOLING.md`](EXTENDED-TOOLING.md) - Zsh関数とClaude Codeコマンド
- [`GITHUB-CLI-INTEGRATION.md`](GITHUB-CLI-INTEGRATION.md) - GitHub CLI活用法

### 設定ファイル
- [`CLAUDE.md`](CLAUDE.md) - Claude Code用設定
- [`examples/`](examples/) - 実装スクリプト例

## クイックスタート

### 既存環境から今すぐ移行を始める

```bash
# 自動移行スクリプトを実行
./scripts/quick-start.sh

# または、GitHubから直接実行
curl -fsSL https://raw.githubusercontent.com/mashi727/tool-philosophy/main/scripts/quick-start.sh | bash
```

このスクリプトが実行すること：
1. 現在の設定をバックアップ
2. dotfilesリポジトリを作成（GitHub）
3. 既存ツールを新構造に移行
4. インストールスクリプトを生成
5. 初期コミット＆プッシュ

### 手動での段階的移行

```bash
# Step 1: リポジトリ作成
mkdir -p ~/repos && cd ~/repos
gh repo create dotfiles --private --clone

# Step 2: 構造作成
cd dotfiles && mkdir -p shell/zsh/functions tools scripts

# Step 3: 重要なツールから移行
cp -r ~/works/git/tools/luatex-docker-remote tools/
cp ~/.config/zsh/functions/*.zsh shell/zsh/functions/

# Step 4: コミット
git add -A && git commit -m "Initial migration" && git push
```

### 3. 時系列記録の追加
```bash
# journal/ディレクトリに日々の決定を記録
mkdir -p journal
echo "# $(date +%Y-%m-%d) Tool Decision" > journal/$(date +%Y-%m-%d)_decision.md
```

## 関連リポジトリ

実際の実装は以下のリポジトリで管理：

- `dotfiles` - 公開可能な設定ファイル群
- `dotfiles-secure` - 暗号化された機密情報
- `infrastructure` - Docker/サーバー設定

## 実装チェックリスト

- [ ] このリポジトリをGitで初期化
- [ ] 基盤文書の確定
- [ ] dotfilesリポジトリの作成
- [ ] 初期ツールの移行
- [ ] CI/CDの設定
- [ ] チーム共有の検討

## 改訂履歴

- 2024-11-18: 初期構成の確立
- 2024-11-18: 各種戦略文書の作成

## ライセンス

個人使用を前提としているため、適切なライセンスを選択してください。

## 連絡先

[あなたのGitHubプロフィールまたはメールアドレス]