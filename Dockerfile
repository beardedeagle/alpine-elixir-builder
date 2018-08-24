FROM beardedeagle/alpine-erlang-builder:21.0.6 as base_stage

LABEL maintainer="beardedeagle <randy@heroictek.com>"

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images.
ENV REFRESHED_AT=2018-08-24b \
  ELIXIR_VER=1.7.3 \
  MIX_HOME=/usr/local/lib/elixir/.mix \
  TERM=xterm \
  LANG=C.UTF-8

RUN set -xe \
  && rm -rf /usr/local/bin/rebar \
  && rm -rf /usr/local/bin/rebar3

FROM base_stage as deps_stage

RUN set -xe \
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
  && ELIXIR_DOWNLOAD_SHA256="c9beabd05e820ee83a56610cf2af3f34acf3b445c8fabdbe98894c886d2aa28e" \
  && curl -fSL -o elixir-src.tar.gz "$ELIXIR_DOWNLOAD_URL" \
  && echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
  && export ELIXIR_TOP="/usr/src/elixir_src_${ELIXIR_VER%%@*}" \
  && mkdir -vp $ELIXIR_TOP \
  && tar -xzf elixir-src.tar.gz -C $ELIXIR_TOP --strip-components=1 \
  && rm elixir-src.tar.gz \
  && ( cd $ELIXIR_TOP \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install ) \
  && rm -rf $ELIXIR_TOP \
  && find /usr/local -regex '/usr/local/lib/elixir/\(lib/\|erts-\).*/\(man\|doc\|obj\|c_src\|emacs\|info\|examples\)' | xargs rm -rf \
  && find /usr/local -name src | xargs -r find | grep -v '\.hrl$' | xargs rm -v || true \
  && find /usr/local -name src | xargs -r find | xargs rmdir -vp || true \
  && scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/local | xargs -r strip --strip-all \
  && scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/local | xargs -r strip --strip-unneeded \
  && mix local.hex --force \
  && mix local.rebar --force

FROM deps_stage as stage

COPY --from=elixir_stage /usr/local /opt/elixir

RUN set -xe \
  && rsync -a /opt/elixir/ /usr/local \
  && apk del .build-deps \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/*

FROM base_stage

COPY --from=stage /usr/local /usr/local
