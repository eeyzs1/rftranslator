r"""
Download, convert, and upload the two missing tc-big OPUS-MT models to CTranslate2 format.

Models:
  - Helsinki-NLP/opus-mt-tc-big-en-ko  (en->ko)
  - Helsinki-NLP/opus-mt-tc-big-zh-ja  (zh->ja)

Usage:
    python download_convert_upload_tc_big.py [--output-dir E:\opus_mt_tc_big] [--mirror] [--skip-download] [--skip-convert] [--skip-upload]

Options:
    --output-dir    Base directory for downloads and conversions (default: E:\opus_mt_tc_big)
    --mirror        Use hf-mirror.com instead of huggingface.co
    --skip-download Skip download step
    --skip-convert  Skip conversion step
    --skip-upload   Skip upload step
"""

import os
import sys
import argparse
import time
import shutil
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("Installing huggingface_hub...")
    os.system(f"{sys.executable} -m pip install huggingface_hub")
    from huggingface_hub import snapshot_download

try:
    import ctranslate2
except ImportError:
    print("Installing ctranslate2...")
    os.system(f"{sys.executable} -m pip install ctranslate2")
    import ctranslate2

try:
    from transformers import MarianTokenizer, MarianMTModel
except ImportError:
    print("Installing transformers and torch...")
    os.system(f"{sys.executable} -m pip install transformers torch")
    from transformers import MarianTokenizer, MarianMTModel

MODELS = [
    {
        "hf_repo": "Helsinki-NLP/opus-mt-tc-big-en-ko",
        "download_name": "opus-mt-tc-big-en-ko",
        "ct2_name": "opus-mt-tc-big-en-ko-ct2",
        "scope_name": "opus-mt-tc-big-en-ko-ct2",
        "lang_pair": "en->ko",
    },
    {
        "hf_repo": "Helsinki-NLP/opus-mt-tc-big-zh-ja",
        "download_name": "opus-mt-tc-big-zh-ja",
        "ct2_name": "opus-mt-tc-big-zh-ja-ct2",
        "scope_name": "opus-mt-tc-big-zh-ja-ct2",
        "lang_pair": "zh->ja",
    },
]

MODELSCOPE_USERNAME = "eeyzs1"
QUANTIZATION = "int8"


def step_download(base_dir, use_mirror):
    download_dir = base_dir / "original"
    download_dir.mkdir(parents=True, exist_ok=True)

    endpoint = "https://hf-mirror.com" if use_mirror else None
    if use_mirror:
        os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
        print(f"[DOWNLOAD] Using mirror: hf-mirror.com")

    for m in MODELS:
        target = download_dir / m["download_name"]
        if target.exists() and any(target.iterdir()):
            print(f"[DOWNLOAD] {m['download_name']} already exists, skipping")
            continue

        print(f"[DOWNLOAD] Downloading {m['hf_repo']} ({m['lang_pair']}) ...")
        try:
            snapshot_download(
                repo_id=m["hf_repo"],
                local_dir=str(target),
                endpoint=endpoint,
            )
            print(f"[DOWNLOAD]   -> Saved to {target}")
        except Exception as e:
            print(f"[DOWNLOAD]   -> FAILED: {e}")
            print(f"[DOWNLOAD]   -> Trying with mirror...")
            try:
                os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
                snapshot_download(
                    repo_id=m["hf_repo"],
                    local_dir=str(target),
                    endpoint="https://hf-mirror.com",
                )
                print(f"[DOWNLOAD]   -> Saved to {target} (via mirror)")
            except Exception as e2:
                print(f"[DOWNLOAD]   -> FAILED with mirror too: {e2}")
                continue

    return download_dir


def step_convert(base_dir, download_dir):
    ct2_dir = base_dir / "ct2"
    ct2_dir.mkdir(parents=True, exist_ok=True)

    for m in MODELS:
        src = download_dir / m["download_name"]
        dst = ct2_dir / m["ct2_name"]

        if not src.exists() or not any(src.iterdir()):
            print(f"[CONVERT] Source not found: {src}, skipping")
            continue

        if dst.exists() and any(dst.iterdir()):
            print(f"[CONVERT] {m['ct2_name']} already exists, skipping")
            continue

        print(f"[CONVERT] Converting {m['download_name']} ({m['lang_pair']}) ...")
        print(f"[CONVERT]   Source: {src}")
        print(f"[CONVERT]   Output: {dst}")
        print(f"[CONVERT]   Quantization: {QUANTIZATION}")

        start = time.time()
        try:
            converter = ctranslate2.converters.TransformersConverter(str(src))
            converter.convert(str(dst), force=True)
            elapsed = time.time() - start

            orig_size = sum(
                f.stat().st_size for f in src.rglob("*") if f.is_file()
            )
            ct2_size = sum(
                f.stat().st_size for f in dst.rglob("*") if f.is_file()
            )

            print(f"[CONVERT]   -> Done in {elapsed:.1f}s")
            print(f"[CONVERT]   -> Original: {orig_size/1024/1024:.1f} MB")
            print(f"[CONVERT]   -> CT2: {ct2_size/1024/1024:.1f} MB")
            print(f"[CONVERT]   -> Ratio: {ct2_size/orig_size:.1%}")
        except Exception as e:
            print(f"[CONVERT]   -> FAILED: {e}")
            continue

    return ct2_dir


def step_upload(ct2_dir):
    print(f"[UPLOAD] Uploading to ModelScope (user: {MODELSCOPE_USERNAME})")
    print(f"[UPLOAD] Make sure you are logged in: modelscope login")

    for m in MODELS:
        local_path = ct2_dir / m["ct2_name"]
        if not local_path.exists() or not any(local_path.iterdir()):
            print(f"[UPLOAD] CT2 model not found: {local_path}, skipping")
            continue

        scope_repo = f"{MODELSCOPE_USERNAME}/{m['scope_name']}"
        print(f"[UPLOAD] Uploading {m['ct2_name']} ({m['lang_pair']}) ...")
        print(f"[UPLOAD]   Local: {local_path}")
        print(f"[UPLOAD]   Remote: {scope_repo}")

        lang_pair = m["lang_pair"]
        cmd = f'modelscope upload {scope_repo} "{local_path}" --repo-type model --commit-message "upload ct2 model: {lang_pair}"'
        print(f"[UPLOAD]   Command: {cmd}")
        ret = os.system(cmd)
        if ret == 0:
            print(f"[UPLOAD]   -> SUCCESS")
        else:
            print(f"[UPLOAD]   -> FAILED (exit code: {ret})")

    print(f"[UPLOAD] Done!")


def main():
    parser = argparse.ArgumentParser(
        description="Download, convert, and upload tc-big OPUS-MT models to CTranslate2"
    )
    parser.add_argument(
        "--output-dir",
        default=r"E:\opus_mt_tc_big",
        help="Base directory (default: E:\\opus_mt_tc_big)",
    )
    parser.add_argument(
        "--mirror", action="store_true", help="Use hf-mirror.com (China)"
    )
    parser.add_argument("--skip-download", action="store_true", help="Skip download")
    parser.add_argument("--skip-convert", action="store_true", help="Skip conversion")
    parser.add_argument("--skip-upload", action="store_true", help="Skip upload")
    args = parser.parse_args()

    base_dir = Path(args.output_dir)
    base_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("OPUS-MT tc-big -> CTranslate2 Pipeline")
    print(f"Output: {base_dir.resolve()}")
    print(f"Models: {len(MODELS)}")
    for m in MODELS:
        print(f"  - {m['hf_repo']} ({m['lang_pair']})")
    print("=" * 60)

    download_dir = None
    ct2_dir = None

    if not args.skip_download:
        print("\n>>> STEP 1: Download <<<")
        download_dir = step_download(base_dir, args.mirror)
    else:
        download_dir = base_dir / "original"
        print(f"\n>>> STEP 1: Download (SKIPPED) <<<")
        print(f"  Assuming originals in: {download_dir}")

    if not args.skip_convert:
        print("\n>>> STEP 2: Convert <<<")
        ct2_dir = step_convert(base_dir, download_dir)
    else:
        ct2_dir = base_dir / "ct2"
        print(f"\n>>> STEP 2: Convert (SKIPPED) <<<")
        print(f"  Assuming CT2 models in: {ct2_dir}")

    if not args.skip_upload:
        print("\n>>> STEP 3: Upload <<<")
        step_upload(ct2_dir)
    else:
        print(f"\n>>> STEP 3: Upload (SKIPPED) <<<")

    print("\n" + "=" * 60)
    print("All done!")
    print(f"Original models: {download_dir}")
    print(f"CT2 models: {ct2_dir}")
    print("=" * 60)


if __name__ == "__main__":
    main()
