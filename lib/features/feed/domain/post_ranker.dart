class PostRanker {
  static double score({
    required int likes,
    required int reports,
    required int authorRep,
    required DateTime createdAt,
  }) {
    final hours = DateTime.now().difference(createdAt).inMinutes / 60.0;
    final timeBoost = 1.0 / (1.0 + (hours / 12.0));
    final repBoost = (authorRep.clamp(0, 120)) / 120.0;
    final likeBoost = likes.toDouble();
    final reportPenalty = reports * 2.5;

    return (likeBoost - reportPenalty) * 0.7 +
        (timeBoost * 10.0) +
        (repBoost * 2.0);
  }
}

