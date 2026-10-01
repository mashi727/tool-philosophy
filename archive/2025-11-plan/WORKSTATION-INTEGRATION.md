# Workstation Integration Strategy - GPU処理とリモートコンパイル環境

## ハードウェア役割分担

```
┌──────────────────┐
│  MacBook Pro     │ ← メイン開発環境（常時携帯）
│  - 開発/編集     │
│  - 軽量処理      │
└────────┬─────────┘
         │
┌────────▼─────────┐
│  iPad Pro 13"    │ ← 軽装時のアクセス端末
│  - 緊急対応      │
│  - レビュー      │
└────────┬─────────┘
         │
┌────────▼─────────────────┐
│  Windows Workstation     │ ← 計算リソース提供
│  - NVIDIA GPU (CUDA)     │
│  - Docker (LuaLaTeX)     │
│  - Whisper/ML処理        │
└──────────────────────────┘
```

## 1. Windows ワークステーションの役割定義

### GPU計算サーバーとしての構成

```yaml
# Windows Workstation 構成
Hardware:
  GPU: NVIDIA RTX/Quadro
  RAM: 32GB+
  Storage: NVMe SSD

Software Stack:
  - WSL2 Ubuntu 22.04/24.04
  - NVIDIA CUDA Toolkit
  - Docker Desktop with GPU support
  - SSH Server (WSL2)
  - Tailscale

Services:
  - Whisper API Server
  - LuaLaTeX Compilation Service
  - ML Training Environment
  - Video/Audio Processing
```

### WSL2 GPU パススルー設定

```bash
# WSL2 での CUDA 確認
nvidia-smi  # GPU情報表示

# Docker での GPU 利用
docker run --gpus all nvidia/cuda:12.0-base nvidia-smi

# Whisper サーバー起動
docker run -d \
  --name whisper-server \
  --gpus all \
  -p 8080:8080 \
  -v ~/whisper-models:/models \
  whisper-api:latest
```

## 2. リモート処理用Zsh関数

### GPU処理関数

```bash
# ~/.config/zsh/functions/remote/whisper-transcribe

whisper-transcribe() {
    local audio_file="$1"
    local model="${2:-base}"
    local workstation="${WORKSTATION_HOST:-workstation.tail-scale.ts.net}"

    if [[ ! -f "$audio_file" ]]; then
        echo "Error: Audio file not found" >&2
        return 1
    fi

    # ファイルをワークステーションに転送
    echo "📤 Uploading audio file..."
    scp "$audio_file" "${workstation}:/tmp/whisper-input/"

    # リモートでWhisper実行
    echo "🎙️ Transcribing with Whisper (model: $model)..."
    ssh "$workstation" "cd /tmp/whisper-input && \
        docker run --gpus all \
        -v /tmp/whisper-input:/data \
        whisper:latest \
        --model $model \
        --file /data/$(basename $audio_file)"

    # 結果を取得
    echo "📥 Downloading transcription..."
    scp "${workstation}:/tmp/whisper-input/$(basename $audio_file .*)*.txt" .

    echo "✅ Transcription complete!"
}

# ~/.config/zsh/functions/remote/gpu-status

gpu-status() {
    local workstation="${WORKSTATION_HOST:-workstation.tail-scale.ts.net}"

    echo "🖥️ GPU Status on $workstation"
    ssh "$workstation" "nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits" | \
    awk -F', ' '{
        printf "GPU: %s\n", $1
        printf "Memory: %s/%s MB (%.1f%%)\n", $2, $3, ($2/$3)*100
        printf "Utilization: %s%%\n", $4
    }'
}
```

### LaTeXリモートコンパイル

```bash
# ~/.config/zsh/functions/remote/luatex-remote

luatex-remote() {
    local tex_file="$1"
    local workstation="${WORKSTATION_HOST:-workstation.tail-scale.ts.net}"
    local project_dir="$(basename $(pwd))"

    if [[ ! -f "$tex_file" ]]; then
        echo "Error: TeX file not found" >&2
        return 1
    fi

    echo "🚀 Remote LuaLaTeX compilation starting..."

    # プロジェクト全体を同期
    echo "📤 Syncing project files..."
    rsync -avz --exclude='.git' --exclude='*.pdf' \
        ./ "${workstation}:/tmp/latex-compile/${project_dir}/"

    # Dockerでコンパイル
    echo "📝 Compiling with LuaLaTeX..."
    ssh "$workstation" "cd /tmp/latex-compile/${project_dir} && \
        docker run --rm \
        -v /tmp/latex-compile/${project_dir}:/workspace \
        -w /workspace \
        texlive/luatex:latest \
        lualatex -interaction=nonstopmode -file-line-error $tex_file"

    # PDFを取得
    echo "📥 Downloading PDF..."
    scp "${workstation}:/tmp/latex-compile/${project_dir}/*.pdf" .

    echo "✅ Compilation complete!"

    # macOSの場合、PDFを開く
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "${tex_file%.tex}.pdf"
    fi
}

# ~/.config/zsh/functions/remote/latex-watch

latex-watch() {
    local tex_file="${1:-main.tex}"

    echo "👁️ Watching for changes in TeX files..."

    # fswatch (macOS) または inotifywait (Linux) を使用
    if command -v fswatch >/dev/null 2>&1; then
        fswatch -o *.tex | while read f; do
            luatex-remote "$tex_file"
        done
    else
        while inotifywait -e modify *.tex; do
            luatex-remote "$tex_file"
        done
    fi
}
```

## 3. Docker環境の構築

### LuaLaTeX Dockerイメージ

```dockerfile
# docker/luatex/Dockerfile
FROM ubuntu:22.04

# 日本語環境設定
ENV LANG=ja_JP.UTF-8
ENV LC_ALL=ja_JP.UTF-8

# TeX Live インストール
RUN apt-get update && apt-get install -y \
    texlive-full \
    texlive-lang-japanese \
    texlive-lang-cjk \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    fonts-liberation \
    fonts-liberationserif \
    locales \
    && locale-gen ja_JP.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# 原ノ味フォントのインストール
RUN apt-get update && apt-get install -y \
    wget \
    fontconfig \
    && wget https://github.com/trueroad/HaranoAjiFonts/archive/refs/heads/master.zip \
    && unzip master.zip \
    && cp HaranoAjiFonts-master/*.ttf /usr/local/share/fonts/ \
    && fc-cache -fv \
    && rm -rf master.zip HaranoAjiFonts-master

WORKDIR /workspace

CMD ["/bin/bash"]
```

### Whisper Docker環境

```dockerfile
# docker/whisper/Dockerfile
FROM nvidia/cuda:12.0-base-ubuntu22.04

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install \
    openai-whisper \
    flask \
    gunicorn

# API サーバースクリプト
COPY whisper_api.py /app/whisper_api.py

WORKDIR /app

CMD ["gunicorn", "-b", "0.0.0.0:8080", "whisper_api:app"]
```

### Docker Compose 構成

```yaml
# docker-compose.yml
version: '3.8'

services:
  luatex:
    build: ./docker/luatex
    volumes:
      - ./workspace:/workspace
    command: tail -f /dev/null  # 常時起動

  whisper:
    build: ./docker/whisper
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    ports:
      - "8080:8080"
    volumes:
      - ./models:/models
      - ./audio:/audio

  jupyter-gpu:
    image: tensorflow/tensorflow:latest-gpu-jupyter
    runtime: nvidia
    ports:
      - "8888:8888"
    volumes:
      - ./notebooks:/tf/notebooks
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
```

## 4. iPad からの軽量アクセス

### Blink Shell ショートカット

```javascript
// .blink/shortcuts.js

// GPU状態確認
cmd('gpu', 'ssh workstation nvidia-smi');

// LaTeX コンパイル
cmd('tex', (args) => {
    return `ssh mac "cd ~/Documents/papers && luatex-remote ${args[0] || 'main.tex'}"`;
});

// Whisper 実行
cmd('whisper', (args) => {
    return `ssh workstation "whisper-api ${args.join(' ')}"`;
});
```

### Working Copy + Textastic ワークフロー

```markdown
# iPad での LaTeX 編集ワークフロー

1. Working Copy で Git リポジトリをクローン
2. Textastic で .tex ファイルを編集
3. Blink Shell から `tex main.tex` でコンパイル
4. Files アプリで PDF を確認
5. Working Copy でコミット・プッシュ
```

## 5. 統合管理スクリプト

### ワークステーション初期設定

```bash
#!/usr/bin/env bash
# setup-workstation.sh

setup_workstation() {
    local workstation="${1:-workstation.tail-scale.ts.net}"

    echo "🔧 Setting up workstation..."

    # Docker 環境構築
    scp -r ./docker "${workstation}:/home/$(whoami)/"
    ssh "$workstation" "cd ~/docker && docker-compose up -d"

    # 作業ディレクトリ作成
    ssh "$workstation" "mkdir -p /tmp/{whisper-input,latex-compile}"

    # GPU確認
    ssh "$workstation" "docker run --gpus all nvidia/cuda:12.0-base nvidia-smi"

    echo "✅ Workstation setup complete!"
}
```

### 状態監視ダッシュボード

```bash
#!/usr/bin/env bash
# monitor-resources.sh

monitor_resources() {
    while true; do
        clear
        echo "📊 Resource Monitor - $(date)"
        echo "================================"

        # MacBook状態
        echo -e "\n💻 MacBook Pro:"
        uptime | awk '{print "  Load: " $10 $11 $12}'

        # Workstation GPU状態
        echo -e "\n🖥️ Workstation GPU:"
        ssh workstation "nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader" | \
            awk -F', ' '{print "  GPU: " $1 ", Memory: " $2}'

        # Docker コンテナ状態
        echo -e "\n🐳 Docker Services:"
        ssh workstation "docker ps --format 'table {{.Names}}\t{{.Status}}'" | tail -n +2

        sleep 5
    done
}
```

## 6. パフォーマンス最適化

### SSH 多重接続

```ssh
# ~/.ssh/config
Host workstation
    HostName workstation.tail-scale.ts.net
    User yourusername
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 600
    Compression yes
    ServerAliveInterval 60
```

### rsync 最適化

```bash
# 差分転送のみ
alias rsync-fast='rsync -avz --compress-level=9 --partial --progress'

# 大容量ファイル用
alias rsync-large='rsync -avP --inplace --no-compress'
```

## まとめ

この構成により：

1. **MacBook Pro**: メインの開発環境として日常使用
2. **iPad Pro**: 軽装時の緊急対応・レビュー端末
3. **Windows Workstation**: GPU処理とDocker環境のリモートリソース

という明確な役割分担で、効率的なワークフローを実現できます。特に：

- Whisper等のGPU処理はSSH経由で透過的に実行
- LaTeXコンパイルはDocker環境でクリーンに実行
- すべての操作はZsh関数として統一的に管理

これにより、デバイスの特性を最大限活用した生産的な環境が構築できます。