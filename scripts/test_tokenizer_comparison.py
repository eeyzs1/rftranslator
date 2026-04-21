import ctranslate2
import json
import os
import sys

MODEL_PATH = r"E:\scope_ct2\ct2\opus-mt-en-zh"

def load_vocab(model_path):
    vocab_path = os.path.join(model_path, "shared_vocabulary.json")
    with open(vocab_path, 'r', encoding='utf-8') as f:
        vocab = json.load(f)
    return vocab

def tokenize_greedy(text, vocab):
    SP_MARKER = '\u2581'
    lang_token = ""
    for token in vocab:
        if token.startswith(">>") and token.endswith("<<"):
            lang_token = token
            break
    tokens = []
    if lang_token:
        tokens.append(lang_token)
    processed = SP_MARKER
    i = 0
    while i < len(text):
        c = text[i]
        if c in ' \t\n\r':
            if not processed.endswith(SP_MARKER):
                processed += SP_MARKER
            i += 1
        elif '\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' or '\uf900' <= c <= '\ufaff':
            if not processed.endswith(SP_MARKER):
                processed += SP_MARKER
            processed += c
            i += 1
        else:
            processed += c
            i += 1
    pos = 0
    while pos < len(processed):
        best_len = 0
        max_len = min(len(processed) - pos, 256)
        for length in range(max_len, 0, -1):
            candidate = processed[pos:pos+length]
            if candidate in vocab:
                best_len = length
                break
        if best_len > 0:
            tokens.append(processed[pos:pos+best_len])
            pos += best_len
        else:
            pos += 1
    tokens.append("</s>")
    return tokens

def detokenize_sp(tokens):
    result = ""
    for token in tokens:
        if token in ("<unk>", "<s>", "</s>", "<pad>"):
            continue
        if token.startswith(">>") and token.endswith("<<"):
            continue
        if token.startswith('\u2581'):
            if result:
                result += ' '
            result += token[1:]
        else:
            result += token
    return result

def main():
    vocab = load_vocab(MODEL_PATH)
    translator = ctranslate2.Translator(MODEL_PATH, device="cpu")

    try:
        import sentencepiece as spm
        sp_path = None
        for candidate in ["source.spm", "target.spm", "shared.spm"]:
            p = os.path.join(MODEL_PATH, candidate)
            if os.path.exists(p):
                sp_path = p
                break

        if not sp_path:
            print("No .spm file found. Trying to extract from model config...")
            try:
                from transformers import AutoTokenizer
                tokenizer = AutoTokenizer.from_pretrained("Helsinki-NLP/opus-mt-en-zh")
                sp_model = tokenizer.sp_model
                sp_path = os.path.join(MODEL_PATH, "_extracted.spm")
                if not os.path.exists(sp_path):
                    pass
                print("Using transformers tokenizer for comparison")
                
                test_sentences = [
                    "The city awakens not with a roar, but with a whisper.",
                    "It is a living organism, this metropolis.",
                    "The city becomes a circuit board of gold and neon.",
                    "We build these towers of ambition not just to touch the sky, but to find a vantage point.",
                    "The only true wisdom is in knowing you know nothing.",
                ]
                
                print("\n" + "=" * 80)
                print("COMPARISON: Greedy tokenization vs Transformers (SentencePiece) tokenizer")
                print("=" * 80)
                
                for text in test_sentences:
                    greedy_tokens = tokenize_greedy(text, vocab)
                    sp_tokens_raw = tokenizer.tokenize(text)
                    sp_tokens = [">>cmn_Hans<<"] + sp_tokens_raw + ["</s>"]
                    
                    print(f"\nInput: {text}")
                    print(f"Greedy ({len(greedy_tokens)}): {greedy_tokens}")
                    print(f"SP    ({len(sp_tokens)}): {sp_tokens}")
                    
                    if greedy_tokens != sp_tokens:
                        print(">>> DIFFERENT! <<<")
                    
                    results_greedy = translator.translate_batch([greedy_tokens], beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
                    results_sp = translator.translate_batch([sp_tokens], beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
                    
                    out_greedy = detokenize_sp(results_greedy[0].hypotheses[0])
                    out_sp = detokenize_sp(results_sp[0].hypotheses[0])
                    
                    print(f"Greedy output: {out_greedy}")
                    print(f"SP output:     {out_sp}")
                
            except Exception as e:
                print(f"Could not load transformers tokenizer: {e}")
                print("Falling back to greedy-only test")
                _run_greedy_only_test(translator, vocab)
        else:
            print(f"SentencePiece model found: {sp_path}")
            _run_sp_comparison(translator, vocab, sp_path)
    except ImportError:
        print("sentencepiece not installed")
        _run_greedy_only_test(translator, vocab)

def _run_greedy_only_test(translator, vocab):
    test_sentences = [
        "The city awakens not with a roar, but with a whisper.",
        "It is a living organism, this metropolis.",
        "The city becomes a circuit board of gold and neon.",
        "We build these towers of ambition not just to touch the sky, but to find a vantage point.",
        "The only true wisdom is in knowing you know nothing.",
    ]
    
    print("\n" + "=" * 80)
    print("GREEDY TOKENIZATION TEST")
    print("=" * 80)
    
    for text in test_sentences:
        tokens = tokenize_greedy(text, vocab)
        results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
        output = detokenize_sp(results[0].hypotheses[0])
        print(f"\nInput:  {text}")
        print(f"Tokens: {tokens}")
        print(f"Output: {output}")
    
    print("\n" + "=" * 80)
    print("PARAMETER TUNING TEST")
    print("=" * 80)
    
    text = "It is a living organism, this metropolis."
    tokens = tokenize_greedy(text, vocab)
    
    for beam in [1, 2, 4, 6]:
        for penalty in [1.0, 1.1, 1.2, 1.5, 2.0]:
            for length_penalty in [0.6, 0.8, 1.0, 1.2]:
                try:
                    results = translator.translate_batch(
                        [tokens],
                        beam_size=beam,
                        max_decoding_length=256,
                        repetition_penalty=penalty,
                        length_penalty=length_penalty,
                    )
                    output = detokenize_sp(results[0].hypotheses[0])
                    if "metropolis" in text.lower() and ("大都市" in output or "都市" in output or "城市" in output):
                        print(f"✅ beam={beam} penalty={penalty} len_penalty={length_penalty}: {output}")
                    elif beam == 4 and penalty == 1.1 and length_penalty == 1.0:
                        print(f"❌ beam={beam} penalty={penalty} len_penalty={length_penalty}: {output}")
                except Exception as e:
                    pass

if __name__ == "__main__":
    main()
