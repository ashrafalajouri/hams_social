import '../../../core/config/remote_config_service.dart';

class TrustPolicy {
  static String levelFromScore(int score) {
    if (score >= 80) return 'A';
    if (score >= 50) return 'B';
    if (score >= 20) return 'C';
    return 'D';
  }

  static int anonLimitPerDay(int score) {
    final level = levelFromScore(score);
    return RemoteConfigService.instance.anonLimitByLevel(level);
  }

  static int postLimitPerDay(int score) {
    final level = levelFromScore(score);
    switch (level) {
      case 'A':
        return 20;
      case 'B':
        return 12;
      case 'C':
        return 6;
      default:
        return 2;
    }
  }
}
