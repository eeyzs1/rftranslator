class OcrTextBlock {
  final String text;
  final List<Point> points;
  final double confidence;

  const OcrTextBlock({
    required this.text,
    required this.points,
    required this.confidence,
  });

  double get left => points.map((p) => p.x).reduce((a, b) => a < b ? a : b);
  double get top => points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
  double get right => points.map((p) => p.x).reduce((a, b) => a > b ? a : b);
  double get bottom => points.map((p) => p.y).reduce((a, b) => a > b ? a : b);

  double get width => right - left;
  double get height => bottom - top;
}

class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
}
