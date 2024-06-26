ARG CUDA_VERSION=12.4.1
ARG OS_VERSION=22.04
ARG TRT_VERSION=10.0.1.6-1+cuda12.4
ARG KATAGO_VERSION=v1.14.1

# ---------------------------------------------------------------------------
FROM registry-1.docker.io/nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu${OS_VERSION} as tensorrt-runner
# ---------------------------------------------------------------------------

ARG TRT_VERSION
ARG CUDA_VERSION

ENV DEBIAN_FRONTEND noninteractive

RUN v="${TRT_VERSION}" \
  && apt update -y && apt install -y \
  libnvinfer10=${v} \
  libnvonnxparsers10=${v} \
  libnvinfer-plugin10=${v} \
  && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------
FROM registry-1.docker.io/nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${OS_VERSION} as builder
# -----------------------------------------------------------------

ARG TRT_VERSION
ARG CUDA_VERSION

ENV DEBIAN_FRONTEND noninteractive

RUN v="${TRT_VERSION}" \
  && apt update -y && apt install -y \
  libnvinfer-dev=${v} \
  libnvonnxparsers-dev=${v} \
  libnvinfer-plugin-dev=${v} \
  wget \
  git \
  zlib1g-dev \
  libzip-dev \
  && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/Kitware/CMake/releases/download/v3.29.2/cmake-3.29.2-linux-x86_64.sh \
  -q -O /tmp/cmake-install.sh \
  && chmod u+x /tmp/cmake-install.sh \
  && /tmp/cmake-install.sh --skip-license --prefix=/usr/local \
  && rm /tmp/cmake-install.sh

WORKDIR /

ARG KATAGO_VERSION
RUN git clone -b ${KATAGO_VERSION} https://github.com/lightvector/KataGo.git && mkdir -p /KataGo/cpp/build

WORKDIR /KataGo/cpp/build

RUN cmake .. -DUSE_BACKEND=TENSORRT
RUN make -j$(nproc)

# ------------------
FROM tensorrt-runner
# ------------------

RUN apt update -y && apt install --no-install-recommends -y \
  zlib1g-dev \
  libzip-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /KataGo/cpp/build/katago /app/katago
RUN chmod +x /app/katago

ENTRYPOINT ["/app/katago"]
