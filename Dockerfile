FROM alpine:3.9 as base_stage

LABEL maintainer="beardedeagle <randy@heroictek.com>"

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images.
ENV REFRESHED_AT=2019-01-30 \
  ELIXIR_VER=1.8.1 \
  HEX_VER=0.19.0 \
  REBAR2_VER=2.6.4 \
  REBAR3_VER=3.8.0 \
  MIX_HOME=/usr/local/lib/elixir/.mix \
  TERM=xterm \
  LANG=C.UTF-8

RUN set -xe \
  && apk --update --no-cache upgrade \
  && apk add --no-cache \
    bash \
    openssl \
    lksctp-tools \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/*

FROM beardedeagle/alpine-erlang-builder:21.2.4 as deps_stage

ENV ELIXIR_VER=1.8.1 \
  HEX_VER=0.19.0 \
  REBAR2_VER=2.6.4 \
  REBAR3_VER=3.8.0 \
  MIX_HOME=/usr/local/lib/elixir/.mix \
  TERM=xterm \
  LANG=C.UTF-8

RUN set -xe \
  && rm -rf /usr/local/bin/rebar \
  && rm -rf /usr/local/bin/rebar3 \
  && apk add --no-cache --virtual .build-deps \
    autoconf \
    binutils-gold \
    curl curl-dev \
    dpkg dpkg-dev \
    g++ \
    gcc \
    libc-dev \
    linux-headers \
    lksctp-tools-dev \
    make \
    musl musl-dev \
    rsync \
    tar

FROM deps_stage as elixir_stage

RUN set -xe \
  && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VER}.tar.gz" \
  && ELIXIR_DOWNLOAD_SHA256="de8c636ea999392496ccd9a204ccccbc8cb7f417d948fd12692cda2bd02d9822" \
  && curl -fSL -o elixir-src.tar.gz "$ELIXIR_DOWNLOAD_URL" \
  && echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
  && export ELIXIR_TOP="/usr/src/elixir_src_${ELIXIR_VER%%@*}" \
  && mkdir -vp $ELIXIR_TOP \
  && tar -xzf elixir-src.tar.gz -C $ELIXIR_TOP --strip-components=1 \
  && rm elixir-src.tar.gz \
  && ( cd $ELIXIR_TOP \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install clean ) \
  && rm -rf $ELIXIR_TOP \
  && find /usr/local -regex '/usr/local/lib/elixir/\(lib/\|erts-\).*/\(man\|doc\|obj\|c_src\|emacs\|info\|examples\)' | xargs rm -rf \
  && find /usr/local -name src | xargs -r find | grep -v '\.hrl$' | xargs rm -v || true \
  && find /usr/local -name src | xargs -r find | xargs rmdir -vp || true \
  && scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/local | xargs -r strip --strip-all \
  && scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/local | xargs -r strip --strip-unneeded

FROM elixir_stage as hex_stage

RUN set -xe \
  && HEX_DOWNLOAD_URL="https://github.com/hexpm/hex/archive/v${HEX_VER}.tar.gz" \
  && HEX_DOWNLOAD_SHA256="31f78e75483d27e8636be346e153aaed72e6529f13859f84a6b54718a8ef2ba9" \
  && curl -fSL -o hex-src.tar.gz "$HEX_DOWNLOAD_URL" \
  && echo "$HEX_DOWNLOAD_SHA256  hex-src.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/hex-src \
  && tar -xzf hex-src.tar.gz -C /usr/src/hex-src --strip-components=1 \
  && rm hex-src.tar.gz \
  && cd /usr/src/hex-src \
  && MIX_ENV=prod mix install

FROM elixir_stage as rebar2_stage

RUN set -xe \
  && REBAR_DOWNLOAD_URL="https://github.com/rebar/rebar/archive/${REBAR2_VER}.tar.gz" \
  && REBAR_DOWNLOAD_SHA256="577246bafa2eb2b2c3f1d0c157408650446884555bf87901508ce71d5cc0bd07" \
  && curl -fSL -o rebar-src.tar.gz "$REBAR_DOWNLOAD_URL" \
  && echo "$REBAR_DOWNLOAD_SHA256  rebar-src.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/rebar-src \
  && tar -xzf rebar-src.tar.gz -C /usr/src/rebar-src --strip-components=1 \
  && rm rebar-src.tar.gz \
  && cd /usr/src/rebar-src \
  && ./bootstrap \
  && MIX_ENV=prod mix local.rebar rebar ./rebar

FROM elixir_stage as rebar3_stage

RUN set -xe \
  && REBAR3_DOWNLOAD_URL="https://github.com/erlang/rebar3/archive/${REBAR3_VER}.tar.gz" \
  && REBAR3_DOWNLOAD_SHA256="fc4d08037d39bcc651a4a749f8a5b1a10b2205527df834c2aee8f60725c3f431" \
  && curl -fSL -o rebar3-src.tar.gz "$REBAR3_DOWNLOAD_URL" \
  && echo "$REBAR3_DOWNLOAD_SHA256  rebar3-src.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/rebar3-src \
  && tar -xzf rebar3-src.tar.gz -C /usr/src/rebar3-src --strip-components=1 \
  && rm rebar3-src.tar.gz \
  && cd /usr/src/rebar3-src \
  && HOME=$PWD ./bootstrap \
  && MIX_ENV=prod mix local.rebar rebar3 ./rebar3

FROM deps_stage as stage

COPY --from=elixir_stage /usr/local /opt/elixir
COPY --from=hex_stage /usr/local /opt/hex
COPY --from=rebar2_stage /usr/local /opt/rebar2
COPY --from=rebar3_stage /usr/local /opt/rebar3

RUN set -xe \
  && rsync -a /opt/elixir/ /usr/local \
  && rsync -a /opt/hex/ /usr/local \
  && rsync -a /opt/rebar2/ /usr/local \
  && rsync -a /opt/rebar3/ /usr/local \
  && apk del .build-deps \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/*

FROM base_stage

COPY --from=stage /usr/local /usr/local
