import 'package:rftranslator/features/image_translation/domain/entities/ocr_text_block.dart';

class OcrResult {
  final List<OcrTextBlock> blocks;
  final String fullText;
  final Duration elapsedTime;

  const OcrResult({
    required this.blocks,
    required this.fullText,
    required this.elapsedTime,
  });

  factory OcrResult.empty() {
    return const OcrResult(
      blocks: [],
      fullText: '',
      elapsedTime: Duration.zero,
    );
  }

  OcrResult copyWithFullText(String newFullText) {
    return OcrResult(
      blocks: blocks,
      fullText: newFullText,
      elapsedTime: elapsedTime,
    );
  }
}
