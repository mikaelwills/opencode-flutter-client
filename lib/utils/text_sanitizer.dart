/// Optimized utility class for sanitizing text to prevent UTF-16 encoding errors
/// while preserving Markdown formatting when needed.
class TextSanitizer {
  // Pre-compiled regex patterns for performance
  static final RegExp _markdownControlCharsRegex = RegExp(r'[\x00-\x08\x0E-\x1F]');
  static final RegExp _plainTextControlCharsRegex = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _invalidUnicodeRegex = RegExp(r'[\uFFFE\uFFFF]');
  static final RegExp _unpairedSurrogatesRegex = RegExp(r'[\uD800-\uDFFF](?![\uDC00-\uDFFF])');
  static final RegExp _asciiOnlyRegex = RegExp(r'[^\x20-\x7E]');
  static final RegExp _problematicCharsRegex = RegExp(r'[\x00-\x08\x0B-\x1F\x7F\uFFFE\uFFFF\uD800-\uDFFF]');

  // Cache for sanitized strings to avoid re-processing
  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 200;

  /// Sanitizes text with option to preserve Markdown formatting
  static String sanitize(String text, {bool preserveMarkdown = true}) {
    // Early returns for edge cases
    if (text.isEmpty) return text;
    
    // Check cache first
    final cacheKey = '${preserveMarkdown ? 'md' : 'txt'}_${text.hashCode}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Fast path: if text doesn't contain problematic characters, return as-is
    if (!_containsProblematicChars(text)) {
      _cache[cacheKey] = text;
      return text;
    }

    String result;
    try {
      result = preserveMarkdown ? _sanitizeForMarkdown(text) : _sanitizeForPlainText(text);
    } catch (e) {
      print('⚠️ [TextSanitizer] Critical sanitization failure: $e');
      result = text; // Return original text as last resort
    }

    // Cache the result
    _cacheResult(cacheKey, result);
    return result;
  }

  /// Fast check for problematic characters
  static bool _containsProblematicChars(String text) {
    return _problematicCharsRegex.hasMatch(text);
  }

  /// Sanitizes text while preserving Markdown syntax characters
  static String _sanitizeForMarkdown(String text) {
    // Only remove characters that actually cause UTF-16 errors
    // Preserve all Markdown syntax characters (#, *, _, [, ], `, >, -, +, etc.)
    return text
        .replaceAll(_markdownControlCharsRegex, '') // Control chars (keep \t, \n, \r)
        .replaceAll(_invalidUnicodeRegex, '') // Invalid Unicode
        .replaceAll(_unpairedSurrogatesRegex, ''); // Unpaired surrogates only
  }

  /// Sanitizes text more aggressively for plain text content (tool names, etc.)
  static String _sanitizeForPlainText(String text) {
    // More aggressive cleaning for plain text (tool names, etc.)
    return text
        .replaceAll(_plainTextControlCharsRegex, '') // Control characters
        .replaceAll(_invalidUnicodeRegex, '') // Invalid Unicode
        .replaceAll(_unpairedSurrogatesRegex, ''); // Unpaired surrogates
  }

  /// Caches result with size management
  static void _cacheResult(String key, String value) {
    _cache[key] = value;
    
    // Prevent cache from growing too large
    if (_cache.length > _maxCacheSize) {
      final keys = _cache.keys.toList();
      _cache.remove(keys.first);
    }
  }

  /// Sanitizes text for streaming with optimized single-pass processing
  static String sanitizeForStreaming(String fullText, int currentIndex, {bool preserveMarkdown = true}) {
    // Early return for edge cases
    if (fullText.isEmpty || currentIndex <= 0) return '';
    if (currentIndex >= fullText.length) return sanitize(fullText, preserveMarkdown: preserveMarkdown);

    // For streaming, we need to be careful about partial UTF-16 sequences
    final substring = fullText.substring(0, currentIndex);
    
    // Check if we're in the middle of a surrogate pair
    if (currentIndex < fullText.length && _isHighSurrogate(fullText.codeUnitAt(currentIndex - 1))) {
      // Don't sanitize partial surrogate pairs
      return substring;
    }

    return sanitize(substring, preserveMarkdown: preserveMarkdown);
  }

  /// Checks if a code unit is a high surrogate
  static bool _isHighSurrogate(int codeUnit) {
    return codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
  }

  /// Fallback sanitization for critical failures (ASCII-only)
  static String sanitizeToAscii(String text) {
    if (text.isEmpty) return text;
    
    try {
      return text.replaceAll(_asciiOnlyRegex, '');
    } catch (e) {
      print('⚠️ [TextSanitizer] ASCII fallback failed: $e');
      // Ultimate fallback: filter character by character
      final buffer = StringBuffer();
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        final code = char.codeUnitAt(0);
        if (code >= 0x20 && code <= 0x7E) {
          buffer.write(char);
        }
      }
      return buffer.toString();
    }
  }

  /// Clears the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }

  /// Gets cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'hitRate': _cache.isNotEmpty ? 'Available' : 'No data',
    };
  }

  /// Validates if a string is safe for UTF-16 rendering
  static bool isValidUtf16(String text) {
    try {
      text.runes.toList();
      return true;
    } catch (e) {
      return false;
    }
  }
}