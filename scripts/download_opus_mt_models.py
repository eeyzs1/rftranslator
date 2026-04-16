"""
Download all OPUS-MT models from HuggingFace for uploading to ModelScope.

Usage:
    python download_opus_mt_models.py [--output-dir ./opus_mt_models] [--mirror]

Options:
    --output-dir  Directory to save downloaded models (default: ./opus_mt_models)
    --mirror      Use hf-mirror.com instead of huggingface.co (for China network)
"""

import os
import sys
import argparse
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("Installing huggingface_hub...")
    os.system(f"{sys.executable} -m pip install huggingface_hub")
    from huggingface_hub import snapshot_download

MODELS = [
    "Helsinki-NLP/opus-mt-en-zh",
    "Helsinki-NLP/opus-mt-zh-en",
    "Helsinki-NLP/opus-mt-en-de",
    "Helsinki-NLP/opus-mt-de-en",
    "Helsinki-NLP/opus-mt-en-fr",
    "Helsinki-NLP/opus-mt-fr-en",
    "Helsinki-NLP/opus-mt-en-es",
    "Helsinki-NLP/opus-mt-es-en",
    "Helsinki-NLP/opus-mt-en-it",
    "Helsinki-NLP/opus-mt-it-en",
    "Helsinki-NLP/opus-mt-en-pt",
    "Helsinki-NLP/opus-mt-pt-en",
    "Helsinki-NLP/opus-mt-en-ru",
    "Helsinki-NLP/opus-mt-ru-en",
    "Helsinki-NLP/opus-mt-en-ar",
    "Helsinki-NLP/opus-mt-ar-en",
    "Helsinki-NLP/opus-mt-en-ja",
    "Helsinki-NLP/opus-mt-ja-en",
    "Helsinki-NLP/opus-mt-en-ko",
    "Helsinki-NLP/opus-mt-ko-en",
]

ALLOW_PATTERNS = [
    "config.json",
    "pytorch_model.bin",
    "source.spm",
    "target.spm",
    "vocab.json",
]


def main():
    parser = argparse.ArgumentParser(description="Download OPUS-MT models from HuggingFace")
    parser.add_argument("--output-dir", default="./opus_mt_models", help="Output directory")
    parser.add_argument("--mirror", action="store_true", help="Use hf-mirror.com (China)")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    endpoint = "https://hf-mirror.com" if args.mirror else None
    if args.mirror:
        os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
        print(f"Using mirror: {endpoint}")

    print(f"Output directory: {output_dir.resolve()}")
    print(f"Models to download: {len(MODELS)}")
    print("=" * 60)

    success = []
    failed = []

    for i, model_id in enumerate(MODELS, 1):
        model_name = model_id.split("/")[1]
        model_dir = output_dir / model_name

        if model_dir.exists() and any(model_dir.iterdir()):
            print(f"[{i}/{len(MODELS)}] {model_name} - already exists, skipping")
            success.append(model_id)
            continue

        print(f"[{i}/{len(MODELS)}] Downloading {model_id} ...")

        try:
            downloaded = snapshot_download(
                repo_id=model_id,
                local_dir=str(model_dir),
                allow_patterns=ALLOW_PATTERNS,
                endpoint=endpoint,
            )
            print(f"  -> Saved to {downloaded}")
            success.append(model_id)
        except Exception as e:
            print(f"  -> FAILED: {e}")
            failed.append((model_id, str(e)))

    print("=" * 60)
    print(f"\nDone! Success: {len(success)}, Failed: {len(failed)}")

    if failed:
        print("\nFailed models:")
        for model_id, error in failed:
            print(f"  - {model_id}: {error}")

    print(f"\nAll models saved to: {output_dir.resolve()}")
    print("\nTo upload to ModelScope, use:")
    print("  pip install modelscope")
    for model_id in MODELS:
        model_name = model_id.split("/")[1]
        print(f"  modelscope upload --model your-username/{model_name} {output_dir / model_name}")


if __name__ == "__main__":
    main()
