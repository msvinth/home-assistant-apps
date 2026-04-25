ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install system packages and development tools
RUN apk add --no-cache \
    bash \
    curl \
    nano \
    nodejs \
    npm \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    py3-beautifulsoup4 \
    git \
    vim \
    wget \
    jq \
    tree \
    tmux \
    ttyd \
    yq

# Install GitHub Copilot CLI via npm
RUN npm install -g @github/copilot \
    && npm cache clean --force

# Install uv for running ha-mcp (Python package manager/runner)
RUN apk add --no-cache uv

# Create directory for Copilot configuration and set working directory
RUN mkdir -p /config
WORKDIR /config

# Copy image upload service (uses aiohttp which is already installed via py3-aiohttp)
COPY image-service/ /opt/image-service/

# Copy startup script, modular scripts, and changelog
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
COPY CHANGELOG.md /opt/scripts/CHANGELOG.md
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
