

FROM fedora:39 as base
ENV DEPS_STD="dnf-plugin-ovl git make cmake gcc gcc-c++ g++ libstdc++-static libstdc++-devel libuv-static hwloc-devel openssl-devel automake libtool autoconf"
ENV RUNTIME_DEPS="libuv hwloc openssl"

# Add a target platform argument to the build

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log

RUN --mount=type=cache,target=/var/cache/dnf \
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    dnf-plugins-core

# cache downloads first

RUN --mount=type=cache,target=/var/cache/dnf <<EOF
    EXTRA_PKGS=""
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
        echo "Adding CUDA"
        dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/fedora39/x86_64/cuda-fedora39.repo
        dnf module disable -y nvidia-driver 
        export EXTRA_PKGS="cuda xorg-x11-drv-nvidia-cuda"
    fi
    dnf install -y $RUNTIME_DEPS $DEPS_STD $EXTRA_PKGS --downloadonly
EOF

# finally install

RUN --mount=type=cache,target=/var/cache/dnf <<EOF
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
        dnf install -y $RUNTIME_DEPS $DEPS_STD cuda xorg-x11-drv-nvidia-cuda
    else
        dnf install -y $RUNTIME_DEPS $DEPS_STD
    fi
EOF


FROM base as cuda

RUN git clone https://github.com/xmrig/xmrig-cuda.git /src


WORKDIR /src

RUN mkdir -p build

WORKDIR /src/build

RUN <<EOF
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
        cmake ..
        make -j$(nproc)
    else
        echo "CUDA is not supported on $TARGETPLATFORM! Continuing anyway"
    fi
EOF

FROM base as xmrig


COPY . /src
WORKDIR /src
RUN mkdir -p build

WORKDIR /src/build

ENV CFLAGS=""
ENV CXXFLAGS=""

RUN <<EOF
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
        cmake .. -DWITH_CUDA=ON
    else
        cmake .. -DWITH_CUDA=OFF ..
    fi
EOF

RUN make -j$(nproc)

RUN chmod +x ./xmrig

FROM base as runtime


RUN mkdir -p /xmrig

WORKDIR /xmrig

COPY --from=xmrig /src/build/xmrig /xmrig/xmrig

COPY --from=cuda /src/build /xmrig-cuda

RUN <<EOF
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
        cp -v /xmrig-cuda/*.so /xmrig/xmrig-cuda
    fi
EOF


ENTRYPOINT ["/xmrig/xmrig"]
