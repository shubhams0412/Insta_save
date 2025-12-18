// lib/utils/instagram_service.dart

import 'package:http/http.dart' as http;

/// Optional: helper to clean basic HTML characters
class HtmlUnescape {
  String convert(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'");
  }
}

/// ✅ Main function that fetches public Instagram post details without API key
Future<Map<String, String?>> fetchInstagramPostData(String postUrl) async {
  // Remove ? stuff after URL
  String url = postUrl.split('?')[0];
  if (!url.endsWith('/')) url = '$url/';

  // Fake browser
  final headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  final response = await http.get(Uri.parse(url), headers: headers);

  if (response.statusCode != 200) {
    throw Exception("HTTP error: ${response.statusCode}");
  }

  final html = response.body;

  String? imageUrl;
  String? videoUrl;
  String? username;
  String? caption;

  // --- STEP 1: og:meta extraction ---
  final ogImage = RegExp(r'<meta property="og:image" content="([^"]+)"');
  final ogVideo = RegExp(r'<meta property="og:video" content="([^"]+)"');
  final ogDesc = RegExp(r'<meta property="og:description" content="([^"]+)"');
  final ogTitle = RegExp(r'<meta property="og:title" content="([^"]+)"');

  imageUrl = _matchValue(html, ogImage);
  videoUrl = _matchValue(html, ogVideo);
  caption = HtmlUnescape().convert(_matchValue(html, ogDesc) ?? '');
  username = _extractUsernameFromTitle(_matchValue(html, ogTitle));

  if (imageUrl == null && videoUrl == null) {
    throw Exception("No media found or profile is private.");
  }

  return {
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
    'username': username,
    'caption': caption,
  };
}

/// Helper to match regex safely
String? _matchValue(String input, RegExp reg) {
  final match = reg.firstMatch(input);
  return match != null ? match.group(1) : null;
}

/// Extracts username from title (example: "username on Instagram: “post”")
String? _extractUsernameFromTitle(String? title) {
  if (title == null) return null;
  final lower = title.toLowerCase();
  if (lower.contains(" on instagram")) {
    return title.substring(0, lower.indexOf(" on instagram")).trim();
  }
  return title;
}
