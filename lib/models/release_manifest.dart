class ReleaseManifest {
  final String versionName;
  final int versionCode;
  final String? releaseNotes;
  final String apkFileName;
  final DateTime? releasedAt;

  ReleaseManifest({
    required this.versionName,
    required this.versionCode,
    this.releaseNotes,
    required this.apkFileName,
    this.releasedAt,
  });

  factory ReleaseManifest.fromJson(Map<String, dynamic> json) {
    return ReleaseManifest(
      versionName: json['versionName'] as String? ?? '',
      versionCode: json['versionCode'] is int
          ? json['versionCode'] as int
          : int.tryParse('${json['versionCode']}') ?? 0,
      releaseNotes: json['releaseNotes'] as String?,
      apkFileName: json['apkFileName'] as String? ?? '',
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'].toString())
          : null,
    );
  }
}
