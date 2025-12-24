class SavedPost {
  final String localPath;
  final String username;
  final String caption;
  final String postUrl;

  SavedPost({
    required this.localPath,
    required this.username,
    required this.caption,
    required this.postUrl,
  });

  Map<String, dynamic> toJson() => {
    'localPath': localPath,
    'username': username,
    'caption': caption,
    'postUrl': postUrl,
  };

  factory SavedPost.fromJson(Map<String, dynamic> json) => SavedPost(
    localPath: json['localPath'],
    username: json['username'],
    caption: json['caption'],
    postUrl: json['postUrl'],
  );
}