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

WORKDIR /workspace

CMD ["agy.sh"]
