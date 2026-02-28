ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

# OS packages.
RUN rm -f /etc/apt/sources.list.d/yarn.list || true
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        ca-certificates \
        wget \
        curl \
        sed \
        ripgrep \
        unzip \
        zip \
        git \
        # ADB runtime dependencies
        usbutils \
        # Node.js build tools (needed for ws-scrcpy native modules)
        build-essential \
        python3

# GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update -y \
    && apt install gh -y

# Java 21
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends openjdk-21-jdk
# Set JAVA_HOME dynamically based on architecture
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64" >> /etc/profile.d/java.sh; \
    else \
        echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" >> /etc/profile.d/java.sh; \
    fi && \
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java.sh
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Android SDK + adb + build tools
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "arm64" ]; then \
        SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"; \
       else \
        SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"; \
       fi \
    && wget -q -O /tmp/cmdline-tools.zip "$SDK_URL" \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/android-tools \
    && mv /tmp/android-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -rf /tmp/cmdline-tools.zip /tmp/android-tools

# Accept licenses and install platform-tools (adb) + build tools
RUN yes | sdkmanager --licenses > /dev/null 2>&1 \
    && sdkmanager \
        "platform-tools" \
        "build-tools;34.0.0" \
        "platforms;android-34"


# Gradle
ENV GRADLE_VERSION=8.7
ENV GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION}
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

RUN wget -q "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
        -O /tmp/gradle.zip \
    && mkdir -p /opt/gradle \
    && unzip -q /tmp/gradle.zip -d /opt/gradle \
    && rm /tmp/gradle.zip \
    && gradle --version

# Install NVM and Node.js 24 (must come before PM2)
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=24
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install ${NODE_VERSION} \
    && nvm use ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION}
ENV PATH="$NVM_DIR/versions/node/v${NODE_VERSION}.*/bin:${PATH}"

# PM2
RUN bash -c "source $NVM_DIR/nvm.sh && npm install -g pm2 && pm2 --version"

# install Gitleaks (supports x64 and arm64)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        GITLEAKS_URL="https://github.com/gitleaks/gitleaks/releases/download/v8.28.0/gitleaks_8.28.0_linux_x64.tar.gz"; \
    elif [ "$ARCH" = "arm64" ]; then \
        GITLEAKS_URL="https://github.com/gitleaks/gitleaks/releases/download/v8.28.0/gitleaks_8.28.0_linux_arm64.tar.gz"; \
    else \
        GITLEAKS_URL=""; \
    fi && \
    if [ -n "$GITLEAKS_URL" ]; then \
        echo "Installing gitleaks for architecture: $ARCH" && \
        wget -O /tmp/gitleaks.tar.gz "$GITLEAKS_URL" && \
        tar -xzf /tmp/gitleaks.tar.gz -C /tmp && \
        mv /tmp/gitleaks /usr/local/bin/gitleaks && \
        chmod +x /usr/local/bin/gitleaks && \
        rm /tmp/gitleaks.tar.gz; \
    else \
        echo "Skipping gitleaks install: unsupported architecture $ARCH"; \
    fi

# Install goose CLI
RUN export CONFIGURE=false && \
    export GOOSE_VERSION="v1.22.0" && \
    export PATH="/root/.local/bin:$PATH" && \
    curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash


# Clone ws-scrcpy repo and build (customizations are on master branch)
RUN export NVM_DIR=/root/.nvm \
    && . "$NVM_DIR/nvm.sh" \
    && nvm use 24 \
    && git clone https://github.com/fayekelmith/ws-scrcpy /opt/ws-scrcpy \
    && cd /opt/ws-scrcpy \
    && git checkout master \
    && npm install \
    && npm run dist

ENV PATH="/root/.cargo/bin:/root/.local/bin:${PATH}"
