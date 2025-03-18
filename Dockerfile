# Stage 1: Install browsers and dependencies
FROM python:3.11.4-slim-bullseye AS install-browser

# Set non-interactive mode for APT
ENV DEBIAN_FRONTEND=noninteractive 

# Install system dependencies including nginx
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx apache2-utils gnupg wget ca-certificates curl unzip build-essential && \
    wget -qO - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        google-chrome-stable \
        chromium-driver \
        firefox-esr \
        && google-chrome --version && chromedriver --version && firefox --version && \
    wget -q https://github.com/mozilla/geckodriver/releases/download/v0.33.0/geckodriver-v0.33.0-linux64.tar.gz && \
    tar -xzf geckodriver-v0.33.0-linux64.tar.gz && \
    chmod +x geckodriver && \
    mv geckodriver /usr/local/bin/ && \
    rm -rf geckodriver-v0.33.0-linux64.tar.gz /var/lib/apt/lists/*

# Stage 2: Install Python dependencies
FROM install-browser AS gpt-researcher-install

# Set pip options
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

WORKDIR /usr/src/app

# Copy dependency files first to leverage Docker cache
COPY ./requirements.txt ./requirements.txt
COPY ./multi_agents/requirements.txt ./multi_agents/requirements.txt

RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r multi_agents/requirements.txt

# Stage 3: Final lightweight application image with Nginx
FROM gpt-researcher-install AS gpt-researcher

# Install Nginx & authentication utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx apache2-utils && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -ms /bin/bash gpt-researcher && \
    mkdir -p /usr/src/app/outputs && \
    chown -R gpt-researcher:gpt-researcher /usr/src/app && \
    chown -R gpt-researcher:gpt-researcher /usr/src/app/outputs && \
    chmod 777 /usr/src/app/outputs

USER gpt-researcher
WORKDIR /usr/src/app

# Copy application source code
COPY --chown=gpt-researcher:gpt-researcher ./ ./

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create authentication credentials from environment variables
USER root
RUN mkdir -p /etc/nginx/auth
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose FastAPI port internally & Nginx externally
EXPOSE 8000 80

# Run the authentication setup script and start Nginx and Uvicorn
ENTRYPOINT ["/entrypoint.sh"]

