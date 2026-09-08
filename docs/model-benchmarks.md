# Local vision model benchmark

Run date: 8 September 2026 (Australia/Sydney). Ollama reported version 0.19.0.

This is a small functional benchmark for the Clicky pipeline, not a general model leaderboard. Both models were already installed locally; no model was downloaded for this test. The same checked-in screenshot was sent to both models for the same three prompts, using Ollama's non-streaming `/api/chat`, temperature 0.2 and `num_predict=512`. The source image is [codex-app-screenshot.jpg](../leanring-buddy/Assets.xcassets/codex-app-screenshot.imageset/codex-app-screenshot.jpg), 2000x1125 and 60,050 bytes. It is a repository asset used as a reproducible fallback, not a live ScreenCaptureKit capture.

The exact command was:

```sh
python3 scripts/benchmark_local_vision.py \
  --image leanring-buddy/Assets.xcassets/codex-app-screenshot.imageset/codex-app-screenshot.jpg \
  --output /tmp/clicky-local-vision-benchmark.json
```

The cases were: a one-sentence visual summary quoting `Let's build` and `Codex`; JSON coordinates for the white send button (expected centre approximately x=1460, y=910 in the original image); and an exact three-line instruction-following response. A result counts as correct only when it satisfies the requested format and the visual target.

| Model | Ollama metadata | Case results | Empty answer | Total case time | Observed resident model |
|---|---|---|---:|---:|---|
| `qwen3-vl:4b` | qwen3vl, 4.4B, Q4_K_M | summary partial; coordinates fail with empty answer and `done_reason=length`; exact lines pass | 1/3 | 49.3 s | 4.4 GB, 100% GPU |
| `gemma3:4b` | gemma3, 4.3B, Q4_K_M | summary pass; coordinates fail (768,632, fenced JSON); exact lines pass | 0/3 | 4.4 s | 4.2 GB, 100% GPU |

The individual elapsed times were qwen: 11.550 s, 28.930 s and 8.808 s; gemma: 1.981 s, 1.565 s and 0.868 s. These were sequential requests on a warm Ollama service, so they are useful pipeline evidence rather than a cold-start or statistically stable latency estimate. `ollama ps` observed both models resident at the same time with a 4096 runtime context; the displayed size is a model allocation estimate, not a complete system memory or VRAM profile.

Neither model produced a usable coordinate for this screenshot. Qwen's coordinate request consumed all 512 output tokens in thinking and returned empty `message.content` with HTTP 200 and `done_reason=length`, even though the benchmark did not append `/no_think`. The application client does append `/no_think`; this benchmark deliberately records the model's baseline behavior and confirms why the directive remains necessary. Gemma returned a syntactically fenced JSON object with a substantially incorrect coordinate. The benchmark therefore does not support enabling autonomous cursor pointing by default.

## Controlled application-shaped run

The same three cases were repeated with `/no_think` appended to every user message and `num_predict=512`, matching the current client request shape. Raw sanitized evidence is in [benchmark-results.json](benchmark-results.json); it contains only the repository asset path and model responses.

| Model | Case times | Empty answer | Controlled total | Result |
|---|---:|---:|---:|---|
| `qwen3-vl:4b` | 12.410 s, 26.770 s, 7.681 s | 1/3 | 46.9 s | summary and exact lines pass; coordinate still ends `length` with empty answer |
| `gemma3:4b` | 1.887 s, 1.440 s, 0.983 s | 0/3 | 4.3 s | summary and exact lines pass; coordinate still wrong (768,544) and fenced |

The directive improved Qwen's summary wording in this sample but did not make the coordinate case usable. It is still appropriate in the app because the earlier failure mode is real, while the controlled run shows it is not a complete coordinate solution.

## Recommendation

Use `gemma3:4b` as the dependable default for the current local path. In both runs it answered quickly, had no empty response, and followed the exact-text instruction; retain coordinate validation and treat failed or malformed coordinates as ordinary text-only responses. Keep `qwen3-vl:4b` selectable for further testing, with the existing `/no_think` directive and a sufficiently large output budget. Do not claim either model has reliable screen-coordinate accuracy from this one screenshot.

Ollama's official Qwen tag listing does include `qwen3-vl:4b-instruct` and its 3.3 GB Q4_K_M variant, alongside the installed `qwen3-vl:4b-thinking` tag. It is a plausible follow-up because it removes the thinking variant at the same nominal size, but downloading it is not justified for this milestone: the controlled run already supports Gemma as the faster, non-empty default, and the instruct tag was not installed or benchmarked here.

The model choice is consistent with Ollama's official model pages: [Gemma 3](https://ollama.com/library/gemma3) documents a 4B multimodal image model, while [Qwen3-VL](https://ollama.com/library/qwen3-vl) documents the 4B vision model and its thinking capability. The request and response fields used here follow Ollama's official [`/api/chat` documentation](https://docs.ollama.com/api/chat).
