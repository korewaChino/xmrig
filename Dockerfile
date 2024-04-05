FROM fedora:latest

COPY . /src
WORKDIR /src
RUN mkdir -p build
RUN \
    --mount=type=cache,target=/var/cache/dnf \
    dnf install -y git make cmake gcc gcc-c++ g++ libstdc++-static libstdc++-devel libuv-static hwloc-devel openssl-devel automake libtool autoconf


WORKDIR /src/build
ENV CFLAGS=""
ENV CXXFLAGS=""
RUN cmake .. -DWITH_CUDA=OFF 
RUN make -j$(nproc)

RUN chmod +x ./xmrig

CMD ["/src/build/xmrig"]