import 'dart:collection';

class SymSpell {
  final int _maxEditDistance;
  final HashMap<String, List<String>> _deletes = HashMap<String, List<String>>();
  final Set<String> _words = {};
  final Map<String, int> _wordFrequency = {};

  SymSpell({int maxEditDistance = 2}) : _maxEditDistance = maxEditDistance;

  int get wordCount => _words.length;

  void addWord(String word, {int frequency = 1}) {
    final lower = word.toLowerCase();
    if (lower.isEmpty) return;
    _words.add(lower);
    _wordFrequency[lower] = (_wordFrequency[lower] ?? 0) + frequency;

    final deletes = _editsPrefix(lower, _maxEditDistance);
    for (final delete in deletes) {
      _deletes.putIfAbsent(delete, () => []);
      if (!_deletes[delete]!.contains(lower)) {
        _deletes[delete]!.add(lower);
      }
    }
  }

  void addWords(Map<String, int> wordFrequencies) {
    for (final entry in wordFrequencies.entries) {
      addWord(entry.key, frequency: entry.value);
    }
  }

  SuggestionResult? lookup(String input, {int maxEditDistance = 2}) {
    final lower = input.toLowerCase();
    if (lower.isEmpty) return null;

    if (_words.contains(lower)) {
      return SuggestionResult(word: lower, distance: 0, frequency: _wordFrequency[lower] ?? 1);
    }

    final effectiveDistance = maxEditDistance < _maxEditDistance ? maxEditDistance : _maxEditDistance;
    final candidates = <String, int>{};
    final queue = Queue<String>();
    queue.add(lower);

    final seen = <String>{lower};

    while (queue.isNotEmpty) {
      final candidate = queue.removeFirst();

      if (_deletes.containsKey(candidate)) {
        for (final suggestion in _deletes[candidate]!) {
          if (suggestion == lower) continue;
          if (!_words.contains(suggestion)) continue;

          final distance = _damerauLevenshtein(lower, suggestion, effectiveDistance);
          if (distance < 0) continue;

          if (!candidates.containsKey(suggestion) || distance < candidates[suggestion]!) {
            candidates[suggestion] = distance;
          }
        }
      }

      if (candidate.length > 1 && candidate.length - 1 >= lower.length - effectiveDistance) {
        for (int i = 0; i < candidate.length; i++) {
          final delete = candidate.substring(0, i) + candidate.substring(i + 1);
          if (!seen.contains(delete)) {
            seen.add(delete);
            queue.add(delete);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    final sorted = candidates.entries.toList()
      ..sort((a, b) {
        final distCmp = a.value.compareTo(b.value);
        if (distCmp != 0) return distCmp;
        return (_wordFrequency[b.key] ?? 0).compareTo(_wordFrequency[a.key] ?? 0);
      });

    final best = sorted.first;
    return SuggestionResult(
      word: best.key,
      distance: best.value,
      frequency: _wordFrequency[best.key] ?? 1,
    );
  }

  Set<String> _editsPrefix(String word, int maxDist) {
    final result = <String>{};
    if (word.isEmpty) return result;

    final maxLen = word.length > maxDist ? word.length - maxDist : 1;
    for (int len = maxLen; len <= word.length; len++) {
      _collectDeletes(word.substring(0, len), maxDist, result);
    }
    return result;
  }

  void _collectDeletes(String prefix, int remaining, Set<String> result) {
    if (remaining > 0 && prefix.length > 1) {
      for (int i = 0; i < prefix.length; i++) {
        final delete = prefix.substring(0, i) + prefix.substring(i + 1);
        result.add(delete);
        _collectDeletes(delete, remaining - 1, result);
      }
    }
  }

  int _damerauLevenshtein(String a, String b, int maxDistance) {
    if ((a.length - b.length).abs() > maxDistance) return -1;
    if (a == b) return 0;

    final aLen = a.length;
    final bLen = b.length;

    if (aLen == 0) return bLen > maxDistance ? -1 : bLen;
    if (bLen == 0) return aLen > maxDistance ? -1 : aLen;

    final matrix = List.generate(aLen + 1, (_) => List.filled(bLen + 1, 0));
    for (int i = 0; i <= aLen; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= bLen; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= aLen; i++) {
      int minRow = maxDistance + 1;
      for (int j = 1; j <= bLen; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);

        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          matrix[i][j] = [matrix[i][j], matrix[i - 2][j - 2] + cost].reduce((a, b) => a < b ? a : b);
        }

        if (matrix[i][j] < minRow) minRow = matrix[i][j];
      }
      if (minRow > maxDistance) return -1;
    }

    return matrix[aLen][bLen] > maxDistance ? -1 : matrix[aLen][bLen];
  }
}

class SuggestionResult {
  final String word;
  final int distance;
  final int frequency;

  SuggestionResult({required this.word, required this.distance, required this.frequency});

  @override
  String toString() => 'SuggestionResult(word: $word, distance: $distance, frequency: $frequency)';
}
