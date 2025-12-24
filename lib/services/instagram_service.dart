// lib/utils/instagram_service.dart
import 'package:http/http.dart' as http;

/// ✅ Data Model for structured access
class InstaPost {
  final String? imageUrl;
  final String? videoUrl;
  final String? username;
  final String? caption;
  final bool isVideo;

  InstaPost({
    this.imageUrl,
    this.videoUrl,
    this.username,
    this.caption,
  }) : isVideo = videoUrl != null;
}

class InstagramService {
  // Singleton pattern
  static final InstagramService _instance = InstagramService._internal();
  factory InstagramService() => _instance;
  InstagramService._internal();

  /// Fetches public Instagram post details
  Future<InstaPost> fetchPost(String postUrl) async {
    // 1. Sanitize URL
    final Uri uri = Uri.parse(postUrl);
    final String cleanUrl = "${uri.scheme}://${uri.host}${uri.path}";

    // 2. Headers to mimic a real browser (Helps avoid 429/Redirects)
    final headers = {
      'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Upgrade-Insecure-Requests': '1',
    };

    try {
      final response = await http
          .get(Uri.parse(cleanUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception("Failed to load page: HTTP ${response.statusCode}");
      }

      return _parseHtml(response.body);

    } catch (e) {
      throw Exception("Error fetching Instagram post: $e");
    }
  }

  InstaPost _parseHtml(String html) {
    // --- Regex Patterns ---
    // Flexible regex to handle " or ' and varying spaces
    final ogImageReg = RegExp(r'<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27]([^"\x27]+)["\x27]');
    final ogVideoReg = RegExp(r'<meta\s+property=["\x27]og:video["\x27]\s+content=["\x27]([^"\x27]+)["\x27]');
    final ogDescReg  = RegExp(r'<meta\s+property=["\x27]og:description["\x27]\s+content=["\x27]([^"\x27]+)["\x27]');
    final ogTitleReg = RegExp(r'<meta\s+property=["\x27]og:title["\x27]\s+content=["\x27]([^"\x27]+)["\x27]');

    String? imageUrl = _matchValue(html, ogImageReg);
    String? videoUrl = _matchValue(html, ogVideoReg);
    String? rawTitle = _matchValue(html, ogTitleReg);
    String? rawDesc = _matchValue(html, ogDescReg);

    // Clean up data
    String? username = _extractUsername(rawTitle);
    String? caption = _cleanHtmlEntities(rawDesc);

    if (imageUrl == null && videoUrl == null) {
      throw Exception("No media found. Account might be private.");
    }

    return InstaPost(
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      username: username,
      caption: caption,
    );
  }

  String? _matchValue(String input, RegExp reg) {
    final match = reg.firstMatch(input);
    return match?.group(1);
  }

  String? _extractUsername(String? title) {
    if (title == null) return null;
    // Format usually: "Username on Instagram: 'Caption...'"
    // We explicitly requested en-US in headers, so we look for " on Instagram"
    final lower = title.toLowerCase();
    const separator = " on instagram";

    if (lower.contains(separator)) {
      // Use raw title for substring to preserve casing
      final index = lower.indexOf(separator);
      // Instagram titles often start with a strange invisible char or name
      var extracted = title.substring(0, index).trim();

      // Remove any leading ( ) or specific prefixes if meta tag structure changes
      if(extracted.startsWith("(")) extracted = extracted.replaceAll(RegExp(r'[()]'), '');

      return extracted;
    }
    return title;
  }

  String? _cleanHtmlEntities(String? input) {
    if (input == null) return null;
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}