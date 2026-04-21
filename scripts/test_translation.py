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
    print("=" * 70)
    print("CTranslate2 Final Translation Quality Test")
    print("Model: opus-mt-en-zh (with </s> + beam=4 + penalty=1.1)")
    print("=" * 70)
    
    vocab = load_vocab(MODEL_PATH)
    translator = ctranslate2.Translator(MODEL_PATH, device="cpu")
    
    test_cases = [
        ("短句-日常", "Hello, how are you today?"),
        ("短句-新闻", "The United Nations held an emergency meeting on climate change yesterday."),
        ("短句-技术", "The software update includes security patches and performance improvements."),
        ("短句-哲学", "The only true wisdom is in knowing you know nothing."),
        ("中句-描述", "Technology has transformed the way we communicate. From letters to emails, and now to instant messaging, each advancement has brought people closer together."),
        ("中句-经济", "Despite the economic challenges posed by the pandemic, many small businesses have shown remarkable resilience by adapting their business models to embrace digital commerce and remote work arrangements."),
        ("长句-文学", "The city awakens not with a roar, but with a whisper, a subtle shift in the light that bleeds through the high-rise canyons, turning the steel and glass into silhouettes against a bruised purple sky."),
        ("长句-科技", "Artificial intelligence has rapidly evolved from a niche field of computer science into a transformative technology that is reshaping industries ranging from healthcare and finance to transportation and entertainment, raising both hopes for unprecedented efficiency and concerns about job displacement and ethical implications."),
        ("段落-城市", "To walk through the streets at this hour is to witness the backstage of a grand theater. The frantic pace of the stock market and the digital frenzy of the financial district are momentarily paused. There is a profound beauty in the geometry of the urban landscape."),
        ("段落-科技", "The technology that surrounds us has not replaced the need for physical presence but has instead layered a digital ghost over the physical world. We are never truly alone, yet we are constantly seeking connection in the noise."),
        ("中文输入", "This is a test with numbers 123 and symbols @#$%."),
        ("专业术语", "The algorithm uses a convolutional neural network with batch normalization and dropout regularization to prevent overfitting."),
        ("口语化", "I think we should grab some coffee and talk about this later."),
        ("反问句", "Isn't it amazing how quickly things can change when you least expect it?"),
        ("条件句", "If we don't act now, the consequences could be far more severe than anyone anticipated."),
    ]
    
    print(f"\n{'测试名称':<12} | {'原文':<50} | {'译文'}")
    print("-" * 120)
    
    for name, text in test_cases:
        tokens = tokenize_greedy(text, vocab)
        results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=512, repetition_penalty=1.1)
        output = detokenize_sp(results[0].hypotheses[0])
        
        display_text = text[:47] + "..." if len(text) > 50 else text
        print(f"{name:<12} | {display_text:<50} | {output}")
    
    print("\n" + "=" * 70)
    print("长段落翻译测试")
    print("=" * 70)
    
    long_paragraphs = [
        ("完整段落1", """The Silent Symphony of the City

The city awakens not with a roar, but with a whisper—a subtle shift in the light that bleeds through the high-rise canyons, turning the steel and glass into silhouettes against a bruised purple sky. It is a living organism, this metropolis, breathing in the quiet hours of the dawn and exhaling the chaotic energy of millions as the sun climbs higher.

To walk through the streets at this hour is to witness the backstage of a grand theater. The frantic pace of the stock market and the digital frenzy of the financial district are momentarily paused. There is a profound beauty in the geometry of the urban landscape—the rigid lines of the architecture contrasting with the organic flow of the river that cuts through it like a vein of liquid mercury."""),
        
        ("完整段落2", """Artificial intelligence represents one of the most significant technological advances of the twenty-first century. From virtual assistants that manage our daily schedules to sophisticated algorithms that can diagnose diseases with remarkable accuracy, AI is transforming every aspect of human life. However, this rapid progress also raises important ethical questions about privacy, autonomy, and the future of work. As we stand on the brink of an AI-driven revolution, it is crucial that we develop these technologies responsibly, ensuring that the benefits are shared broadly across society while minimizing potential harms."""),
    ]
    
    for name, text in long_paragraphs:
        print(f"\n--- {name} ---")
        print(f"原文:\n{text}")
        tokens = tokenize_greedy(text, vocab)
        results = translator.translate_batch([tokens], beam_size=4, max_decoding_length=512, repetition_penalty=1.1)
        output = detokenize_sp(results[0].hypotheses[0])
        print(f"译文:\n{output}")

if __name__ == "__main__":
    main()
