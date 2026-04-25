ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    nano \
    git \
    vim \
    wget \
    jq \
    tree \
    tmux \
    python3 \
    python3-pip \
    python3-requests \
    python3-aiohttp \
    python3-yaml \
    python3-bs4 \
    nodejs \
    npm \
    openssh-client \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub Copilot CLI (standalone binary from GitHub releases)
ARG BUILD_ARCH
RUN case "${BUILD_ARCH}" in \
        amd64)   COPILOT_ARCH="x64"   ;; \
        aarch64) COPILOT_ARCH="arm64"  ;; \
        *)       COPILOT_ARCH="x64"    ;; \
    esac && \
    curl -fsSL \
      "https://github.com/github/copilot-cli/releases/latest/download/copilot-linux-${COPILOT_ARCH}.tar.gz" \
      -o /tmp/copilot.tar.gz && \
    tar -xzf /tmp/copilot.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/copilot && \
    rm -f /tmp/copilot.tar.gz && \
    copilot --version

# Install ttyd (web terminal server)
RUN case "${BUILD_ARCH}" in \
        amd64)   TTYD_ARCH="x86_64"   ;; \
        aarch64) TTYD_ARCH="aarch64"   ;; \
        *)       TTYD_ARCH="x86_64"    ;; \
    esac && \
    curl -fsSL \
      "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}" \
      -o /usr/bin/ttyd && \
    chmod +x /usr/bin/ttyd

# Install yq (YAML processor)
RUN case "${BUILD_ARCH}" in \
        amd64)   YQ_ARCH="amd64"   ;; \
        aarch64) YQ_ARCH="arm64"   ;; \
        *)       YQ_ARCH="amd64"   ;; \
    esac && \
    curl -fsSL \
      "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}" \
      -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Install uv for running ha-mcp (Python package manager/runner)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -sf /root/.local/bin/uv /usr/local/bin/uv && \
    ln -sf /root/.local/bin/uvx /usr/local/bin/uvx

# Create directory for Copilot configuration and set working directory
RUN mkdir -p /config
WORKDIR /config

# Copy image upload service
COPY image-service/ /opt/image-service/

# Copy startup script, modular scripts, and changelog
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
COPY CHANGELOG.md /opt/scripts/CHANGELOG.md
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
