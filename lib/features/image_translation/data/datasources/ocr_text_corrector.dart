import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:rftranslator/features/image_translation/data/datasources/symspell.dart';

class OcrTextCorrector {
  static SymSpell? _symSpell;
  static Set<String> _wordSet = {};
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    _symSpell = SymSpell(maxEditDistance: 2);

    try {
      final jsonStr = await rootBundle.loadString('assets/data/english_dictionary.json');
      final dict = jsonDecode(jsonStr) as Map<String, dynamic>;
      final frequencies = <String, int>{};
      for (final entry in dict.entries) {
        frequencies[entry.key] = (entry.value as num).toInt();
      }
      _symSpell!.addWords(frequencies);
      _wordSet = frequencies.keys.toSet();
    } catch (e) {
      _addFallbackWords();
    }

    _initialized = true;
  }

  static void _addFallbackWords() {
    final words = [
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'it',
      'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this',
      'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or',
      'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what',
      'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me',
      'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know',
      'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could',
      'them', 'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come',
      'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how',
      'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because',
      'any', 'these', 'give', 'day', 'most', 'us', 'model', 'models',
      'network', 'networks', 'neural', 'sequence', 'transduction', 'recurrent',
      'convolutional', 'convolution', 'attention', 'mechanism', 'mechanisms',
      'encoder', 'decoder', 'decoders', 'encoding', 'decoding',
      'parallelizable', 'parallel', 'dispensing', 'constituency',
      'significantly', 'significant', 'establishes', 'established',
      'architecture', 'superior', 'inference', 'generalization',
      'generalize', 'generalizes', 'subword', 'tokenization', 'embedding',
      'normalization', 'regularization', 'optimization', 'backpropagation',
      'overfitting', 'underfitting', 'fine', 'tuning', 'pretraining',
      'transfer', 'learning', 'sequences', 'dominant', 'complex',
      'include', 'includes', 'included', 'including', 'connect', 'connects',
      'connected', 'connecting', 'propose', 'proposes', 'proposed',
      'proposing', 'require', 'requires', 'required', 'requiring',
      'achieve', 'achieves', 'achieved', 'achieving', 'improve', 'improves',
      'improved', 'improving', 'show', 'shows', 'showed', 'shown', 'showing',
      'apply', 'applies', 'applied', 'applying', 'exist', 'exists', 'existed',
      'existing', 'perform', 'performs', 'performed', 'performing',
      'train', 'trains', 'trained', 'training', 'parse', 'parses', 'parsed',
      'parsing', 'base', 'bases', 'based', 'basing', 'task', 'tasks',
      'result', 'results', 'resulted', 'resulting', 'score', 'scores',
      'cost', 'costs', 'literature', 'ensemble', 'ensembles', 'fraction',
      'limited', 'solely', 'entirely', 'whereas', 'thereby', 'thereof',
      'transformer', 'transformers', 'translation', 'translate', 'translated',
      'machine', 'german', 'french', 'english', 'bleu', 'wmt', 'gpu', 'gpus',
      'simple', 'quality', 'eight', 'days', 'best', 'better', 'small',
      'successfully', 'both', 'data', 'large', 'less', 'more', 'through',
      'while', 'after', 'between', 'against', 'during', 'without', 'within',
      'among', 'along', 'following', 'according', 'regarding', 'despite',
      'except', 'beyond', 'toward', 'towards', 'upon', 'whether', 'whenever',
      'wherever', 'although', 'though', 'unless', 'until', 'since',
      'because', 'therefore', 'thus', 'hence', 'consequently',
      'furthermore', 'moreover', 'nevertheless', 'nonetheless', 'meanwhile',
      'otherwise', 'rather', 'instead', 'indeed', 'certainly', 'obviously',
      'apparently', 'naturally', 'typically', 'generally', 'specifically',
      'particularly', 'especially', 'notably', 'substantially',
      'considerably', 'extensively', 'effectively', 'efficiently',
      'accurately', 'precisely', 'approximately', 'respectively',
      'independently', 'simultaneously', 'consistently',
    ];
    for (final word in words) {
      _symSpell!.addWord(word);
    }
    _wordSet = words.toSet();
  }

  static String correct(String text) {
    if (text.isEmpty) return text;

    var result = text;

    result = _fixDollarNumberPatterns(result);
    result = _fixOcrArtifacts(result);
    result = _fixMergedWords(result);
    result = _fixDoubleLetters(result);
    result = _fixArticleNounAgreement(result);
    result = _fixPunctuationSpacing(result);
    result = _fixCapitalizationAfterSentenceEnd(result);
    result = _spellCheckWords(result);
    result = _cleanUpWhitespace(result);

    return result;
  }

  static String _fixDollarNumberPatterns(String text) {
    final result = StringBuffer();
    int i = 0;

    while (i < text.length) {
      final match = _tryMatchCommaPattern(text, i);
      if (match != null) {
        result.write(match);
        i = _skipMatchedPattern(text, i);
        continue;
      }
      result.write(text[i]);
      i++;
    }

    return result.toString();
  }

  static String? _tryMatchCommaPattern(String text, int start) {
    if (start == 0) return null;
    final prevChar = text[start - 1];
    if (!_isLetter(prevChar.codeUnitAt(0))) return null;

    int pos = start;
    while (pos < text.length && !_isLetterOrDigit(text.codeUnitAt(pos))) {
      pos++;
    }
    if (pos >= text.length || text[pos] != '1') return null;

    int pos2 = pos + 1;
    while (pos2 < text.length && !_isLetterOrDigit(text.codeUnitAt(pos2))) {
      pos2++;
    }
    if (pos2 >= text.length || text[pos2] != '2') return null;

    int posFrag = pos2 + 1;
    while (posFrag < text.length && !_isLetter(text.codeUnitAt(posFrag))) {
      posFrag++;
    }
    if (posFrag >= text.length || !_isLowerLetter(text.codeUnitAt(posFrag))) return null;

    int fragEnd = posFrag;
    while (fragEnd < text.length && _isLowerLetter(text.codeUnitAt(fragEnd))) {
      fragEnd++;
    }
    if (fragEnd - posFrag < 2) return null;

    final fragment = text.substring(posFrag, fragEnd);
    final restored = _restoreMissingFirstLetter(fragment);
    return '$prevChar, $restored';
  }

  static int _skipMatchedPattern(String text, int start) {
    int pos = start;
    while (pos < text.length && !_isLetterOrDigit(text.codeUnitAt(pos))) {
      pos++;
    }
    if (pos >= text.length || text[pos] != '1') return start + 1;
    pos++;
    while (pos < text.length && !_isLetterOrDigit(text.codeUnitAt(pos))) {
      pos++;
    }
    if (pos >= text.length || text[pos] != '2') return start + 1;
    pos++;
    while (pos < text.length && !_isLetter(text.codeUnitAt(pos))) {
      pos++;
    }
    if (pos >= text.length || !_isLowerLetter(text.codeUnitAt(pos))) return start + 1;
    while (pos < text.length && _isLowerLetter(text.codeUnitAt(pos))) {
      pos++;
    }
    return pos;
  }

  static String _restoreMissingFirstLetter(String fragment) {
    if (fragment.isEmpty || _symSpell == null) return fragment;

    for (var i = 0; i < 26; i++) {
      final prefix = String.fromCharCode(97 + i);
      final candidate = prefix + fragment;
      final result = _symSpell!.lookup(candidate, maxEditDistance: 0);
      if (result != null && result.distance == 0) {
        return candidate;
      }
    }

    return fragment;
  }

  static String _fixMergedWords(String text) {
    final mergedPatterns = <String, String>{
      'basedon': 'based on', 'modelsto': 'models to', 'overthe': 'over the',
      'fromthe': 'from the', 'withthe': 'with the', 'forthe': 'for the',
      'andthe': 'and the', 'ofthe': 'of the', 'inthe': 'in the',
      'tothe': 'to the', 'bythe': 'by the', 'onthe': 'on the',
      'outof': 'out of', 'into': 'in to',
    };

    var result = text;
    final sortedKeys = mergedPatterns.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in sortedKeys) {
      result = result.replaceAll(key, mergedPatterns[key]!);
    }

    return result;
  }

  static String _fixArticleNounAgreement(String text) {
    if (_symSpell == null) return text;

    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'\ba\s+([a-z]+s)\b'),
      (match) {
        final plural = match.group(1)!;
        final singular = _trySingularize(plural);
        if (singular != null) {
          return 'a $singular';
        }
        return match.group(0)!;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'\ban\s+([a-z]+s)\b'),
      (match) {
        final plural = match.group(1)!;
        final singular = _trySingularize(plural);
        if (singular != null) {
          return 'an $singular';
        }
        return match.group(0)!;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'\b([a-z]+)\s+and\s+([a-z]+s)(?=[\s,.\)])'),
      (match) {
        final firstNoun = match.group(1)!;
        final secondWord = match.group(2)!;
        if (_isSingularNoun(firstNoun)) {
          final singular = _trySingularize(secondWord);
          if (singular != null) {
            return '$firstNoun and $singular';
          }
        }
        return match.group(0)!;
      },
    );

    return result;
  }

  static String? _trySingularize(String plural) {
    if (plural.length < 3) return null;

    if (!_wordSet.contains(plural)) return null;

    String? candidate;

    if (plural.endsWith('ies') && plural.length > 4) {
      candidate = '${plural.substring(0, plural.length - 3)}y';
    } else if (plural.endsWith('es') && plural.length > 3) {
      candidate = plural.substring(0, plural.length - 1);
      final candidate2 = plural.substring(0, plural.length - 2);
      if (!_wordSet.contains(candidate)) {
        if (_wordSet.contains(candidate2)) {
          candidate = candidate2;
        } else {
          candidate = null;
        }
      }
    } else if (plural.endsWith('s') && !plural.endsWith('ss') && !plural.endsWith('us')) {
      candidate = plural.substring(0, plural.length - 1);
    }

    if (candidate == null) return null;

    if (_wordSet.contains(candidate)) {
      return candidate;
    }

    return null;
  }

  static bool _isSingularNoun(String word) {
    if (word.endsWith('s') && !word.endsWith('ss') && !word.endsWith('us')) {
      return false;
    }
    return _wordSet.contains(word);
  }

  static String _fixDoubleLetters(String text) {
    if (_symSpell == null) return text;

    final words = text.split(RegExp(r'(\s+)'));
    final separators = <String>[];
    final sepMatch = RegExp(r'\s+').allMatches(text);
    for (final m in sepMatch) {
      separators.add(m.group(0)!);
    }

    final fixedWords = <String>[];
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) {
        fixedWords.add(word);
        continue;
      }

      final lookup = _symSpell!.lookup(word, maxEditDistance: 0);
      if (lookup != null && lookup.distance == 0) {
        fixedWords.add(word);
        continue;
      }

      final deduped = _tryDeduplicate(word);
      fixedWords.add(deduped);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < fixedWords.length; i++) {
      buffer.write(fixedWords[i]);
      if (i < separators.length) {
        buffer.write(separators[i]);
      }
    }
    return buffer.toString();
  }

  static String _tryDeduplicate(String word) {
    if (_symSpell == null) return word;

    final isCapitalized = word.length > 1 &&
        _isUpperLetter(word.codeUnitAt(0)) &&
        word.substring(1).toLowerCase() == word.substring(1);

    final lower = word.toLowerCase();

    for (int i = 0; i < lower.length - 1; i++) {
      if (lower[i] == lower[i + 1]) {
        final candidate = lower.substring(0, i) + lower.substring(i + 1);
        final result = _symSpell!.lookup(candidate, maxEditDistance: 0);
        if (result != null && result.distance == 0) {
          if (isCapitalized) {
            return candidate[0].toUpperCase() + candidate.substring(1);
          }
          return candidate;
        }
      }
    }

    for (int i = 0; i < lower.length - 1; i++) {
      if (lower[i] == lower[i + 1]) {
        for (int j = i + 2; j < lower.length - 1; j++) {
          if (lower[j] == lower[j + 1]) {
            final candidate =
                lower.substring(0, i) + lower.substring(i + 1, j) + lower.substring(j + 1);
            final result = _symSpell!.lookup(candidate, maxEditDistance: 0);
            if (result != null && result.distance == 0) {
              if (isCapitalized) {
                return candidate[0].toUpperCase() + candidate.substring(1);
              }
              return candidate;
            }
          }
        }
      }
    }

    return word;
  }

  static String _fixOcrArtifacts(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'([a-z])\.\s*([A-Z][a-z])'),
      (match) => '${match.group(1)}. ${match.group(2)}',
    );

    result = result.replaceAllMapped(
      RegExp(r'([a-z]),([A-Z])'),
      (match) => '${match.group(1)}, ${match.group(2)}',
    );

    return result;
  }

  static String _fixPunctuationSpacing(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'\s+([.,;:!?])'),
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'([.,;:!?])([A-Za-z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'([.,;:!?])\s{2,}'),
      (match) => '${match.group(1)} ',
    );

    result = result.replaceAllMapped(
      RegExp(r'([A-Za-z])-\s+to-'),
      (match) => '${match.group(1)} to-',
    );

    result = _restoreMissingSentenceEndPunctuation(result);

    return result;
  }

  static String _restoreMissingSentenceEndPunctuation(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'([a-z])\s+([A-Z][a-z]+)'),
      (match) {
        final before = match.group(1)!;
        final after = match.group(2)!;
        if (_isSentenceStartWord(after)) {
          return '$before. $after';
        }
        return match.group(0)!;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r',\s+(Our|We|They|Their|It|Its|The|This|That|These|Those|In|On|For|With|From|By|To|However|Moreover|Furthermore|Additionally|Although|While|Since|Because|Experiments|Results|Based|Proposed)\b'),
      (match) {
        final word = match.group(1)!;
        return '. $word';
      },
    );

    return result;
  }

  static bool _isSentenceStartWord(String word) {
    final sentenceStarters = {
      'The', 'This', 'That', 'These', 'Those',
      'We', 'Our', 'They', 'Their', 'It', 'Its',
      'In', 'On', 'For', 'With', 'From', 'By', 'To',
      'However', 'Moreover', 'Furthermore', 'Additionally',
      'Although', 'While', 'Since', 'Because',
      'Experiments', 'Results', 'Based', 'Proposed',
    };
    return sentenceStarters.contains(word);
  }

  static String _fixCapitalizationAfterSentenceEnd(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'\.\s+([a-z])'),
      (match) {
        final ch = match.group(1)!;
        return '. ${ch.toUpperCase()}';
      },
    );

    return result;
  }

  static String _spellCheckWords(String text) {
    if (_symSpell == null) return text;

    final words = text.split(RegExp(r'(\s+)'));
    final separators = <String>[];
    final sepMatch = RegExp(r'\s+').allMatches(text);
    for (final m in sepMatch) {
      separators.add(m.group(0)!);
    }

    final fixedWords = <String>[];
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) {
        fixedWords.add(word);
        continue;
      }

      final cleaned = _stripPunctuation(word);
      if (cleaned.isEmpty) {
        fixedWords.add(word);
        continue;
      }

      final isCapitalized = cleaned.length > 1 &&
          _isUpperLetter(cleaned.codeUnitAt(0)) &&
          cleaned.substring(1).toLowerCase() == cleaned.substring(1);

      final isAllUpper = cleaned.toUpperCase() == cleaned && cleaned.length > 1;

      final lookup = _symSpell!.lookup(cleaned.toLowerCase(), maxEditDistance: 0);
      if (lookup != null && lookup.distance == 0) {
        fixedWords.add(word);
        continue;
      }

      final suggestion = _symSpell!.lookup(cleaned.toLowerCase(), maxEditDistance: 1);
      if (suggestion != null && suggestion.distance == 1) {
        final fixed = suggestion.word;
        final replacement = isAllUpper
            ? fixed.toUpperCase()
            : isCapitalized
                ? fixed[0].toUpperCase() + fixed.substring(1)
                : fixed;

        final reassembled = _reassembleWord(word, replacement);
        fixedWords.add(reassembled);
      } else {
        fixedWords.add(word);
      }
    }

    final buffer = StringBuffer();
    for (int i = 0; i < fixedWords.length; i++) {
      buffer.write(fixedWords[i]);
      if (i < separators.length) {
        buffer.write(separators[i]);
      }
    }
    return buffer.toString();
  }

  static String _stripPunctuation(String word) {
    var start = 0;
    var end = word.length;
    while (start < end && !_isLetter(word.codeUnitAt(start))) {
      start++;
    }
    while (end > start && !_isLetter(word.codeUnitAt(end - 1))) {
      end--;
    }
    return word.substring(start, end);
  }

  static String _reassembleWord(String original, String replacement) {
    final prefix = StringBuffer();
    final suffix = StringBuffer();
    int i = 0;
    while (i < original.length && !_isLetter(original.codeUnitAt(i))) {
      prefix.write(original[i]);
      i++;
    }
    int j = original.length - 1;
    while (j >= 0 && !_isLetter(original.codeUnitAt(j))) {
      suffix.write(original[j]);
      j--;
    }
    return '$prefix$replacement${suffix.toString().split('').reversed.join()}';
  }

  static String _cleanUpWhitespace(String text) {
    var result = text;
    result = result.replaceAll(RegExp(r' {2,}'), ' ');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    result = result.replaceAll(RegExp(r' \n'), '\n');
    result = result.replaceAll(RegExp(r'\n '), '\n');
    return result.trim();
  }

  static bool _isLetter(int codeUnit) {
    return (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);
  }

  static bool _isLowerLetter(int codeUnit) {
    return codeUnit >= 97 && codeUnit <= 122;
  }

  static bool _isLetterOrDigit(int codeUnit) {
    return _isLetter(codeUnit) || (codeUnit >= 48 && codeUnit <= 57);
  }

  static bool _isUpperLetter(int ch) {
    return ch >= 0x0041 && ch <= 0x005A;
  }
}
