import ctranslate2
import json
import os

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
    
    full_text = """The only true wisdom is in knowing you know nothing.

The Silent Symphony of the City

The city awakens not with a roar, but with a whisper—a subtle shift in the light that bleeds through the high-rise canyons, turning the steel and glass into silhouettes against a bruised purple sky. It is a living organism, this metropolis, breathing in the quiet hours of the dawn and exhaling the chaotic energy of millions as the sun climbs higher.

To walk through the streets at this hour is to witness the backstage of a grand theater. The frantic pace of the stock market and the digital frenzy of the financial district are momentarily paused. There is a profound beauty in the geometry of the urban landscape—the rigid lines of the architecture contrasting with the organic flow of the river that cuts through it like a vein of liquid mercury. The air carries the scent of roasted beans from a corner bistro, mingling with the metallic tang of the subway rails, a sensory prelude to the day's performance.

As the morning progresses, the city transforms into a complex network of human connection. It is a paradox of isolation and intimacy; thousands of people shoulder-to-shoulder on a subway platform, each trapped in their own private universe of thought, yet moving as a single, synchronized entity. The technology that surrounds us—the glowing rectangles in our pockets, the seamless flow of information—has not replaced the need for physical presence but has instead layered a digital ghost over the physical world. We are never truly alone, yet we are constantly seeking connection in the noise.

By evening, the artificial lights mimic the stars that the pollution has hidden. The city becomes a circuit board of gold and neon. In this vertical labyrinth, ambition is the currency, and time is the resource we are all trying to manage. We build these towers of ambition not just to touch the sky, but to find a vantage point from which to understand our place within the beautiful, terrifying complexity of it all."""

    print("=" * 70)
    print("TEST 1: Full text as single input (current approach)")
    print("=" * 70)
    tokens = tokenize_greedy(full_text, vocab)
    print(f"Token count: {len(tokens)}")
    results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=512, repetition_penalty=1.1)
    output = detokenize_sp(results[0].hypotheses[0])
    print(f"Output:\n{output}")
    
    print("\n" + "=" * 70)
    print("TEST 2: Split by paragraphs, translate each separately")
    print("=" * 70)
    paragraphs = [p.strip() for p in full_text.split('\n\n') if p.strip()]
    for i, para in enumerate(paragraphs):
        tokens = tokenize_greedy(para, vocab)
        print(f"\nParagraph {i+1} ({len(tokens)} tokens): {para[:60]}...")
        results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=512, repetition_penalty=1.1)
        output = detokenize_sp(results[0].hypotheses[0])
        print(f"Translation: {output}")
    
    print("\n" + "=" * 70)
    print("TEST 3: Split by sentences, translate each separately")
    print("=" * 70)
    import re
    sentences = re.split(r'(?<=[.!?])\s+', full_text)
    sentences = [s for s in sentences if s.strip()]
    full_translation = []
    for i, sent in enumerate(sentences):
        tokens = tokenize_greedy(sent, vocab)
        results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=256, repetition_penalty=1.1)
        output = detokenize_sp(results[0].hypotheses[0])
        full_translation.append(output)
        print(f"S{i+1}: {sent[:50]}... => {output}")
    
    print(f"\nFull translation (sentence-by-sentence):\n{''.join(full_translation)}")
    
    print("\n" + "=" * 70)
    print("TEST 4: Higher repetition penalty for full text")
    print("=" * 70)
    for penalty in [1.2, 1.5, 2.0]:
        tokens = tokenize_greedy(full_text, vocab)
        results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=512, repetition_penalty=penalty)
        output = detokenize_sp(results[0].hypotheses[0])
        has_repeat = "流流" in output or "路路" in output
        print(f"penalty={penalty}: repeat={'YES' if has_repeat else 'NO'} | {output[:100]}...")

if __name__ == "__main__":
    main()
