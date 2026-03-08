import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class GitHubService {
  static const _base = 'https://api.github.com';

  final String? token;
  GitHubService({this.token});

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github+json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'token $token',
      };

  // ─── Repo metadata ────────────────────────────────────────────────────────

  Future<RepoInfo> fetchRepo(String owner, String repo) async {
    final res = await http
        .get(Uri.parse('$_base/repos/$owner/$repo'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (!res.statusCode.toString().startsWith('2')) {
      throw _apiError(res.statusCode, data, owner, repo);
    }
    return RepoInfo.fromJson(owner, data);
  }

  // ─── Branches ─────────────────────────────────────────────────────────────

  Future<List<String>> fetchBranches(String owner, String repo) async {
    final res = await http
        .get(Uri.parse('$_base/repos/$owner/$repo/branches?per_page=100'),
            headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (!res.statusCode.toString().startsWith('2')) return [];
    final List data = jsonDecode(res.body);
    return data.map<String>((b) => b['name'] as String).toList();
  }

  // ─── Full git tree ────────────────────────────────────────────────────────

  Future<({List<TreeItem> items, bool truncated})> fetchTree(
      String owner, String repo, String branch) async {
    final url = '$_base/repos/$owner/$repo/git/trees/$branch?recursive=1';
    final res = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 30));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (!res.statusCode.toString().startsWith('2')) {
      throw _apiError(res.statusCode, data, owner, repo);
    }
    if (data['tree'] == null) {
      throw Exception(
          'GitHub returned an unexpected response. Try adding a PAT token.');
    }
    final rawTree = data['tree'] as List;
    final items = rawTree
        .asMap()
        .entries
        .map((e) => TreeItem.fromJson(e.value as Map<String, dynamic>, e.key))
        .toList();
    return (items: items, truncated: data['truncated'] == true);
  }

  // ─── File content ─────────────────────────────────────────────────────────

  Future<String> fetchFileContent(TreeItem file) async {
    final res = await http
        .get(Uri.parse(file.url), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (!res.statusCode.toString().startsWith('2')) {
      return '// Error ${res.statusCode}: could not fetch file.';
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final encoded = data['content'] as String?;
    if (encoded == null || encoded.isEmpty) {
      return '// File content unavailable (binary or empty).';
    }
    try {
      final clean = encoded.replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(clean);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '// Unable to decode file content (likely binary).';
    }
  }

  // ─── GitHub user info (for OAuth) ─────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/user'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─── Device Flow: Start ───────────────────────────────────────────────────
  //
  // Requires a GitHub OAuth App with device flow enabled.
  // The clientId here is the OAuth App's client_id — NOT a secret.
  // Users create their own at: github.com/settings/developers
  //
  static Future<DeviceFlowStart> startDeviceFlow(String clientId) async {
    final res = await http
        .post(
          Uri.parse('https://github.com/login/device/code'),
          headers: {'Accept': 'application/json'},
          body: {'client_id': clientId, 'scope': 'repo read:user'},
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Failed to start device flow (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error_description'] ?? data['error']);
    }
    return DeviceFlowStart.fromJson(data);
  }

  // ─── Device Flow: Poll for token ─────────────────────────────────────────

  /// Polls until the user authorises or the flow expires/errors.
  /// Calls [onWaiting] each poll cycle so the UI can update.
  static Future<String> pollDeviceFlow({
    required String clientId,
    required String deviceCode,
    required int intervalSeconds,
    required void Function() onWaiting,
    required bool Function() isCancelled,
  }) async {
    var interval = intervalSeconds;
    final deadline =
        DateTime.now().add(const Duration(minutes: 15));

    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled()) throw Exception('Cancelled');
      await Future.delayed(Duration(seconds: interval));
      if (isCancelled()) throw Exception('Cancelled');

      onWaiting();

      final res = await http
          .post(
            Uri.parse('https://github.com/login/oauth/access_token'),
            headers: {'Accept': 'application/json'},
            body: {
              'client_id': clientId,
              'device_code': deviceCode,
              'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) continue;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final error = data['error'] as String?;

      if (error == null) {
        final tok = data['access_token'] as String?;
        if (tok != null && tok.isNotEmpty) return tok;
      } else if (error == 'authorization_pending') {
        continue; // user hasn't authorised yet
      } else if (error == 'slow_down') {
        interval += 5; // GitHub asked us to slow down
      } else if (error == 'expired_token') {
        throw Exception('Device code expired. Please try again.');
      } else if (error == 'access_denied') {
        throw Exception('Authorisation was denied.');
      } else {
        throw Exception(data['error_description'] ?? error);
      }
    }
    throw Exception('Device flow timed out.');
  }

  // ─── Error helper ─────────────────────────────────────────────────────────

  Exception _apiError(int status, Map<String, dynamic> data,
      String owner, String repo) {
    final msg = data['message'] ?? '';
    if (status == 401) return Exception('Bad credentials — check your token.');
    if (status == 403) {
      if (msg.toString().toLowerCase().contains('rate limit')) {
        return Exception(
            'GitHub API rate limit hit. Add a token to get 5 000 req/hr.');
      }
      return Exception('Access forbidden. Repo may be private — add a token.');
    }
    if (status == 404) {
      return Exception(
          'Repo "$owner/$repo" not found. Check the URL or add a token for private repos.');
    }
    if (status == 422) {
      return Exception(
          'Git tree unavailable — the repo may be empty or the branch invalid.');
    }
    return Exception(msg.isNotEmpty ? msg : 'GitHub API error ($status).');
  }
}
