FROM debian:trixie

RUN apt update
RUN apt install -y build-essential wget binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu git python3 python3-pip qemu-system-arm

# Install zig
RUN cd /tmp; \
    wget https://ziglang.org/download/0.15.2/zig-aarch64-linux-0.15.2.tar.xz; \
    tar -xf zig-aarch64-linux-0.15.2.tar.xz; \
    cd zig-aarch64-linux-0.15.2; \
    mv zig /usr/bin/; \
    mv lib /usr/lib/zig

# Install sdfgen tool
RUN cd /tmp; \
    git clone --depth=1 https://github.com/au-ts/microkit_sdf_gen.git; \
    git checkout 0.28.1; \
    cd microkit_sdf_gen; \
    zig build c -p /usr/; \
    pip install . --break-system-packages
