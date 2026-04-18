import argparse
import os
import sys

try:
    import ctranslate2
except ImportError:
    print("Installing ctranslate2...")
    os.system(f"{sys.executable} -m pip install ctranslate2")
    import ctranslate2

try:
    from transformers import MarianMTModel, MarianTokenizer
except ImportError:
    print("Installing transformers...")
    os.system(f"{sys.executable} -m pip install transformers torch")
    from transformers import MarianMTModel, MarianTokenizer


def convert_model(model_dir, output_dir, quantization="int8"):
    model_name = os.path.basename(model_dir.rstrip("/\\"))
    if not output_dir:
        output_dir = model_dir + "-ct2"

    print(f"Converting: {model_name}")
    print(f"  Source: {model_dir}")
    print(f"  Output: {output_dir}")
    print(f"  Quantization: {quantization}")

    os.makedirs(output_dir, exist_ok=True)

    print("  Loading MarianMT model...")
    tokenizer = MarianTokenizer.from_pretrained(model_dir)
    model = MarianMTModel.from_pretrained(model_dir)

    print("  Converting to CTranslate2 format...")
    ctranslate2.converters.transformers_converter(
        model_dir,
        output_dir=output_dir,
        force=True,
    )

    print(f"  ✓ Converted successfully: {output_dir}")

    vocab_src = os.path.join(output_dir, "source_vocabulary.txt")
    vocab_tgt = os.path.join(output_dir, "target_vocabulary.txt")
    if os.path.exists(vocab_src):
        print(f"  Source vocabulary: {vocab_src}")
    if os.path.exists(vocab_tgt):
        print(f"  Target vocabulary: {vocab_tgt}")

    return output_dir


def main():
    parser = argparse.ArgumentParser(description="Convert OPUS-MT MarianMT models to CTranslate2 format")
    parser.add_argument("--model_dir", help="Path to a single MarianMT model directory")
    parser.add_argument("--models_dir", help="Path to directory containing multiple opus-mt-* model directories")
    parser.add_argument("--output_dir", help="Output directory (default: <model_dir>-ct2)")
    parser.add_argument("--quantization", default="int8", choices=["int8", "int8_float16", "float16", "float32"],
                        help="Quantization type (default: int8)")

    args = parser.parse_args()

    if args.model_dir:
        convert_model(args.model_dir, args.output_dir, args.quantization)
    elif args.models_dir:
        for name in sorted(os.listdir(args.models_dir)):
            if name.startswith("opus-mt-"):
                model_path = os.path.join(args.models_dir, name)
                if os.path.isdir(model_path):
                    config_file = os.path.join(model_path, "config.json")
                    if os.path.exists(config_file):
                        out_dir = args.output_dir
                        if out_dir:
                            out_dir = os.path.join(out_dir, name + "-ct2")
                        convert_model(model_path, out_dir, args.quantization)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
