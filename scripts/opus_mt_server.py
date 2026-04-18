import sys
import os
import json

try:
    from transformers import MarianMTModel, MarianTokenizer
except ImportError:
    print(json.dumps({"error": "transformers not installed, installing..."}), flush=True)
    os.system(f"{sys.executable} -m pip install transformers torch --quiet")
    from transformers import MarianMTModel, MarianTokenizer

_model = None
_tokenizer = None
_model_path = None


def load_model(model_path):
    global _model, _tokenizer, _model_path
    if _model is not None and _model_path == model_path:
        return {"status": "already_loaded"}
    try:
        _tokenizer = MarianTokenizer.from_pretrained(model_path)
        _model = MarianMTModel.from_pretrained(model_path)
        _model_path = model_path
        return {"status": "loaded"}
    except Exception as e:
        _model = None
        _tokenizer = None
        _model_path = None
        return {"status": "error", "error": str(e)}


def translate(text):
    global _model, _tokenizer
    if _model is None or _tokenizer is None:
        return {"error": "model not loaded"}

    try:
        inputs = _tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=512)
        outputs = _model.generate(**inputs, max_length=512, num_beams=4, early_stopping=True)
        result = _tokenizer.decode(outputs[0], skip_special_tokens=True)
        return {"translation": result}
    except Exception as e:
        return {"error": str(e)}


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            print(json.dumps({"error": "invalid json"}), flush=True)
            continue

        cmd = request.get("cmd")

        if cmd == "load":
            model_path = request.get("model_path", "")
            result = load_model(model_path)
            print(json.dumps(result), flush=True)

        elif cmd == "translate":
            text = request.get("text", "")
            result = translate(text)
            print(json.dumps(result), flush=True)

        elif cmd == "quit":
            print(json.dumps({"status": "quitting"}), flush=True)
            break

        else:
            print(json.dumps({"error": f"unknown command: {cmd}"}), flush=True)


if __name__ == "__main__":
    main()
