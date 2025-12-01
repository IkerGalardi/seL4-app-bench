FROM debian:trixie

RUN apt update
RUN apt install -y wget binutils-aarch64-linux-gnu
