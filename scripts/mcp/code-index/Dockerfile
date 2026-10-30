# Индексатор кода проекта: bsl-indexer (github.com/Regsorm/code-index-mcp) — демон индексации + HTTP MCP (serve).
# Бинарник берется из GitHub Releases (без сборки cargo). Индексы — на хосте (<PROJECT_ROOT>\indexes\code-index),
# монтируются томами; образ собирает start-code-index.ps1: docker build -t <CODE_INDEX_IMAGE> .

FROM debian:bookworm-slim

ARG BSL_INDEXER_VERSION=1.8.5
ARG BSL_INDEXER_URL=https://github.com/Regsorm/code-index-mcp/releases/download/v${BSL_INDEXER_VERSION}/bsl-indexer-linux-x64.tar.gz

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tar \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "$BSL_INDEXER_URL" -o /tmp/bsl-indexer.tar.gz \
 && mkdir -p /tmp/bsl-extract \
 && tar -xzf /tmp/bsl-indexer.tar.gz -C /tmp/bsl-extract \
 && BIN="$(find /tmp/bsl-extract -type f -name 'bsl-indexer' | head -n1)" \
 && test -n "$BIN" \
 && mv "$BIN" /usr/local/bin/bsl-indexer \
 && chmod +x /usr/local/bin/bsl-indexer \
 && rm -rf /tmp/bsl-indexer.tar.gz /tmp/bsl-extract \
 && bsl-indexer --version

COPY entrypoint.sh /usr/local/bin/bsl-indexer-entrypoint.sh
RUN chmod +x /usr/local/bin/bsl-indexer-entrypoint.sh

ENV CODE_INDEX_HOME=/data/code-index-home
ENV MCP_HTTP_HOST=0.0.0.0
ENV MCP_HTTP_PORT=8030

WORKDIR /data
EXPOSE 8030

ENTRYPOINT ["bash", "/usr/local/bin/bsl-indexer-entrypoint.sh"]
