# syntax=docker/dockerfile:1.7

ARG CUDA_VERSION=12.8.1

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LLAMA_CPP_REF=prism
# NVIDIA architectures used by Hugging Face's current GPU catalog:
# T4=75, A100=80, A10G=86, L4/L40S=89, H100/H200=90, Blackwell RTX PRO 6000=120.
ARG CUDA_ARCHITECTURES="75;80;86;89;90;120"

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      cmake \
      git \
      ninja-build \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 --branch "${LLAMA_CPP_REF}" \
      https://github.com/PrismML-Eng/llama.cpp.git

RUN cmake -S /src/llama.cpp -B /src/llama.cpp/build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
      -DBUILD_SHARED_LIBS=OFF \
      -DGGML_CUDA=ON \
      -DGGML_NATIVE=OFF \
      -DGGML_CUDA_FA_ALL_QUANTS=ON \
      -DLLAMA_CURL=OFF \
      -DLLAMA_BUILD_SERVER=ON \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
    && cmake --build /src/llama.cpp/build --target llama-server --parallel 2 \
    && strip /src/llama.cpp/build/bin/llama-server

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/llama.cpp/build/bin/llama-server /app/llama-server

LABEL org.opencontainers.image.source="https://github.com/freddwithy/bonsai-llama-cpp"
LABEL org.opencontainers.image.description="PrismML llama.cpp CUDA server for Ternary Bonsai 2"
LABEL org.opencontainers.image.licenses="MIT"

EXPOSE 8080

ENTRYPOINT ["/app/llama-server"]
