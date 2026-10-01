# Extended Tooling Strategy - zsh関数とClaude Codeコマンドを含む統合管理

## 拡張されたリポジトリ構造

```bash
dotfiles/
├── core/                      # 基盤層
│   ├── plumbing/             # 配管コマンド（POSIX sh）
│   ├── middleware/           # OS差異吸収
│   └── lib/                  # 共通ライブラリ
│
├── zsh/                       # Zsh 専用機能
│   ├── functions/            # Zsh 関数群
│   │   ├── dev/             # 開発用関数
│   │   │   ├── gco         # git checkout の拡張
│   │   │   ├── pr          # Pull Request 作成
│   │   │   └── docker-clean # Docker クリーンアップ
│   │   ├── productivity/    # 生産性向上関数
│   │   │   ├── mkcd        # mkdir && cd
│   │   │   ├── extract     # 万能展開関数
│   │   │   └── backup      # インテリジェントバックアップ
│   │   └── system/         # システム管理関数
│   │       ├── ports       # ポート使用状況確認
│   │       ├── update-all  # 全パッケージ更新
│   │       └── clean-cache # キャッシュクリーンアップ
│   ├── completions/          # 補完定義
│   ├── widgets/              # Zle ウィジェット
│   └── .zshrc                # メイン設定ファイル
│
├── claude/                    # Claude Code 専用
│   ├── commands/             # カスタムコマンド
│   │   ├── review-pr.md     # PR レビュー
│   │   ├── explain-code.md  # コード説明
│   │   ├── refactor.md      # リファクタリング提案
│   │   └── debug-help.md    # デバッグ支援
│   ├── templates/            # コマンドテンプレート
│   │   ├── python-script.md
│   │   └── shell-script.md
│   └── CLAUDE.md             # Claude Code 用メタ設定
│
├── bash/                      # Bash 互換機能
│   ├── functions/            # POSIX準拠の関数
│   └── .bashrc               # Bash設定
│
└── install/                   # セットアップスクリプト
    ├── link-zsh.sh           # Zsh関数のリンク
    └── setup-claude.sh       # Claude設定
```

## 1. Zsh 関数の階層的管理

### 配管・陶器パターンの適用

```bash
# ~/.config/zsh/functions/dev/gco
# Git checkout の陶器層実装

gco() {
    # 配管層の利用
    local branches=$(plumb-git-branches)

    # インタラクティブ選択（fzf使用）
    if command -v fzf >/dev/null 2>&1; then
        local branch=$(echo "$branches" | fzf \
            --height 40% \
            --border \
            --preview 'git log --oneline -5 {}' \
            --preview-window right:50%)

        if [[ -n "$branch" ]]; then
            git checkout "$branch"
        fi
    else
        # フォールバック
        git checkout "$@"
    fi
}
```

### 関数の遅延ロード（パフォーマンス最適化）

```bash
# ~/.config/zsh/.zshrc

# 関数ディレクトリをFPATHに追加
fpath=(~/.config/zsh/functions/**/*(/N) $fpath)

# 自動ロード設定
autoload -Uz ~/.config/zsh/functions/**/*(:t)

# よく使う関数は即座にロード
for func in mkcd extract gco; do
    autoload -Uz $func
done

# 開発関数は必要時にロード
function load_dev_functions() {
    local dev_funcs=(~/.config/zsh/functions/dev/*(.:t))
    for func in $dev_funcs; do
        autoload -Uz $func
    done
}

# エイリアスで遅延ロードをトリガー
alias dev='load_dev_functions && unalias dev'
```

### カテゴリ別関数例

```bash
# ===== 生産性向上関数 =====
# ~/.config/zsh/functions/productivity/mkcd

mkcd() {
    # ディレクトリ作成して移動
    if [[ $# -eq 0 ]]; then
        echo "Usage: mkcd <directory>" >&2
        return 1
    fi

    mkdir -p "$1" && cd "$1"
}

# ===== システム管理関数 =====
# ~/.config/zsh/functions/system/ports

ports() {
    # 使用中のポート一覧表示
    local port="${1:-all}"

    if [[ "$port" == "all" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            lsof -iTCP -sTCP:LISTEN -P -n
        else
            sudo ss -tulpn
        fi
    else
        lsof -i ":$port" 2>/dev/null || echo "Port $port is not in use"
    fi
}

# ===== 開発支援関数 =====
# ~/.config/zsh/functions/dev/pr

pr() {
    # GitHub PR作成の拡張インターフェース
    local title="$1"
    local body="${2:-}"
    local draft="${3:-false}"

    # GitHub CLI を使用
    if [[ "$draft" == "true" ]]; then
        gh pr create --title "$title" --body "$body" --draft
    else
        gh pr create --title "$title" --body "$body"
    fi
}

# ~/.config/zsh/functions/dev/pr-review

pr-review() {
    # PR レビュー支援
    local pr_number="${1:-}"

    if [[ -z "$pr_number" ]]; then
        # インタラクティブにPR選択
        pr_number=$(gh pr list --limit 20 | fzf | cut -f1)
    fi

    if [[ -n "$pr_number" ]]; then
        # PR の詳細表示
        gh pr view "$pr_number"

        # 差分表示
        gh pr diff "$pr_number"
    fi
}
```

## 2. Claude Code カスタムコマンド管理

### コマンド構造

```markdown
<!-- ~/.claude/commands/review-pr.md -->
---
name: review-pr
description: Review a pull request with detailed analysis
parameters:
  - name: pr_number
    description: Pull request number
    required: true
  - name: focus
    description: Review focus (security|performance|style|all)
    required: false
    default: all
---

# Pull Request Review for PR #{{pr_number}}

Please perform a comprehensive review of PR #{{pr_number}} with focus on {{focus}}.

## Review Checklist

1. **Code Quality**
   - Is the code readable and maintainable?
   - Are there appropriate comments?
   - Does it follow project conventions?

2. **Security**
   - Check for potential vulnerabilities
   - Validate input handling
   - Review authentication/authorization

3. **Performance**
   - Identify potential bottlenecks
   - Check for unnecessary operations
   - Review database queries

4. **Testing**
   - Are tests comprehensive?
   - Edge cases covered?
   - Test coverage adequate?

## Specific Instructions

When reviewing, please:
- Use the `gh` CLI to fetch PR details
- Check the diff carefully
- Provide actionable feedback
- Suggest specific improvements

Focus area: **{{focus}}**
```

### 動的コマンド生成

```bash
#!/usr/bin/env bash
# ~/.config/tools/generate-claude-command.sh

generate_claude_command() {
    local name="$1"
    local description="$2"
    local template="${3:-generic}"

    cat > ~/.claude/commands/${name}.md <<EOF
---
name: ${name}
description: ${description}
created: $(date -Iseconds)
generator: auto-generated
---

# ${description}

This command was auto-generated based on the ${template} template.

## Task

${description}

## Instructions

1. Analyze the current context
2. Provide comprehensive solutions
3. Include code examples where appropriate
4. Explain the reasoning behind recommendations

## Additional Context

- Working directory: \$(pwd)
- Current branch: \$(git branch --show-current 2>/dev/null || echo "N/A")
- OS: ${TOOLS_OS}
EOF

    echo "Created Claude command: ${name}"
}
```

### テンプレートベースのコマンド

```markdown
<!-- ~/.claude/templates/debug-template.md -->
---
template: debug
variables:
  - error_message
  - file_path
  - line_number
---

# Debug Assistance Required

## Error Information
- **Error**: {{error_message}}
- **Location**: {{file_path}}:{{line_number}}

## Tasks
1. Analyze the error message
2. Examine the code at the specified location
3. Identify the root cause
4. Provide a fix with explanation

## Context Gathering
Please use the following tools:
- Read the file at {{file_path}}
- Check recent git changes: `git diff HEAD~1 {{file_path}}`
- Look for similar patterns in the codebase
```

## 3. 統合管理スクリプト

### 関数とコマンドの同期

```bash
#!/usr/bin/env bash
# ~/.config/tools/sync-extensions.sh

sync_extensions() {
    local dotfiles_dir="$HOME/repos/dotfiles"

    # Zsh 関数の同期
    echo "Syncing Zsh functions..."
    rsync -av --delete \
        "$dotfiles_dir/zsh/functions/" \
        "$HOME/.config/zsh/functions/"

    # Claude コマンドの同期
    echo "Syncing Claude commands..."
    mkdir -p "$HOME/.claude/commands"
    rsync -av --delete \
        "$dotfiles_dir/claude/commands/" \
        "$HOME/.claude/commands/"

    # Zsh 再コンパイル
    echo "Recompiling Zsh functions..."
    zcompile "$HOME/.config/zsh/.zshrc"
    for func in "$HOME/.config/zsh/functions"/**/*(.); do
        zcompile "$func"
    done

    echo "✅ Extensions synced successfully"
}
```

### インストーラー

```bash
#!/usr/bin/env bash
# install/setup-extended.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Zsh 関数のセットアップ
setup_zsh_functions() {
    local zsh_config_dir="$HOME/.config/zsh"

    mkdir -p "$zsh_config_dir/functions"

    # シンボリックリンク作成
    ln -sfn "$DOTFILES_DIR/zsh/functions" "$zsh_config_dir/functions"

    # .zshrc のバックアップと更新
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d)"
    fi

    ln -sfn "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
}

# Claude コマンドのセットアップ
setup_claude_commands() {
    local claude_dir="$HOME/.claude"

    mkdir -p "$claude_dir"

    # コマンドディレクトリのリンク
    ln -sfn "$DOTFILES_DIR/claude/commands" "$claude_dir/commands"

    # CLAUDE.md のコピー
    cp "$DOTFILES_DIR/claude/CLAUDE.md" "$claude_dir/CLAUDE.md"
}

# メイン処理
main() {
    echo "🚀 Setting up extended tooling..."

    setup_zsh_functions
    setup_claude_commands

    echo "✅ Setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your shell or run: source ~/.zshrc"
    echo "2. Test a zsh function: mkcd test-dir"
    echo "3. Check Claude commands: ls ~/.claude/commands/"
}

main "$@"
```

## 4. バージョン管理のベストプラクティス

### .gitignore 設定

```gitignore
# Zsh compiled files
*.zwc
*.zwc.old

# Claude Code
.claude/cache/
.claude/logs/

# 個人用カスタマイズ
zsh/functions/personal/
claude/commands/private/

# 生成されたファイル
*.generated.md
```

### コミットメッセージ規約

```bash
# タイプ別プレフィックス
feat(zsh): Add new git helper function
fix(claude): Correct review-pr command parameters
docs(zsh): Update function documentation
refactor(claude): Simplify debug command template
perf(zsh): Optimize function loading
```

## 5. 検証とテスト

### Zsh 関数のテスト

```bash
#!/usr/bin/env zsh
# tests/test-zsh-functions.sh

source "$HOME/.config/zsh/functions/productivity/mkcd"

# テスト実行
test_mkcd() {
    local test_dir="/tmp/test_mkcd_$$"

    # 実行
    mkcd "$test_dir"

    # 検証
    if [[ "$PWD" == "$test_dir" ]] && [[ -d "$test_dir" ]]; then
        echo "✅ mkcd: PASS"
        cd - > /dev/null
        rm -rf "$test_dir"
        return 0
    else
        echo "❌ mkcd: FAIL"
        return 1
    fi
}

test_mkcd
```

## まとめ

この拡張により：
- **Zsh関数の体系的管理**: カテゴリ別整理と遅延ロード
- **Claude Codeとの統合**: カスタムコマンドのGit管理
- **配管・陶器パターンの一貫性**: 全ツールで統一された設計
- **クロスプラットフォーム対応**: macOS/WSL2での完全互換性