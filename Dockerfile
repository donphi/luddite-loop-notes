FROM python:3.12-slim

# Set locale for proper UTF-8 and emoji support
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Install Node.js 20.x LTS and npm with locale support
RUN apt-get update && apt-get install -y \
    curl \
    locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency files first for better caching
COPY package.json requirements.txt ./

# Install dependencies (this layer will be cached if deps don't change)
RUN npm install && \
    pip install --no-cache-dir -r requirements.txt

# Create output directory with open permissions (user mapping will apply at runtime)
RUN mkdir -p /app/output && chmod 777 /app/output

# Note: In docker-compose.yml, we mount the source files as volumes
# so they can be changed without rebuilding the image
# This allows for live development while keeping the container lightweight

# Default command - can be overridden in docker-compose
CMD ["python", "export_notion.py"]
