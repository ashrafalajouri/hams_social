import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.changelog,
    required this.minSupportedCode,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;
  final List<String> changelog;
  final int minSupportedCode;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> j) {
    int parseInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return AppUpdateInfo(
      versionName: (j['versionName'] ?? '') as String,
      versionCode: parseInt(j['versionCode'], 0),
      apkUrl: (j['apkUrl'] ?? '') as String,
      changelog:
          (j['changelog'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      minSupportedCode: parseInt(j['minSupportedCode'], 1),
    );
  }
}

class UpdateService {
  UpdateService({required this.versionJsonUrl});
  final String versionJsonUrl;

  Future<AppUpdateInfo?> fetchLatest() async {
    if (versionJsonUrl.trim().isEmpty) return null;
    final res = await http.get(Uri.parse(versionJsonUrl));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AppUpdateInfo.fromJson(data);
  }

  Future<PackageInfo> _pkg() => PackageInfo.fromPlatform();

  Future<bool> isUpdateAvailable(AppUpdateInfo latest) async {
    final p = await _pkg();
    final currentCode = int.tryParse(p.buildNumber) ?? 0;
    return latest.versionCode > currentCode;
  }

  Future<bool> isForceUpdate(AppUpdateInfo latest) async {
    final p = await _pkg();
    final currentCode = int.tryParse(p.buildNumber) ?? 0;
    return currentCode < latest.minSupportedCode;
  }

  Future<void> openApkUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
