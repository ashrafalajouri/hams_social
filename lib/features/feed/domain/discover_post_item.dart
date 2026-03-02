class DiscoverPostItem {
  const DiscoverPostItem({
    required this.postId,
    required this.path,
    required this.authorUid,
    required this.authorUsername,
    required this.text,
    required this.replyText,
    required this.likesCount,
    required this.reportsCount,
    required this.createdAt,
    required this.authorRep,
    required this.score,
  });

  final String postId;
  final String path;
  final String authorUid;
  final String authorUsername;
  final String text;
  final String replyText;
  final int likesCount;
  final int reportsCount;
  final DateTime createdAt;
  final int authorRep;
  final double score;
}
