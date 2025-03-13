# syntax=docker/dockerfile:latest

# A termix-nu image with Nushell and Node installed based on alpine
# docker build --no-cache . -t hustcer/termix:latest -f Dockerfile
# TODO:
#   [√] run run/setup-termix.sh to install binary dependencies
#   [√] Add `t` global alias
#   [√] Add ~/.env and ~/.termixrc file
#   [√] Install @terminus/t-package-tools@latest
#   [√] Change entry to nu

FROM node:lts-alpine

LABEL maintainer="hustcer" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.title="Termix-Nu" \
    org.opencontainers.image.vendor="hustcer" \
    org.opencontainers.image.authors="hustcer" \
    org.opencontainers.image.description="A termix-nu image with Nushell and Node installed" \
    org.opencontainers.image.documentation="https://fe-docs.app.terminus.io/termix/termix-nu"

# Add termix-nu to the image
COPY . /home/termix/termix-nu

ENV DISABLE_VERSION_CHECK=true

RUN apk update && apk add --no-cache git \
    #  Setup termix user
    && echo '/usr/bin/nu' >> /etc/shells \
    && adduser -D -s /usr/bin/nu termix \
    && sh /home/termix/termix-nu/run/setup-termix.sh /usr/bin/ \
    && mkdir -p /home/termix/.config/nushell/ \
    # Setup default config file for nushell
    && cd /home/termix/.config/nushell \
    && chmod +x /usr/bin/nu \
    && chown -R termix:termix /home/termix/termix-nu \
    && chown -R termix:termix /home/termix/.config/nushell \
    && cp /home/termix/termix-nu/.termixrc-example /home/termix/.termixrc \
    && cp /home/termix/termix-nu/.env-example /home/termix/.env \
    && ln -s /home/termix/termix-nu/Justfile /home/termix/.justfile \
    && ln -s /home/termix/.env /home/termix/termix-nu/.env \
    && ln -s /home/termix/.termixrc /home/termix/termix-nu/.termixrc \
    && nu -c 'open /home/termix/.env | str replace /Users/terminus/termix-nu /home/termix/termix-nu | save -rf /home/termix/.env' \
    # Reset Nushell config to default
    && su -c 'config reset -w' termix \
    && ls /usr/bin/nu_plugin_[fgipq]* \
    | xargs -I{} su -c 'plugin add {}' termix \
    && npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io \
    && npm cache clean --force \
    && rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists/* \
    && git config --global --add safe.directory /home/termix/termix-nu \
    && nu -c 'do { \
        echo `alias t="just --justfile ~/.justfile --dotenv-path ~/.env --working-directory ."` o>> /home/termix/.profile; \
        echo "alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .\n" o>> /home/termix/.config/nushell/config.nu; \
        echo "$env.config.show_banner = false\n" o>> /home/termix/.config/nushell/config.nu; \
        echo `$env.config.table.mode = "light"` o>> /home/termix/.config/nushell/config.nu; \
      }'

USER termix

WORKDIR /home/termix

CMD ["nu"]
