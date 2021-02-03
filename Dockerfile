FROM alpine:3.13.1 as base_stage

LABEL maintainer="beardedeagle <randy@heroictek.com>"

# Important! Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images.
ENV REFRESHED_AT=2021-02-02 \
  ELIXIR_VER=1.11.3 \
  HEX_VER=0.21.1 \
  REBAR3_VER=3.14.3 \
  MIX_HOME=/usr/local/lib/elixir/.mix \
  TERM=xterm \
  LANG=C.UTF-8

RUN set -xe \
  && apk --no-cache update \
  && apk --no-cache upgrade \
  && apk add --no-cache \
    bash \
    git \
    openssl \
    zlib \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/* \
  && rm -rf /tmp/*

FROM beardedeagle/alpine-erlang-builder:23.2.3 as deps_stage

ENV ELIXIR_VER=1.11.3 \
  HEX_VER=0.21.1 \
  REBAR3_VER=3.14.3 \
  MIX_HOME=/usr/local/lib/elixir/.mix \
  TERM=xterm \
  LANG=C.UTF-8

RUN set -xe \
  && mkdir -p "${MIX_HOME}" \
  && mv /usr/local/bin/rebar3 "${MIX_HOME}" \
  && apk add --no-cache --virtual .build-deps \
    autoconf \
    curl \
    dpkg \
    dpkg-dev \
    g++ \
    gcc \
    make \
    musl-dev \
    rsync \
    tar

FROM deps_stage as elixir_stage

RUN set -xe \
  && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VER}.tar.gz" \
  && ELIXIR_DOWNLOAD_SHA256="d961305e893f4fe1a177fa00233762c34598bc62ff88b32dcee8af27e36f0564" \
  && curl -fSL -o elixir-src.tar.gz "${ELIXIR_DOWNLOAD_URL}" \
  && echo "${ELIXIR_DOWNLOAD_SHA256}  elixir-src.tar.gz" | sha256sum -c - \
  && export ELIXIR_TOP="/usr/src/elixir_src_${ELIXIR_VER%%@*}" \
  && mkdir -vp "${ELIXIR_TOP}" \
  && tar -xzf elixir-src.tar.gz -C "${ELIXIR_TOP}" --strip-components=1 \
  && rm elixir-src.tar.gz \
  && ( cd "${ELIXIR_TOP}" \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install clean ) \
  && rm -rf "${ELIXIR_TOP}" \
  && find /usr/local -regex '/usr/local/lib/elixir/\(lib/\|erts-\).*/\(man\|doc\|obj\|c_src\|emacs\|info\|examples\)' | xargs rm -rf \
  && find /usr/local -name src | xargs -r find | grep -v '\.hrl$' | xargs rm -v || true \
  && find /usr/local -name src | xargs -r find | xargs rmdir -vp || true \
  && scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/local | xargs -r strip --strip-all \
  && scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/local | xargs -r strip --strip-unneeded

FROM elixir_stage as hex_stage

RUN set -xe \
  && HEX_DOWNLOAD_URL="https://github.com/hexpm/hex/archive/v${HEX_VER}.tar.gz" \
  && HEX_DOWNLOAD_SHA256="e44790ee027955baf4ff30d19634831361e6762ea9042acac8d8b18c09ea8705" \
  && curl -fSL -o hex-src.tar.gz "${HEX_DOWNLOAD_URL}" \
  && echo "${HEX_DOWNLOAD_SHA256}  hex-src.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/hex-src \
  && tar -xzf hex-src.tar.gz -C /usr/src/hex-src --strip-components=1 \
  && rm hex-src.tar.gz \
  && cd /usr/src/hex-src \
  && MIX_ENV=prod mix install

FROM deps_stage as stage

COPY --from=elixir_stage /usr/local /opt/elixir
COPY --from=hex_stage /usr/local /opt/hex

RUN set -xe \
  && rsync -a /opt/elixir/ /usr/local \
  && rsync -a /opt/hex/ /usr/local \
  && apk del .build-deps \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/* \
  && rm -rf /tmp/*

FROM base_stage

COPY --from=stage /usr/local /usr/local
