class UpdateConfig {
  static const String githubUser = 'ChaiGmzR';
  static const String repoName = 'DMS_v2';
  static const String currentVersion = '1.0.0';
  static const bool checkOnStartup = true;
  static const Duration requestTimeout = Duration(seconds: 8);

  static Uri get releasesUri =>
      Uri.https('api.github.com', '/repos/$githubUser/$repoName/releases');
}
