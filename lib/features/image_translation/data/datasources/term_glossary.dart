import 'dart:convert';
import 'package:flutter/services.dart';

class TermGlossary {
  static Map<String, String> _enZhTerms = {};
  static Map<String, String> _wrongTranslations = {};
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/data/term_glossary.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final terms = json['enZhTerms'] as Map<String, dynamic>;
      _enZhTerms = terms.map((k, v) => MapEntry(k, v as String));

      final wrong = json['wrongTranslations'] as Map<String, dynamic>;
      _wrongTranslations = wrong.map((k, v) => MapEntry(k, v as String));
    } catch (e) {
      _enZhTerms = {};
      _wrongTranslations = {};
    }

    _initialized = true;
  }

  static List<TermMatch> findTermsInSource(String sourceText) {
    final lower = sourceText.toLowerCase();
    final matches = <TermMatch>[];

    for (final entry in _enZhTerms.entries) {
      final termLower = entry.key.toLowerCase();
      int start = 0;
      while (true) {
        final idx = lower.indexOf(termLower, start);
        if (idx == -1) break;
        matches.add(TermMatch(
          sourceTerm: sourceText.substring(idx, idx + entry.key.length),
          targetTerm: entry.value,
          position: idx,
          length: entry.key.length,
        ),);
        start = idx + entry.key.length;
      }
    }

    matches.sort((a, b) => b.length - a.length);

    final filtered = <TermMatch>[];
    final usedRanges = <_Range>[];

    for (final match in matches) {
      bool overlaps = false;
      for (final range in usedRanges) {
        if (match.position < range.end && match.position + match.length > range.start) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        filtered.add(match);
        usedRanges.add(_Range(match.position, match.position + match.length));
      }
    }

    return filtered;
  }

  static String postProcessTranslation(String translatedText, List<TermMatch> matchedTerms) {
    var result = translatedText;

    final sortedEntries = _wrongTranslations.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedEntries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }

    return result;
  }

  static String buildTerminologyHint(List<TermMatch> matchedTerms) {
    if (matchedTerms.isEmpty) return '';

    final seen = <String>{};
    final hints = <String>[];

    for (final match in matchedTerms) {
      final key = match.sourceTerm.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      hints.add('${match.sourceTerm} → ${match.targetTerm}');
    }

    return hints.join('; ');
  }
}

class TermMatch {
  final String sourceTerm;
  final String targetTerm;
  final int position;
  final int length;

  TermMatch({
    required this.sourceTerm,
    required this.targetTerm,
    required this.position,
    required this.length,
  });
}

class _Range {
  final int start;
  final int end;

  _Range(this.start, this.end);
}
