# Bonsai llama.cpp CUDA image

CUDA-enabled [PrismML llama.cpp fork](https://github.com/PrismML-Eng/llama.cpp) for serving
[`prism-ml/Ternary-Bonsai-2-27B-gguf`](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf)
on Hugging Face Inference Endpoints.

Bonsai 2 uses Prism's `PQ2_0` / `PTQ1_0` formats and Hadamard activation transform.
Stock `llama.cpp` images cannot run these weights correctly.

## Container image

```text
ghcr.io/freddwithy/bonsai-llama-cpp:cuda
```

The image:

- Builds the `prism` branch of `PrismML-Eng/llama.cpp`.
- Uses CUDA 12.8.
- Includes kernels for T4, A10G, A100, L4/L40S, H100/H200, and RTX PRO 6000 Blackwell.
- Exposes the standard OpenAI-compatible `llama-server`.
- Does not bundle model weights. Hugging Face mounts the selected model under `/repository`.

## Recommended Hugging Face configuration

Use the model repository `prism-ml/Ternary-Bonsai-2-27B-gguf` and select:

| Setting | Value |
| --- | --- |
| GGUF file | `Ternary-Bonsai-2-27B-PQ2_0.gguf` |
| Inference engine | `llama.cpp` |
| Engine container URL | `ghcr.io/freddwithy/bonsai-llama-cpp:cuda` |
| Hardware | `1x NVIDIA RTX PRO 6000 Blackwell (96 GB)` |
| Max Tokens per Request | `262144` |
| Max Concurrent Requests | `2` |
| Number of layers on GPU | Leave empty (all layers) |
| Embeddings pooling | `None` |
| Mode | `Default` |
| Server Arguments | `--flash-attn on` |

For vision requests, select `Ternary-Bonsai-2-27B-mmproj-BF16.gguf` as the multimodal
projector. Leave it unset for text-only use to save memory.

Hugging Face sets the reserved `LLAMA_ARG_*` environment variables automatically,
including the model path, host, port, context size, GPU layers, and parallel request
count. Do not add those variables manually.

## Concurrency and sessions

One endpoint and one API URL can serve both users. Set concurrency to `2` for two
simultaneous generations. Each user can keep multiple application-level chat sessions;
only actively generating requests consume concurrency slots.

Ten conversations do not require ten model copies. Their message history is sent with
each request, while the two active requests share the same loaded model.

## Build and publish

Every change to `main` that touches the container files triggers GitHub Actions and
publishes:

- `ghcr.io/freddwithy/bonsai-llama-cpp:cuda`
- `ghcr.io/freddwithy/bonsai-llama-cpp:sha-<commit>`

You can also run the workflow manually from the repository's **Actions** tab.

After the first successful build, make the GHCR package **Public** so Hugging Face can
pull it without registry credentials.

## Local smoke test

Requires an NVIDIA GPU, Docker, and the NVIDIA Container Toolkit:

```bash
docker run --rm --gpus all -p 8080:8080 \
  -v "$PWD/models:/models:ro" \
  ghcr.io/freddwithy/bonsai-llama-cpp:cuda \
  --host 0.0.0.0 \
  --port 8080 \
  --model /models/Ternary-Bonsai-2-27B-PQ2_0.gguf \
  --ctx-size 8192 \
  --n-gpu-layers 999 \
  --flash-attn on
```

Check readiness:

```bash
curl http://localhost:8080/health
```

## Upstream references

- [PrismML Bonsai demo](https://github.com/PrismML-Eng/Bonsai-demo)
- [PrismML llama.cpp fork](https://github.com/PrismML-Eng/llama.cpp)
- [Hugging Face llama.cpp engine](https://huggingface.co/docs/inference-endpoints/engines/llama_cpp)
- [Hugging Face custom containers](https://huggingface.co/docs/inference-endpoints/guides/custom_container)
