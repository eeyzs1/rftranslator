import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class OcrPostprocessor {
  static List<String> _characterList = [];
  static Set<int> _skipIndices = {};
  static bool _initialized = false;

  static List<String> get characterList {
    if (!_initialized) return _getDefaultCharacters();
    return _characterList;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final content = await rootBundle.loadString('assets/models/ocr/ppocrv5_dict.txt');
      final rawChars = content
          .split(RegExp(r'\r?\n'))
          .where((line) => line.isNotEmpty)
          .toList();
      _characterList = ['blank', ...rawChars, ' '];
      _buildSkipIndices();
    } catch (e) {
      try {
        final content = await rootBundle.loadString('assets/models/ocr/ppocr_keys_v1.txt');
        final rawChars = content
            .split(RegExp(r'\r?\n'))
            .where((line) => line.isNotEmpty)
            .toList();
        _characterList = ['blank', ...rawChars, ' '];
        _buildSkipIndices();
      } catch (e2) {
        _characterList = _getDefaultCharacters();
        _buildSkipIndices();
      }
    }

    _initialized = true;
  }

  static void _buildSkipIndices() {
    _skipIndices = {};
    const skipChars = {'\$'};
    for (int i = 0; i < _characterList.length; i++) {
      if (skipChars.contains(_characterList[i])) {
        _skipIndices.add(i);
      }
    }
  }

  static List<String> _getDefaultCharacters() {
    return [
      'blank',
      "'", '疗', '绚', '诚', '娇', '溜', '题', '贿', '者', '廖',
      '更', '纳', '加', '奉', '公', '一', '就', '汴', '计', '与',
      '路', '房', '原', '妇', '2', '0', '8', '-', '7', '其',
      '>', ':', ']', ',', '，', '骑', '刈', '全', '消', '昏',
    ];
  }

  static String ctcDecode(List<int> indices, {List<String>? chars, bool mergeRepeated = true}) {
    final charList = chars ?? (_initialized ? _characterList : _getDefaultCharacters());
    final skipIdx = _initialized ? _skipIndices : <int>{};

    final result = <String>[];
    const blankIdx = 0;

    for (int i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (idx == blankIdx) continue;
      if (skipIdx.contains(idx)) continue;
      if (mergeRepeated && i > 0 && indices[i] == indices[i - 1]) {
        continue;
      }
      if (idx >= 0 && idx < charList.length) {
        result.add(charList[idx]);
      }
    }

    return result.join();
  }

  static List<int> argmax2D(List<double> data, int width, int height) {
    final result = <int>[];
    for (int t = 0; t < height; t++) {
      double maxVal = double.negativeInfinity;
      int maxIdx = 0;
      for (int c = 0; c < width; c++) {
        final val = data[t * width + c];
        if (val > maxVal) {
          maxVal = val;
          maxIdx = c;
        }
      }
      result.add(maxIdx);
    }
    return result;
  }

  static List<List<double>> dbPostprocess({
    required List<double> probabilityMap,
    required int width,
    required int height,
    required int originalWidth,
    required int originalHeight,
    required int resizedWidth,
    required int resizedHeight,
    double thresh = 0.3,
    double boxThresh = 0.5,
    double unclipRatio = 1.2,
    int maxCandidates = 1000,
    int minSize = 3,
    bool useDilation = true,
  }) {
    final boxes = <_Box>[];

    try {
      final binary = List.generate(
        height,
        (y) => List.generate(
          width,
          (x) => probabilityMap[y * width + x] > thresh,
        ),
      );

      if (useDilation) {
        final dilated = List.generate(
          height,
          (y) => List.generate(width, (x) => binary[y][x]),
        );
        for (var y = 0; y < height - 1; y++) {
          for (var x = 0; x < width - 1; x++) {
            if (binary[y][x] ||
                binary[y][x + 1] ||
                binary[y + 1][x] ||
                binary[y + 1][x + 1]) {
              dilated[y][x] = true;
              if (x + 1 < width) dilated[y][x + 1] = true;
              if (y + 1 < height) dilated[y + 1][x] = true;
              if (x + 1 < width && y + 1 < height) dilated[y + 1][x + 1] = true;
            }
          }
        }
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            binary[y][x] = dilated[y][x];
          }
        }
      }

      final regions = _findRegionsFromBinary(binary, probabilityMap, width, height);

      for (final region in regions) {
        if (region.count < 4) continue;

        final score = region.totalProb / region.count;
        if (score < boxThresh) continue;

        var x1 = region.minX.toDouble();
        var y1 = region.minY.toDouble();
        var x2 = region.maxX.toDouble();
        var y2 = region.maxY.toDouble();

        if (unclipRatio > 1.0) {
          final bw = x2 - x1;
          final bh = y2 - y1;
          final padX = bw * (unclipRatio - 1.0) / 2.0;
          final padY = bh * (unclipRatio - 1.0) / 2.0;
          x1 = (x1 - padX).clamp(0.0, width.toDouble());
          y1 = (y1 - padY).clamp(0.0, height.toDouble());
          x2 = (x2 + padX).clamp(0.0, width.toDouble());
          y2 = (y2 + padY).clamp(0.0, height.toDouble());
        }

        final origX1 = (x1 / width * originalWidth).round().clamp(0, originalWidth);
        final origY1 = (y1 / height * originalHeight).round().clamp(0, originalHeight);
        final origX2 = (x2 / width * originalWidth).round().clamp(0, originalWidth);
        final origY2 = (y2 / height * originalHeight).round().clamp(0, originalHeight);

        final bw = origX2 - origX1;
        final bh = origY2 - origY1;
        if (bw < minSize || bh < minSize) continue;

        boxes.add(_Box(
          x1: origX1.toDouble(),
          y1: origY1.toDouble(),
          x2: origX2.toDouble(),
          y2: origY2.toDouble(),
          score: score,
        ),);
      }

      final merged = _mergeBoxes(boxes);

      final sorted = _sortByReadingOrder(merged);

      return sorted
          .take(maxCandidates)
          .map((b) => [b.x1, b.y1, b.x2, b.y2])
          .toList();
    } catch (e) {
      debugPrint('[OcrPostprocessor] DB postprocess error: $e');
      return boxes.map((b) => [b.x1, b.y1, b.x2, b.y2]).toList();
    }
  }

  static List<_Box> _mergeBoxes(List<_Box> boxes) {
    if (boxes.isEmpty) return boxes;

    boxes.sort((a, b) => a.y1.compareTo(b.y1));

    final merged = <_Box>[];
    final used = List.filled(boxes.length, false);

    for (var i = 0; i < boxes.length; i++) {
      if (used[i]) continue;

      var bx1 = boxes[i].x1;
      var by1 = boxes[i].y1;
      var bx2 = boxes[i].x2;
      var by2 = boxes[i].y2;
      var bs = boxes[i].score;
      used[i] = true;

      var changed = true;
      while (changed) {
        changed = false;
        for (var j = 0; j < boxes.length; j++) {
          if (used[j]) continue;

          final ax1 = boxes[j].x1;
          final ay1 = boxes[j].y1;
          final ax2 = boxes[j].x2;
          final ay2 = boxes[j].y2;

          final currCenterY = (by1 + by2) / 2;
          final candCenterY = (ay1 + ay2) / 2;
          final currH = by2 - by1;
          final candH = ay2 - ay1;
          final avgH = (currH + candH) / 2;

          final yOverlap = (currCenterY - candCenterY).abs() < avgH * 0.6;
          if (!yOverlap) continue;

          final gapX = (ax1 > bx2)
              ? ax1 - bx2
              : (bx1 > ax2)
                  ? bx1 - ax2
                  : 0.0;

          final charWidth = avgH * 0.6;
          if (gapX < charWidth * 3) {
            bx1 = bx1 < ax1 ? bx1 : ax1;
            by1 = by1 < ay1 ? by1 : ay1;
            bx2 = bx2 > ax2 ? bx2 : ax2;
            by2 = by2 > ay2 ? by2 : ay2;
            bs = bs > boxes[j].score ? bs : boxes[j].score;
            used[j] = true;
            changed = true;
          }
        }
      }

      merged.add(_Box(x1: bx1, y1: by1, x2: bx2, y2: by2, score: bs));
    }

    return merged;
  }

  static List<_Box> _sortByReadingOrder(List<_Box> boxes) {
    if (boxes.length <= 1) return boxes;

    final sorted = List<_Box>.from(boxes);
    sorted.sort((a, b) {
      final aCenterY = (a.y1 + a.y2) / 2;
      final bCenterY = (b.y1 + b.y2) / 2;
      final avgH = ((a.y2 - a.y1) + (b.y2 - b.y1)) / 2;
      if ((aCenterY - bCenterY).abs() > avgH * 0.5) {
        return aCenterY.compareTo(bCenterY);
      }
      return a.x1.compareTo(b.x1);
    });

    return sorted;
  }

  static List<_Region> _findRegionsFromBinary(
    List<List<bool>> binary,
    List<double> probabilityMap,
    int width,
    int height,
  ) {
    final visited = List.generate(
      height,
      (y) => List.generate(width, (x) => false),
    );

    final regions = <_Region>[];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!binary[y][x] || visited[y][x]) continue;

        int minX = x, maxX = x, minY = y, maxY = y;
        int count = 0;
        double totalProb = 0.0;
        final stack = <List<int>>[[x, y]];
        visited[y][x] = true;

        while (stack.isNotEmpty) {
          final p = stack.removeLast();
          count++;
          totalProb += probabilityMap[p[1] * width + p[0]];
          if (p[0] < minX) minX = p[0];
          if (p[0] > maxX) maxX = p[0];
          if (p[1] < minY) minY = p[1];
          if (p[1] > maxY) maxY = p[1];

          final dirs = [
            [0, -1], [0, 1], [-1, 0], [1, 0],
            [-1, -1], [-1, 1], [1, -1], [1, 1],
          ];
          for (final d in dirs) {
            final nx = p[0] + d[0];
            final ny = p[1] + d[1];
            if (nx >= 0 && nx < width && ny >= 0 && ny < height &&
                binary[ny][nx] && !visited[ny][nx]) {
              visited[ny][nx] = true;
              stack.add([nx, ny]);
            }
          }
        }

        regions.add(_Region(
          minX: minX,
          minY: minY,
          maxX: maxX,
          maxY: maxY,
          count: count,
          totalProb: totalProb,
        ),);
      }
    }

    return regions;
  }

  static int classifyOrientation(List<double> output, {double thresh = 0.9}) {
    if (output.length < 2) return 0;

    final score0 = output[0];
    final score180 = output[1];

    if (score180 > thresh && score180 > score0) {
      return 180;
    }

    return 0;
  }

  static img.Image rotate180(img.Image image) {
    return img.copyRotate(image, angle: 180);
  }
}

class _Region {
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final int count;
  final double totalProb;

  _Region({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.count,
    required this.totalProb,
  });
}

class _Box {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;

  _Box({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
  });
}
