/// Utility class for sanitizing text to prevent UTF-16 encoding errors
/// while preserving Markdown formatting when needed.
class TextSanitizer {
  /// Sanitizes text with option to preserve Markdown formatting
  static String sanitize(String text, {bool preserveMarkdown = true}) {
    if (preserveMarkdown) {
      return sanitizeForMarkdown(text);
    } else {
      return sanitizeForPlainText(text);
    }
  }

  /// Sanitizes text while preserving Markdown syntax characters
  static String sanitizeForMarkdown(String text) {
    try {
      // Only remove characters that actually cause UTF-16 errors
      // Preserve all Markdown syntax characters (#, *, _, [, ], `, >, -, +, etc.)
      String cleaned = text
          .replaceAll(RegExp(r'[\x00-\x08\x0E-\x1F]'), '') // Control chars (keep \t, \n, \r)
          .replaceAll(RegExp(r'[\uFFFE\uFFFF]'), '') // Invalid Unicode
          .replaceAll(RegExp(r'[\uD800-\uDFFF](?![\uDC00-\uDFFF])'), ''); // Unpaired surrogates only
      
      // Test if the string is valid UTF-16
      cleaned.runes.toList(); // This will throw if invalid
      return cleaned;
    } catch (e) {
      print('⚠️ [TextSanitizer] Markdown sanitization failed: $e');
      return sanitizeForPlainText(text);
    }
  }

  /// Sanitizes text more aggressively for plain text content (tool names, etc.)
  static String sanitizeForPlainText(String text) {
    try {
      // More aggressive cleaning for plain text (tool names, etc.)
      String sanitized = text
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Control characters
          .replaceAll(RegExp(r'[\uFFFE\uFFFF]'), '') // Invalid Unicode
          .replaceAll(RegExp(r'[\uD800-\uDFFF]'), ''); // Unpaired surrogates
      
      final runes = sanitized.runes.toList();
      return String.fromCharCodes(runes);
    } catch (e) {
      print('⚠️ [TextSanitizer] Plain text sanitization failed: $e');
      return text.replaceAll(RegExp(r'[^\x20-\x7E]'), ''); // ASCII only fallback
    }
  }
}