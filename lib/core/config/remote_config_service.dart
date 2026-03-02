import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  FirebaseRemoteConfig? _rc;

  Future<void> initialize() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await rc.setDefaults(const {
      'auto_hide_threshold': 5,
      'limit_anon_A': 40,
      'limit_anon_B': 25,
      'limit_anon_C': 10,
      'limit_anon_D': 3,
      'discover_feed_limit': 25,
      'update_version_json_url':
          'https://raw.githubusercontent.com/ashrafalajouri/hams_social/main/version.json',
    });
    await rc.fetchAndActivate();
    _rc = rc;
  }

  int get autoHideThreshold => _rc?.getInt('auto_hide_threshold') ?? 5;
  int get discoverFeedLimit {
    final v = _rc?.getInt('discover_feed_limit') ?? 25;
    return v.clamp(10, 100);
  }

  int anonLimitByLevel(String level) {
    switch (level) {
      case 'A':
        return _rc?.getInt('limit_anon_A') ?? 40;
      case 'B':
        return _rc?.getInt('limit_anon_B') ?? 25;
      case 'C':
        return _rc?.getInt('limit_anon_C') ?? 10;
      default:
        return _rc?.getInt('limit_anon_D') ?? 3;
    }
  }

  String get versionJsonUrl => _rc?.getString('update_version_json_url') ?? '';
}
