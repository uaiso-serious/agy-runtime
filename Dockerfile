FROM ghcr.io/uaiso-serious/scm-runtime:latest

# agy-runtime: Antigravity CLI (agy) + plugin langfuse-observability sobre a base SCM.
# O ENTRYPOINT da base é mantido; só o CMD muda.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

USER root
COPY rootfs /
RUN chmod +x /usr/local/bin/*.sh \
 && chown -R agent:agent /home/agent

USER agent

RUN agy plugin install https://github.com/uaiso-serious/agy-langfuse-plugin

# SHA do commit do build (docker build --build-arg GIT_SHA=$(git rev-parse --short HEAD))
ARG GIT_SHA=unknown
ENV RUNNER_IMAGE_SHA=$GIT_SHA

WORKDIR /workspace

CMD ["agy.sh"]
