# Docker + Alpine + Elixir = Love

This Dockerfile provides a good base build image to use in multistage builds for Elixir apps. It comes with the latest version of Alpine, Erlang, Elixir, Rebar and Hex. It is intended for use in creating release images with or for your application and allows you to avoid cross-compiling releases. The exception of course is if your app has NIFs which require a native compilation toolchain, but that is an exercise left to the user.

No effort has been made to make this image suitable to run in unprivileged environments. The repository owner is not responsible for any losses that result from improper usage or security practices, as it is expected that the user of this image will implement proper security practices themselves.

## Software/Language Versions

```shell
Alpine 3.12.1
OTP/Erlang 23.1.1
Elixir 1.11.1
Rebar 3.14.1
Hex 0.20.6
Git 2.26.2
```

## Usage

To boot straight to a iex prompt in the image:

```shell
$ docker run --rm -i -t beardedeagle/alpine-elixir-builder iex
Erlang/OTP 23 [erts-11.1.1] [source] [64-bit] [smp:12:12] [ds:12:12:10] [async-threads:1]

Interactive Elixir (1.11.1) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```
