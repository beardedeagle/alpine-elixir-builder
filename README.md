# Docker + Alpine + Elixir = Love

This Dockerfile provides a good base build image to use in multistage builds for Elixir apps. It comes with the latest version of Alpine, Erlang, Elixir, Rebar and Hex. It is intended for use in creating release images with or for your application and allows you to avoid cross-compiling releases. The exception of course is if your app has NIFs which require a native compilation toolchain, but that is an exercise left to the user.

No effort has been made to make this image suitable to run in unprivileged environments. The repository owner is not responsible for any losses that result from improper usage or security practices, as it is expected that the user of this image will implement proper security practices themselves.

## Software/Language Versions

```shell
Alpine 3.10.2
OTP/Erlang 22.0.7
Elixir 1.9.1
Rebar 3.12.0
Hex 0.20.1
```

## Usage

To boot straight to a iex prompt in the image:

```shell
$ docker run --rm -i -t beardedeagle/alpine-elixir-builder iex
Erlang/OTP 22 [erts-10.4.4] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Interactive Elixir (1.9.1) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```
