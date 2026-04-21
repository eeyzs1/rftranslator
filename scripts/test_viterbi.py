import ctranslate2
import json
import os
import math

MODEL_PATH = r"E:\scope_ct2\ct2\opus-mt-en-zh"

def load_vocab(model_path):
    vocab_path = os.path.join(model_path, "shared_vocabulary.json")
    with open(vocab_path, 'r', encoding='utf-8') as f:
        vocab = json.load(f)
    return vocab

def tokenize_viterbi(text, vocab, token_log_probs):
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
    
    n = len(processed)
    NEG_INF = -1e30
    best_score = [NEG_INF] * (n + 1)
    best_split = [-1] * (n + 1)
    best_score[0] = 0.0
    
    for i in range(n):
        if best_score[i] == NEG_INF:
            continue
        max_len = min(n - i, 64)
        for length in range(1, max_len + 1):
            candidate = processed[i:i+length]
            if candidate in token_log_probs:
                score = best_score[i] + token_log_probs[candidate]
                if score > best_score[i + length]:
                    best_score[i + length] = score
                    best_split[i + length] = i
    
    if best_score[n] != NEG_INF:
        end = n
        seg_tokens = []
        while end > 0:
            start = best_split[end]
            if start < 0:
                break
            seg_tokens.append(processed[start:end])
            end = start
        seg_tokens.reverse()
        tokens.extend(seg_tokens)
    else:
        pos = 0
        while pos < len(processed):
            best_len = 0
            max_len2 = min(len(processed) - pos, 256)
            for length in range(max_len2, 0, -1):
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
    
    log_vocab_size = math.log(len(vocab))
    token_log_probs = {}
    for token in vocab:
        token_log_probs[token] = -log_vocab_size
    
    test_cases = [
        "It is a living organism, this metropolis.",
        "The city becomes a circuit board of gold and neon.",
        "We build these towers of ambition not just to touch the sky, but to find a vantage point.",
        "The city awakens not with a roar, but with a whisper.",
        "The only true wisdom is in knowing you know nothing.",
        "The Silent Symphony of the City",
    ]
    
    print("=" * 80)
    print("COMPARISON: Greedy vs Viterbi tokenization")
    print("=" * 80)
    
    for text in test_cases:
        greedy_tokens = tokenize_greedy(text, vocab)
        viterbi_tokens = tokenize_viterbi(text, vocab, token_log_probs)
        
        print(f"\nInput: {text}")
        print(f"Greedy:  {greedy_tokens}")
        print(f"Viterbi: {viterbi_tokens}")
        
        if greedy_tokens == viterbi_tokens:
            print(">>> SAME <<<")
        else:
            print(">>> DIFFERENT <<<")
        
        results_greedy = translator.translate_batch([greedy_tokens], beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
        results_viterbi = translator.translate_batch([viterbi_tokens], beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
        
        out_greedy = detokenize_sp(results_greedy[0].hypotheses[0])
        out_viterbi = detokenize_sp(results_viterbi[0].hypotheses[0])
        
        print(f"Greedy  output: {out_greedy}")
        print(f"Viterbi output: {out_viterbi}")

if __name__ == "__main__":
    main()
