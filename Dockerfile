FROM alpine:3.11.3 as base_stage

LABEL maintainer="beardedeagle <randy@heroictek.com>"

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images.
ENV REFRESHED_AT=2020-01-29 \
  ELIXIR_VER=1.10.0 \
  HEX_VER=0.20.1 \
  REBAR3_VER=3.13.0 \
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

FROM beardedeagle/alpine-erlang-builder:22.2.4 as deps_stage

ENV ELIXIR_VER=1.10.0 \
  HEX_VER=0.20.1 \
  REBAR3_VER=3.13.0 \
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
  && ELIXIR_DOWNLOAD_SHA256="6f0d35acfcbede5ef7dced3e37f016fd122c2779000ca9dcaf92975b220737b7" \
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
  && HEX_DOWNLOAD_SHA256="6af8bda12e3c81d15b9d274c1ab2d6afd9a40e28c1db7bb50baf79b6a73bb3ea" \
  && curl -fSL -o hex-src.tar.gz "$HEX_DOWNLOAD_URL" \
  && echo "$HEX_DOWNLOAD_SHA256  hex-src.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/hex-src \
  && tar -xzf hex-src.tar.gz -C /usr/src/hex-src --strip-components=1 \
  && rm hex-src.tar.gz \
  && cd /usr/src/hex-src \
  && MIX_ENV=prod mix install

FROM elixir_stage as rebar3_stage

RUN set -xe \
  && REBAR3_DOWNLOAD_URL="https://github.com/erlang/rebar3/archive/${REBAR3_VER}.tar.gz" \
  && REBAR3_DOWNLOAD_SHA256="49ecf89d04676d077712a10d8252bbda73998a3badf8b342481530fbc685a123" \
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
COPY --from=rebar3_stage /usr/local /opt/rebar3

RUN set -xe \
  && rsync -a /opt/elixir/ /usr/local \
  && rsync -a /opt/hex/ /usr/local \
  && rsync -a /opt/rebar3/ /usr/local \
  && apk del .build-deps \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/*

FROM base_stage

COPY --from=stage /usr/local /usr/local
