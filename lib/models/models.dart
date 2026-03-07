import 'dart:convert';

// ─── Saved Repo (for home screen history) ───────────────────────────────────

class SavedRepo {
  final String owner;
  final String name;
  final DateTime lastAccessed;
  final String? description;
  final String? language;
  final int stars;

  SavedRepo({
    required this.owner,
    required this.name,
    required this.lastAccessed,
    this.description,
    this.language,
    this.stars = 0,
  });

  String get fullName => '$owner/$name';

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'name': name,
        'lastAccessed': lastAccessed.toIso8601String(),
        'description': description,
        'language': language,
        'stars': stars,
      };

  factory SavedRepo.fromJson(Map<String, dynamic> json) => SavedRepo(
        owner: json['owner'] ?? '',
        name: json['name'] ?? '',
        lastAccessed: DateTime.tryParse(json['lastAccessed'] ?? '') ??
            DateTime.now(),
        description: json['description'],
        language: json['language'],
        stars: json['stars'] ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());
  factory SavedRepo.fromJsonString(String s) =>
      SavedRepo.fromJson(jsonDecode(s));
}

// ─── Repo Info (from GitHub API) ────────────────────────────────────────────

class RepoInfo {
  final String owner;
  final String name;
  final String defaultBranch;
  final String? description;
  final int stars;
  final int forks;
  final String? language;
  final bool isPrivate;

  RepoInfo({
    required this.owner,
    required this.name,
    required this.defaultBranch,
    this.description,
    this.stars = 0,
    this.forks = 0,
    this.language,
    this.isPrivate = false,
  });

  factory RepoInfo.fromJson(String owner, Map<String, dynamic> json) =>
      RepoInfo(
        owner: owner,
        name: json['name'] ?? '',
        defaultBranch: json['default_branch'] ?? 'main',
        description: json['description'],
        stars: json['stargazers_count'] ?? 0,
        forks: json['forks_count'] ?? 0,
        language: json['language'],
        isPrivate: json['private'] ?? false,
      );

  SavedRepo toSavedRepo() => SavedRepo(
        owner: owner,
        name: name,
        lastAccessed: DateTime.now(),
        description: description,
        language: language,
        stars: stars,
      );
}

// ─── Tree Item (single file/folder from GitHub tree API) ───────────────────

class TreeItem {
  final String path;
  final String type; // 'blob' or 'tree'
  final String sha;
  final String url;
  final int size;
  final int idx;
  bool checked;

  TreeItem({
    required this.path,
    required this.type,
    required this.sha,
    required this.url,
    this.size = 0,
    required this.idx,
    this.checked = false,
  });

  String get displayName => path.split('/').last;

  String get ext {
    final n = displayName;
    final dot = n.lastIndexOf('.');
    return dot > 0 ? n.substring(dot + 1).toLowerCase() : '';
  }

  bool get isFile => type == 'blob';
  bool get isDir => type == 'tree';

  factory TreeItem.fromJson(Map<String, dynamic> json, int idx) => TreeItem(
        path: json['path'] ?? '',
        type: json['type'] ?? 'blob',
        sha: json['sha'] ?? '',
        url: json['url'] ?? '',
        size: json['size'] ?? 0,
        idx: idx,
      );
}

// ─── Tree Node (virtual tree structure) ────────────────────────────────────

class TreeNode {
  final String name;
  final String path;
  final bool isDir;
  final TreeItem? item; // non-null for files
  final Map<String, TreeNode> children;
  bool isExpanded;

  TreeNode({
    required this.name,
    required this.path,
    required this.isDir,
    this.item,
    Map<String, TreeNode>? children,
    this.isExpanded = false,
  }) : children = children ?? {};

  String get ext {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }
}

// ─── Flat visible node for ListView.builder ─────────────────────────────────

class VisibleNode {
  final TreeNode node;
  final int depth;
  const VisibleNode({required this.node, required this.depth});
}

// ─── PAT Account ────────────────────────────────────────────────────────────

class PatAccount {
  final String label;
  final String token;

  const PatAccount({required this.label, required this.token});

  Map<String, dynamic> toJson() => {'label': label, 'token': token};
  factory PatAccount.fromJson(Map<String, dynamic> j) =>
      PatAccount(label: j['label'] ?? '', token: j['token'] ?? '');
}
