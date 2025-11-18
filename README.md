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

### 基盤文書
- [`CLAUDE.md`](CLAUDE.md) - Claude Code用の設定と指示
- [`FOUNDATION.md`](FOUNDATION.md) - 変更困難な基盤的決定事項

### 戦略文書
- [`GIT-REPOSITORY-BEST-PRACTICES.md`](GIT-REPOSITORY-BEST-PRACTICES.md) - Gitリポジトリ管理のベストプラクティス
- [`SECURITY-STRATEGY.md`](SECURITY-STRATEGY.md) - 機密情報管理とセキュリティ戦略
- [`CROSS-DEVICE-STRATEGY.md`](CROSS-DEVICE-STRATEGY.md) - クロスデバイス環境統合戦略
- [`WORKSTATION-INTEGRATION.md`](WORKSTATION-INTEGRATION.md) - GPUワークステーション統合
- [`GITHUB-CLI-INTEGRATION.md`](GITHUB-CLI-INTEGRATION.md) - GitHub CLI活用戦略

### 実装詳細
- [`EXTENDED-TOOLING.md`](EXTENDED-TOOLING.md) - zsh関数とClaude Codeコマンド管理

### 実装例
- [`examples/unified-setup.sh`](examples/unified-setup.sh) - 統合セットアップスクリプト

## リポジトリの使い方

### 1. 文書として参照
```bash
# 設計思想を理解する
cat FOUNDATION.md

# 実装方法を確認する
cat GIT-REPOSITORY-BEST-PRACTICES.md
```

### 2. 実装の出発点として
```bash
# 実際のdotfilesリポジトリを作成
mkdir -p ~/repos/dotfiles
cp GIT-REPOSITORY-BEST-PRACTICES.md ~/repos/dotfiles/IMPLEMENTATION.md

# セットアップスクリプトを利用
cp examples/unified-setup.sh ~/repos/dotfiles/setup.sh
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