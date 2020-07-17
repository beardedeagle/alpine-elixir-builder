FROM alpine:3.12.0 as base_stage

LABEL maintainer="beardedeagle <randy@heroictek.com>"

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images.
ENV REFRESHED_AT=2020-07-16 \
  ELIXIR_VER=1.10.4 \
  HEX_VER=0.20.5 \
  REBAR3_VER=3.13.2 \
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

FROM beardedeagle/alpine-erlang-builder:23.0.2 as deps_stage

ENV ELIXIR_VER=1.10.4 \
  HEX_VER=0.20.5 \
  REBAR3_VER=3.13.2 \
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
  && ELIXIR_DOWNLOAD_SHA256="8518c78f43fe36315dbe0d623823c2c1b7a025c114f3f4adbb48e04ef63f1d9f" \
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
  && HEX_DOWNLOAD_SHA256="b88dbccfeeef83f68ec4e9f457874177dd8b0497d533b8040528dad14a8808ba" \
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
  && REBAR3_DOWNLOAD_SHA256="e14cdc1f5b7d363a238a9f555f89e878bc4fc836c970571b41b90ee947f91505" \
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
