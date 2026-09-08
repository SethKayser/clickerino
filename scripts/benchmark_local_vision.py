#!/usr/bin/env python3
"""Repeatable Ollama vision benchmark for Clicky's local model choice.

The benchmark intentionally uses one checked-in screenshot and identical prompts
for every model. It records the complete Ollama response so correctness can be
reviewed without pretending that latency alone proves usefulness.
"""
import argparse
import base64
import json
import pathlib
import subprocess
import time
import urllib.request


QUESTIONS = [
    {
        "id": "visual_summary",
        "prompt": "In one sentence, identify the app shown and quote the two prominent central texts.",
        "expected": "Mentions a Codex-style app and both \"Let's build\" and \"Codex\".",
    },
    {
        "id": "coordinate",
        "prompt": "The screenshot is 2000x1125 pixels. Return JSON only as {\"x\": number, \"y\": number} for the centre of the white circular send button at the lower right of the composer.",
        "expected": "Centre approximately x=1460, y=910; valid JSON with numeric x and y.",
    },
    {
        "id": "instruction_following",
        "prompt": "Return exactly these three lines and no other text:\nAPP=Codex\nSTATE=New thread\nMODE=Local",
        "expected": "Exact three-line output.",
    },
]


def request(endpoint, model, image, prompt, timeout, no_think):
    if no_think:
        prompt = prompt + "\n\n/no_think"
    body = {
        "model": model,
        "stream": False,
        "messages": [{"role": "user", "content": prompt, "images": [image]}],
        "options": {"temperature": 0.2, "num_predict": 512},
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read())
        elapsed = time.monotonic() - started
        message = payload.get("message") or {}
        try:
            memory_snapshot = subprocess.run(["ollama", "ps"], capture_output=True, text=True, timeout=5).stdout.strip()
        except Exception as error:
            memory_snapshot = f"unavailable: {error}"
        return {
            "elapsed_seconds": round(elapsed, 3),
            "http_status": 200,
            "done_reason": payload.get("done_reason"),
            "answer": (message.get("content") or "").strip(),
            "thinking": (message.get("thinking") or "").strip(),
            "error": payload.get("error"),
            "eval_count": payload.get("eval_count"),
            "prompt_eval_count": payload.get("prompt_eval_count"),
            "ollama_ps": memory_snapshot,
        }
    except Exception as error:  # Keep one failed case from hiding other evidence.
        return {"elapsed_seconds": round(time.monotonic() - started, 3), "error": str(error), "answer": ""}


def model_metadata(endpoint, model):
    show_endpoint = endpoint.rsplit("/api/", 1)[0] + "/api/show"
    body = json.dumps({"name": model}).encode()
    request = urllib.request.Request(show_endpoint, data=body, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.loads(response.read())
        details = payload.get("details") or {}
        return {key: details.get(key) for key in ("family", "parameter_size", "quantization_level")}
    except Exception as error:
        return {"error": str(error)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--models", nargs="+", default=["qwen3-vl:4b", "gemma3:4b"])
    parser.add_argument("--endpoint", default="http://127.0.0.1:11434/api/chat")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--output", required=True)
    parser.add_argument("--no-think", action="store_true", help="Mirror the app's Qwen directive.")
    args = parser.parse_args()

    image_bytes = pathlib.Path(args.image).read_bytes()
    image = base64.b64encode(image_bytes).decode()
    results = {
        "benchmark": "clicky-local-vision-v1",
        "image": str(pathlib.Path(args.image)),
        "image_bytes": len(image_bytes),
        "endpoint": args.endpoint,
        "no_think": args.no_think,
        "models": {},
    }
    for model in args.models:
        model_results = []
        results["models"][model] = {"metadata": model_metadata(args.endpoint, model), "cases": model_results}
        for question in QUESTIONS:
            result = request(args.endpoint, model, image, question["prompt"], args.timeout, args.no_think)
            result["question_id"] = question["id"]
            result["expected"] = question["expected"]
            model_results.append(result)
    pathlib.Path(args.output).write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
