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

  // ─── Fetch repo metadata ─────────────────────────────────────────────────

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

  // ─── Fetch branches ──────────────────────────────────────────────────────

  Future<List<String>> fetchBranches(String owner, String repo) async {
    final res = await http
        .get(
            Uri.parse('$_base/repos/$owner/$repo/branches?per_page=100'),
            headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (!res.statusCode.toString().startsWith('2')) return [];
    final List data = jsonDecode(res.body);
    return data.map<String>((b) => b['name'] as String).toList();
  }

  // ─── Fetch full git tree ─────────────────────────────────────────────────

  Future<({List<TreeItem> items, bool truncated})> fetchTree(
      String owner, String repo, String branch) async {
    final url =
        '$_base/repos/$owner/$repo/git/trees/$branch?recursive=1';
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

  // ─── Fetch file content (base64 decoded) ─────────────────────────────────

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
      // GitHub wraps base64 in newlines — strip before decoding
      final clean = encoded.replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(clean);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '// Unable to decode file content (likely binary).';
    }
  }

  // ─── Error helper ────────────────────────────────────────────────────────

  Exception _apiError(
      int status, Map<String, dynamic> data, String owner, String repo) {
    final msg = data['message'] ?? '';
    if (status == 401) {
      return Exception('Bad credentials — check your PAT token.');
    }
    if (status == 403) {
      if (msg.toString().toLowerCase().contains('rate limit')) {
        return Exception(
            'GitHub API rate limit hit. Add a PAT token to get 5,000 req/hr.');
      }
      return Exception(
          'Access forbidden. Repo may be private — add a PAT token.');
    }
    if (status == 404) {
      return Exception(
          'Repo "$owner/$repo" not found. Check the URL or add a PAT for private repos.');
    }
    if (status == 422) {
      return Exception(
          'Git tree unavailable — the repo may be empty or the branch invalid.');
    }
    return Exception(msg.isNotEmpty ? msg : 'GitHub API error ($status).');
  }
}
