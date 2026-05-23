FROM node:22-slim

# Install system dependencies Pi may need
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    build-essential \
    python3 \
    procps \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user matching expected UID/GID
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} dev && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash dev

# Switch to dev user before installing Pi globally
USER dev
ENV HOME=/home/dev
ENV PATH="/home/dev/.npm-global/bin:${PATH}"

# Configure npm global prefix so --global installs go to user dir
RUN mkdir -p /home/dev/.npm-global && \
    npm config set prefix /home/dev/.npm-global

# Install Pi Coding Agent
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Create workspace mount point (owned by dev)
USER root
RUN mkdir -p /workspace && chown dev:dev /workspace
USER dev

WORKDIR /workspace

# Pi config (.pi/) and npm cache are bind-mounted from ./data/ on the host.
# models.json and SYSTEM.md live in data/pi/ — edit them there.

ENTRYPOINT ["pi"]
CMD ["--help"]