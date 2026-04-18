r"""
Download MarianMT models from ModelScope, convert to CTranslate2 format, and upload back.

Usage:
    python scope_download_convert_upload.py [--output-dir E:\scope_ct2] [--skip-download] [--skip-convert] [--skip-upload] [--only en-zh,zh-en]

Options:
    --output-dir    Base directory (default: E:\scope_ct2)
    --skip-download Skip download step
    --skip-convert  Skip conversion step
    --skip-upload   Skip upload step
    --only          Only process specific language pairs (comma-separated)
"""

import os
import sys
import argparse
import time
from pathlib import Path

try:
    from modelscope.hub.snapshot_download import snapshot_download
except ImportError:
    print("Installing modelscope...")
    os.system(f"{sys.executable} -m pip install modelscope")
    from modelscope.hub.snapshot_download import snapshot_download

try:
    import ctranslate2
except ImportError:
    print("Installing ctranslate2...")
    os.system(f"{sys.executable} -m pip install ctranslate2")
    import ctranslate2

MODELSCOPE_USERNAME = "eeyzs1"

MODELS = [
    {"scope_src": "eeyzs1/opus-mt-en-zh", "folder": "opus-mt-en-zh", "pair": "en->zh"},
    {"scope_src": "eeyzs1/opus-mt-zh-en", "folder": "opus-mt-zh-en", "pair": "zh->en"},
    {"scope_src": "eeyzs1/opus-mt-en-de", "folder": "opus-mt-en-de", "pair": "en->de"},
    {"scope_src": "eeyzs1/opus-mt-en-fr", "folder": "opus-mt-en-fr", "pair": "en->fr"},
    {"scope_src": "eeyzs1/opus-mt-en-es", "folder": "opus-mt-en-es", "pair": "en->es"},
    {"scope_src": "eeyzs1/opus-mt-en-it", "folder": "opus-mt-en-it", "pair": "en->it"},
    {"scope_src": "eeyzs1/opus-mt-en-ru", "folder": "opus-mt-en-ru", "pair": "en->ru"},
    {"scope_src": "eeyzs1/opus-mt-en-ar", "folder": "opus-mt-en-ar", "pair": "en->ar"},
    {"scope_src": "eeyzs1/opus-mt-en-jap", "folder": "opus-mt-en-jap", "pair": "en->ja"},
    {"scope_src": "eeyzs1/opus-mt-en-ko", "folder": "opus-mt-en-ko", "pair": "en->ko"},
    {"scope_src": "eeyzs1/opus-mt-de-en", "folder": "opus-mt-de-en", "pair": "de->en"},
    {"scope_src": "eeyzs1/opus-mt-fr-en", "folder": "opus-mt-fr-en", "pair": "fr->en"},
    {"scope_src": "eeyzs1/opus-mt-es-en", "folder": "opus-mt-es-en", "pair": "es->en"},
    {"scope_src": "eeyzs1/opus-mt-it-en", "folder": "opus-mt-it-en", "pair": "it->en"},
    {"scope_src": "eeyzs1/opus-mt-ru-en", "folder": "opus-mt-ru-en", "pair": "ru->en"},
    {"scope_src": "eeyzs1/opus-mt-ar-en", "folder": "opus-mt-ar-en", "pair": "ar->en"},
    {"scope_src": "eeyzs1/opus-mt-jap-en", "folder": "opus-mt-jap-en", "pair": "ja->en"},
    {"scope_src": "eeyzs1/opus-mt-ko-en", "folder": "opus-mt-ko-en", "pair": "ko->en"},
    {"scope_src": "eeyzs1/opus-mt-zh-de", "folder": "opus-mt-zh-de", "pair": "zh->de"},
    {"scope_src": "eeyzs1/opus-mt-de-zh", "folder": "opus-mt-de-zh", "pair": "de->zh"},
    {"scope_src": "eeyzs1/opus-mt-zh-it", "folder": "opus-mt-zh-it", "pair": "zh->it"},
    {"scope_src": "eeyzs1/opus-mt-zh-vi", "folder": "opus-mt-zh-vi", "pair": "zh->vi"},
    {"scope_src": "eeyzs1/opus-mt-zh-jap", "folder": "opus-mt-zh-jap", "pair": "zh->ja"},
    {"scope_src": "eeyzs1/opus-mt-fi-zh", "folder": "opus-mt-fi-zh", "pair": "fi->zh"},
    {"scope_src": "eeyzs1/opus-mt-sv-zh", "folder": "opus-mt-sv-zh", "pair": "sv->zh"},
    {"scope_src": "eeyzs1/opus-mt-zh-bg", "folder": "opus-mt-zh-bg", "pair": "zh->bg"},
    {"scope_src": "eeyzs1/opus-mt-zh-fi", "folder": "opus-mt-zh-fi", "pair": "zh->fi"},
    {"scope_src": "eeyzs1/opus-mt-zh-he", "folder": "opus-mt-zh-he", "pair": "zh->he"},
    {"scope_src": "eeyzs1/opus-mt-zh-ms", "folder": "opus-mt-zh-ms", "pair": "zh->ms"},
    {"scope_src": "eeyzs1/opus-mt-zh-nl", "folder": "opus-mt-zh-nl", "pair": "zh->nl"},
    {"scope_src": "eeyzs1/opus-mt-zh-sv", "folder": "opus-mt-zh-sv", "pair": "zh->sv"},
    {"scope_src": "eeyzs1/opus-mt-zh-uk", "folder": "opus-mt-zh-uk", "pair": "zh->uk"},
]


def step_download(base_dir, models):
    download_dir = base_dir / "original"
    download_dir.mkdir(parents=True, exist_ok=True)

    for i, m in enumerate(models):
        target = download_dir / m["folder"]
        if target.exists() and (target / "config.json").exists():
            print(f"[{i+1}/{len(models)}] {m['folder']} already exists, skipping")
            continue

        print(f"[{i+1}/{len(models)}] Downloading {m['scope_src']} ({m['pair']}) ...")
        try:
            snapshot_download(
                model_id=m["scope_src"],
                local_dir=str(target),
                allow_file_pattern=["config.json", "pytorch_model.bin", "source.spm", "target.spm", "vocab.json", "tokenizer_config.json", "generation_config.json"],
            )
            print(f"  -> Saved to {target}")
        except Exception as e:
            print(f"  -> FAILED: {e}")
            continue

    return download_dir


def step_convert(base_dir, download_dir, models):
    ct2_dir = base_dir / "ct2"
    ct2_dir.mkdir(parents=True, exist_ok=True)

    for i, m in enumerate(models):
        src = download_dir / m["folder"]
        dst = ct2_dir / m["folder"]

        if not src.exists() or not any(src.iterdir()):
            print(f"[{i+1}/{len(models)}] Source not found: {src}, skipping")
            continue

        if dst.exists() and (dst / "model.bin").exists():
            model_bin_size = (dst / "model.bin").stat().st_size
            if model_bin_size < 200 * 1024 * 1024:
                print(f"[{i+1}/{len(models)}] {m['folder']} CT2 (int8) already exists, skipping")
                continue
            else:
                print(f"[{i+1}/{len(models)}] {m['folder']} CT2 exists but not quantized ({model_bin_size/1024/1024:.0f}MB), re-converting...")

        print(f"[{i+1}/{len(models)}] Converting {m['folder']} ({m['pair']}) ...")

        start = time.time()
        try:
            converter = ctranslate2.converters.TransformersConverter(str(src))
            converter.convert(str(dst), force=True, quantization="int8")
            elapsed = time.time() - start

            orig_size = sum(f.stat().st_size for f in src.rglob("*") if f.is_file())
            ct2_size = sum(f.stat().st_size for f in dst.rglob("*") if f.is_file())

            print(f"  -> Done in {elapsed:.1f}s")
            print(f"  -> Original: {orig_size/1024/1024:.1f} MB")
            print(f"  -> CT2: {ct2_size/1024/1024:.1f} MB")
            print(f"  -> Ratio: {ct2_size/orig_size:.1%}")
        except Exception as e:
            print(f"  -> FAILED: {e}")
            continue

    return ct2_dir


def step_upload(ct2_dir, models):
    print(f"[UPLOAD] Uploading to ModelScope (user: {MODELSCOPE_USERNAME})")

    for i, m in enumerate(models):
        local_path = ct2_dir / m["folder"]
        if not local_path.exists() or not (local_path / "model.bin").exists():
            print(f"[{i+1}/{len(models)}] CT2 model not found: {local_path}, skipping")
            continue

        scope_repo = f"{MODELSCOPE_USERNAME}/{m['folder']}-ct2"
        print(f"[{i+1}/{len(models)}] Uploading {m['folder']} ({m['pair']}) ...")
        print(f"  Local: {local_path}")
        print(f"  Remote: {scope_repo}")

        pair = m["pair"]
        cmd = f'modelscope upload {scope_repo} "{local_path}" --repo-type model --commit-message "upload ct2 int8 model: {pair}"'
        ret = os.system(cmd)
        if ret == 0:
            print(f"  -> SUCCESS")
        else:
            print(f"  -> FAILED (exit code: {ret})")

    print("[UPLOAD] Done!")


def main():
    parser = argparse.ArgumentParser(
        description="Download from ModelScope, convert to CT2, upload back to ModelScope"
    )
    parser.add_argument(
        "--output-dir",
        default=r"E:\scope_ct2",
        help="Base directory (default: E:\\scope_ct2)",
    )
    parser.add_argument("--skip-download", action="store_true")
    parser.add_argument("--skip-convert", action="store_true")
    parser.add_argument("--skip-upload", action="store_true")
    parser.add_argument("--only", default=None, help="Only process these pairs (comma-separated, e.g. en-zh,zh-en)")
    args = parser.parse_args()

    base_dir = Path(args.output_dir)
    base_dir.mkdir(parents=True, exist_ok=True)

    models = MODELS
    if args.only:
        pairs = set(args.only.split(","))
        models = [m for m in MODELS if m["pair"].replace("->", "-") in pairs or m["folder"] in pairs]
        print(f"Filtered to {len(models)} models")

    print("=" * 60)
    print("ModelScope MarianMT -> CTranslate2 Pipeline")
    print(f"Output: {base_dir.resolve()}")
    print(f"Models: {len(models)}")
    for m in models:
        print(f"  - {m['scope_src']} ({m['pair']})")
    print("=" * 60)

    download_dir = base_dir / "original"
    ct2_dir = base_dir / "ct2"

    if not args.skip_download:
        print("\n>>> STEP 1: Download from ModelScope <<<")
        download_dir = step_download(base_dir, models)
    else:
        print(f"\n>>> STEP 1: Download (SKIPPED) <<<")

    if not args.skip_convert:
        print("\n>>> STEP 2: Convert to CT2 <<<")
        ct2_dir = step_convert(base_dir, download_dir, models)
    else:
        print(f"\n>>> STEP 2: Convert (SKIPPED) <<<")

    if not args.skip_upload:
        print("\n>>> STEP 3: Upload to ModelScope <<<")
        step_upload(ct2_dir, models)
    else:
        print(f"\n>>> STEP 3: Upload (SKIPPED) <<<")

    print("\n" + "=" * 60)
    print("All done!")
    print("=" * 60)


if __name__ == "__main__":
    main()
