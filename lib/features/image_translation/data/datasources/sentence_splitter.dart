class SentenceSplitter {
  static const _abbreviations = <String>{
    'Mr', 'Mrs', 'Ms', 'Dr', 'Prof', 'Sr', 'Jr', 'St',
    'U.S', 'U.K', 'E.U', 'U.N',
    'e.g', 'i.e', 'etc', 'vs', 'cf', 'al', 'ca',
    'Fig', 'Eq', 'No', 'Vol', 'pp', 'ch', 'sec',
    'Jan', 'Feb', 'Mar', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    'Inc', 'Ltd', 'Corp', 'Co', 'Dept', 'Div',
    'Ave', 'Blvd', 'Rd', 'Ln',
  };

  static List<String> split(String text) {
    if (text.isEmpty) return [];

    final sentences = <String>[];
    final buffer = StringBuffer();
    var i = 0;
    final chars = text.runes.toList();

    while (i < chars.length) {
      buffer.writeCharCode(chars[i]);

      if (chars[i] == 0x002E && _isSentenceEnd(chars, i)) {
        var endIdx = i + 1;

        while (endIdx < chars.length && _isClosingOrQuote(chars[endIdx])) {
          buffer.writeCharCode(chars[endIdx]);
          endIdx++;
        }

        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
        i = endIdx;

        while (i < chars.length && _isWhitespace(chars[i])) {
          i++;
        }
        continue;
      }

      if (_isExclamationOrQuestion(chars[i])) {
        var endIdx = i + 1;

        while (endIdx < chars.length && _isClosingOrQuote(chars[endIdx])) {
          buffer.writeCharCode(chars[endIdx]);
          endIdx++;
        }

        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
        i = endIdx;

        while (i < chars.length && _isWhitespace(chars[i])) {
          i++;
        }
        continue;
      }

      i++;
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    return _mergeShortFragments(sentences);
  }

  static bool _isSentenceEnd(List<int> chars, int dotIdx) {
    if (dotIdx <= 0) return true;

    final beforeDot = StringBuffer();
    for (var j = dotIdx - 1; j >= 0; j--) {
      final ch = chars[j];
      if (_isLetter(ch)) {
        beforeDot.writeCharCode(ch);
      } else {
        break;
      }
    }

    final wordBefore = beforeDot.toString().toLowerCase();
    if (wordBefore.isNotEmpty && _abbreviations.contains(wordBefore)) {
      return false;
    }

    if (wordBefore.length == 1) {
      return false;
    }

    if (dotIdx + 1 < chars.length) {
      final nextCh = chars[dotIdx + 1];
      if (_isLowerLetter(nextCh)) {
        return false;
      }
    }

    return true;
  }

  static List<String> _mergeShortFragments(List<String> sentences) {
    if (sentences.isEmpty) return sentences;

    final merged = <String>[];
    var buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.isEmpty) {
        buffer.write(sentence);
      } else if (_estimateTokens(buffer.toString()) < 15 &&
          _estimateTokens('${buffer.toString()} $sentence') <= 60) {
        buffer.write(' ');
        buffer.write(sentence);
      } else {
        merged.add(buffer.toString());
        buffer = StringBuffer(sentence);
      }
    }

    if (buffer.isNotEmpty) {
      merged.add(buffer.toString());
    }

    return merged;
  }

  static int _estimateTokens(String text) {
    var count = 0;
    for (final ch in text.runes) {
      if (ch >= 0x4E00 && ch <= 0x9FFF) {
        count += 2;
      } else {
        count++;
      }
    }
    return count ~/ 4 + 1;
  }

  static bool _isExclamationOrQuestion(int ch) {
    return ch == 0x0021 || ch == 0x003F ||
        ch == 0x3002 || ch == 0xFF01 || ch == 0xFF1F;
  }

  static bool _isClosingOrQuote(int ch) {
    return ch == 0x0029 || ch == 0x005D || ch == 0x007D ||
        ch == 0x2019 || ch == 0x201D || ch == 0xFF09 ||
        ch == 0x300B || ch == 0x3011;
  }

  static bool _isWhitespace(int ch) {
    return ch == 0x0020 || ch == 0x000A || ch == 0x000D ||
        ch == 0x0009 || ch == 0x3000;
  }

  static bool _isLetter(int ch) {
    return _isLowerLetter(ch) || _isUpperLetter(ch);
  }

  static bool _isLowerLetter(int ch) {
    return ch >= 0x0061 && ch <= 0x007A;
  }

  static bool _isUpperLetter(int ch) {
    return ch >= 0x0041 && ch <= 0x005A;
  }
}
