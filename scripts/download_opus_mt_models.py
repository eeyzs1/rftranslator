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
    # === 已下载并上传到 ModelScope 的模型 (eeyzs1/) ===
    "Helsinki-NLP/opus-mt-en-zh",       # -> eeyzs1/opus-mt-en-zh
    "Helsinki-NLP/opus-mt-zh-en",       # -> eeyzs1/opus-mt-zh-en
    "Helsinki-NLP/opus-mt-en-de",       # -> eeyzs1/opus-mt-en-de
    "Helsinki-NLP/opus-mt-de-en",       # -> eeyzs1/opus-mt-de-en
    "Helsinki-NLP/opus-mt-en-fr",       # -> eeyzs1/opus-mt-en-fr
    "Helsinki-NLP/opus-mt-fr-en",       # -> eeyzs1/opus-mt-fr-en
    "Helsinki-NLP/opus-mt-en-es",       # -> eeyzs1/opus-mt-en-es
    "Helsinki-NLP/opus-mt-es-en",       # -> eeyzs1/opus-mt-es-en
    "Helsinki-NLP/opus-mt-en-it",       # -> eeyzs1/opus-mt-en-it
    "Helsinki-NLP/opus-mt-it-en",       # -> eeyzs1/opus-mt-it-en
    "Helsinki-NLP/opus-mt-en-ru",       # -> eeyzs1/opus-mt-en-ru
    "Helsinki-NLP/opus-mt-ru-en",       # -> eeyzs1/opus-mt-ru-en
    "Helsinki-NLP/opus-mt-en-ar",       # -> eeyzs1/opus-mt-en-ar
    "Helsinki-NLP/opus-mt-ar-en",       # -> eeyzs1/opus-mt-ar-en
    "Helsinki-NLP/opus-mt-en-jap",      # -> eeyzs1/opus-mt-en-jap
    "Helsinki-NLP/opus-mt-jap-en",      # -> eeyzs1/opus-mt-jap-en
    "Helsinki-NLP/opus-mt-tc-big-en-ko",# -> eeyzs1/opus-mt-en-ko (重命名)
    "Helsinki-NLP/opus-mt-ko-en",       # -> eeyzs1/opus-mt-ko-en

    # === 待下载的中文语对模型 ===
    "Helsinki-NLP/opus-mt-zh-de",         # -> eeyzs1/opus-mt-zh-de   (中→德)
    "Helsinki-NLP/opus-mt-de-ZH",         # -> eeyzs1/opus-mt-de-zh   (德→中, 注意大写ZH)
    "Helsinki-NLP/opus-mt-zh-it",         # -> eeyzs1/opus-mt-zh-it   (中→意)
    "Helsinki-NLP/opus-mt-zh-vi",         # -> eeyzs1/opus-mt-zh-vi   (中→越)

    "Helsinki-NLP/opus-mt-fi-ZH",         # -> eeyzs1/opus-mt-fi-zh   (芬→中, 注意大写ZH)
    "Helsinki-NLP/opus-mt-sv-ZH",         # -> eeyzs1/opus-mt-sv-zh   (瑞→中, 注意大写ZH)
    "Helsinki-NLP/opus-mt-zh-bg",         # -> eeyzs1/opus-mt-zh-bg   (中→保)
    "Helsinki-NLP/opus-mt-zh-fi",         # -> eeyzs1/opus-mt-zh-fi   (中→芬)
    "Helsinki-NLP/opus-mt-zh-he",         # -> eeyzs1/opus-mt-zh-he   (中→希)
    "Helsinki-NLP/opus-mt-zh-ms",         # -> eeyzs1/opus-mt-zh-ms   (中→马)
    "Helsinki-NLP/opus-mt-zh-nl",         # -> eeyzs1/opus-mt-zh-nl   (中→荷)
    "Helsinki-NLP/opus-mt-zh-sv",         # -> eeyzs1/opus-mt-zh-sv   (中→瑞)
    "Helsinki-NLP/opus-mt-zh-uk",         # -> eeyzs1/opus-mt-zh-uk   (中→乌)
]

ALLOW_PATTERNS = [
    "config.json",
    "pytorch_model.bin",
    "source.spm",
    "target.spm",
    "vocab.json",
]

RENAME_MAP = {
    "opus-mt-de-ZH": "opus-mt-de-zh",
    "opus-mt-fi-ZH": "opus-mt-fi-zh",
    "opus-mt-sv-ZH": "opus-mt-sv-zh",
    "opus-mt-tc-big-en-ko": "opus-mt-en-ko",
}

MODELSCOPE_USERNAME = "eeyzs1"


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
        download_dir = output_dir / model_name
        rename_to = RENAME_MAP.get(model_name)
        final_dir = output_dir / rename_to if rename_to else download_dir

        if final_dir.exists() and any(final_dir.iterdir()):
            print(f"[{i}/{len(MODELS)}] {rename_to or model_name} - already exists, skipping")
            success.append(model_id)
            continue

        print(f"[{i}/{len(MODELS)}] Downloading {model_id} ...")

        try:
            downloaded = snapshot_download(
                repo_id=model_id,
                local_dir=str(final_dir),
                # allow_patterns=ALLOW_PATTERNS,
                endpoint=endpoint,
            )
            print(f"  -> Saved to {downloaded}")

            if rename_to and download_dir != final_dir:
                if download_dir.exists():
                    download_dir.rename(final_dir)
                    print(f"  -> Renamed to {final_dir.name}")

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
        folder_name = RENAME_MAP.get(model_name, model_name)
        print(f"  modelscope upload --model {MODELSCOPE_USERNAME}/{folder_name} {output_dir / folder_name}")


if __name__ == "__main__":
    main()
