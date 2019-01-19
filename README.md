# Docker + Alpine + Elixir = Love

This Dockerfile provides a good base build image to use in multistage builds for Elixir apps. It comes with the latest version of Alpine, Erlang, Elixir, Rebar and Hex. It is intended for use in creating release images with or for your application and allows you to avoid cross-compiling releases. The exception of course is if your app has NIFs which require a native compilation toolchain, but that is left as an exercise let to the user.

No effort has been made to make this image suitable to run in unprivileged environments. The repository owner is not responsible for any loses that result from improper usage or security practices, as it is expected that the user of this image will implement proper security practices themselves.

## Software/Language Versions

```shell
Alpine 3.8
OTP/Erlang 21.2.3
Elixir 1.8.0
Rebar 3.8.0
Hex 0.19.0
```

## Usage

To boot straight to a iex prompt in the image:

```shell
$ docker run --rm -i -t beardedeagle/alpine-elixir-builder iex
Erlang/OTP 21 [erts-10.2.2] [source] [64-bit] [smp:6:6] [ds:6:6:10] [async-threads:1] [hipe]

Interactive Elixir (1.8.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```
