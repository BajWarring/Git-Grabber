import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/github_service.dart';
import 'repo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<SavedRepo> _savedRepos = [];
  List<PatAccount> _patAccounts = [];
  String? _activePatLabel;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _storage.migrateLegacyPat();
    final repos = await _storage.loadSavedRepos();
    final pats = await _storage.loadPatAccounts();
    final activeLabel = await _storage.getActivePatLabel();
    setState(() {
      _savedRepos = repos;
      _patAccounts = pats;
      _activePatLabel = activeLabel;
    });
  }

  Future<void> _openRepo(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    // Parse "owner/repo" or full GitHub URL
    String owner, repo;
    final urlMatch =
        RegExp(r'github\.com/([^/\?#]+)/([^/\?#]+)').firstMatch(trimmed);
    if (urlMatch != null) {
      owner = urlMatch.group(1)!.trim();
      repo = urlMatch.group(2)!
          .replaceAll(RegExp(r'\.git$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\?#].*$'), '')
          .trim();
    } else if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      owner = parts[0].trim();
      repo = parts[1].trim();
    } else {
      _showSnack('Enter owner/repo or a full GitHub URL');
      return;
    }

    if (owner.isEmpty || repo.isEmpty) {
      _showSnack('Could not parse owner and repo from input.');
      return;
    }

    setState(() => _loading = true);
    _searchFocus.unfocus();

    try {
      final token = await _storage.getActivePat();
      final svc = GitHubService(token: token);
      final info = await svc.fetchRepo(owner, repo);

      // Save to history
      await _storage.saveRepo(info.toSavedRepo());

      if (!mounted) return;
      setState(() => _loading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RepoScreen(
            info: info,
            storage: _storage,
          ),
        ),
      );
      // Refresh history after returning
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0F3B82F6),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                const SizedBox(height: 8),
                _buildPatBar(),
                const SizedBox(height: 20),
                Expanded(child: _buildRepoList()),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.blue,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.account_tree_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GitGlance',
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Repo Explorer',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          // PAT management button
          _ChipButton(
            icon: Icons.key_rounded,
            label: _activePatLabel != null
                ? _activePatLabel!
                : 'Add Token',
            active: _activePatLabel != null,
            onTap: _showPatSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(
                color: AppColors.textStrong,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'owner/repo or GitHub URL',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textDim, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textDim, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _openRepo,
              textInputAction: TextInputAction.go,
            ),
          ),
          const SizedBox(width: 8),
          _SearchButton(
            onTap: () => _openRepo(_searchCtrl.text),
          ),
        ],
      ),
    );
  }

  Widget _buildPatBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            _activePatLabel != null
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
            size: 13,
            color: _activePatLabel != null
                ? AppColors.green
                : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            _activePatLabel != null
                ? 'Using PAT: $_activePatLabel'
                : 'No PAT — public repos only (60 req/hr)',
            style: TextStyle(
              fontSize: 11,
              color: _activePatLabel != null
                  ? AppColors.green.withValues(alpha: 0.7)
                  : AppColors.textMuted,
            ),
          ),
          const Spacer(),
          if (_activePatLabel != null)
            GestureDetector(
              onTap: () async {
                await _storage.setActivePatLabel(null);
                _load();
              },
              child: Text(
                'Deactivate',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDim,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textDim,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepoList() {
    if (_savedRepos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.account_tree_outlined,
                color: AppColors.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No repos yet',
              style: TextStyle(
                  color: AppColors.textBase,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search for a GitHub repo above to get started',
              style: TextStyle(
                  color: AppColors.textDim, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              const Text(
                'Recent Repos',
                style: TextStyle(
                  color: AppColors.textBase,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => const _ConfirmDialog(
                      title: 'Clear history?',
                      message: 'This will remove all saved repos.',
                    ),
                  );
                  if (confirm == true) {
                    await _storage.clearAllRepos();
                    _load();
                  }
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: _savedRepos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RepoCard(
              repo: _savedRepos[i],
              onTap: () {
                _searchCtrl.text = _savedRepos[i].fullName;
                _openRepo(_savedRepos[i].fullName);
              },
              onRemove: () async {
                await _storage.removeRepo(_savedRepos[i].fullName);
                _load();
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── PAT Management Sheet ────────────────────────────────────────────────

  void _showPatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PatSheet(
        accounts: _patAccounts,
        activeLabel: _activePatLabel,
        storage: _storage,
        onChanged: _load,
      ),
    );
  }
}

// ─── Repo Card ───────────────────────────────────────────────────────────────

class _RepoCard extends StatelessWidget {
  final SavedRepo repo;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RepoCard({
    required this.repo,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.source_rounded,
                color: AppColors.textDim,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repo.fullName,
                    style: const TextStyle(
                      color: AppColors.textStrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (repo.description != null &&
                      repo.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      repo.description!,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (repo.language != null) ...[
                        _Tag(
                          label: repo.language!,
                          color: extColor(repo.language!.toLowerCase()),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (repo.stars > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 10, color: AppColors.yellow),
                        const SizedBox(width: 3),
                        Text(
                          _fmtNum(repo.stars),
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Icon(Icons.access_time_rounded,
                          size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        _timeAgo(repo.lastAccessed),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 15, color: AppColors.textMuted),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).round()}mo ago';
  }
}

// ─── Tag Chip ────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
      ),
    );
  }
}

// ─── Chip Button ─────────────────────────────────────────────────────────────

class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ChipButton(
      {required this.icon,
      required this.label,
      this.active = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.blue.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.blue.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? AppColors.blue : AppColors.textDim),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppColors.blue : AppColors.textDim,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Button ────────────────────────────────────────────────────────────

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_forward_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

// ─── PAT Sheet ───────────────────────────────────────────────────────────────

class _PatSheet extends StatefulWidget {
  final List<PatAccount> accounts;
  final String? activeLabel;
  final StorageService storage;
  final VoidCallback onChanged;

  const _PatSheet({
    required this.accounts,
    required this.activeLabel,
    required this.storage,
    required this.onChanged,
  });

  @override
  State<_PatSheet> createState() => _PatSheetState();
}

class _PatSheetState extends State<_PatSheet> {
  final _labelCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _tokenVisible = false;
  List<PatAccount> _accounts = [];
  String? _activeLabel;

  @override
  void initState() {
    super.initState();
    _accounts = widget.accounts;
    _activeLabel = widget.activeLabel;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.key_rounded,
                  color: AppColors.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'PAT Tokens',
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textDim, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tokens are stored encrypted on device. Get yours at github.com/settings/tokens',
            style: TextStyle(
                color: AppColors.textDim, fontSize: 11),
          ),
          const SizedBox(height: 20),

          // Add new PAT
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _labelCtrl,
                  style: const TextStyle(
                      color: AppColors.textStrong, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Label (e.g. Work, Personal)',
                    prefixIcon: Icon(Icons.label_outline_rounded,
                        size: 16, color: AppColors.textDim),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: !_tokenVisible,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'ghp_xxxx...',
                    prefixIcon: const Icon(Icons.token_rounded,
                        size: 16, color: AppColors.textDim),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _tokenVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: AppColors.textDim,
                      ),
                      onPressed: () =>
                          setState(() => _tokenVisible = !_tokenVisible),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addPat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Save Token',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          if (_accounts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Saved Tokens',
              style: TextStyle(
                color: AppColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            ..._accounts.map((a) => _PatTile(
                  account: a,
                  isActive: a.label == _activeLabel,
                  onActivate: () async {
                    await widget.storage.setActivePatLabel(a.label);
                    setState(() => _activeLabel = a.label);
                    widget.onChanged();
                  },
                  onDelete: () async {
                    await widget.storage.removePatAccount(a.label);
                    setState(() {
                      _accounts.removeWhere((x) => x.label == a.label);
                      if (_activeLabel == a.label) _activeLabel = null;
                    });
                    widget.onChanged();
                  },
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _addPat() async {
    final label = _labelCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (label.isEmpty || token.isEmpty) return;

    await widget.storage.savePatAccount(label, token);
    await widget.storage.setActivePatLabel(label);

    final newAccount = PatAccount(label: label, token: token);
    setState(() {
      _accounts.removeWhere((a) => a.label == label);
      _accounts.insert(0, newAccount);
      _activeLabel = label;
      _labelCtrl.clear();
      _tokenCtrl.clear();
    });
    widget.onChanged();
  }
}

class _PatTile extends StatelessWidget {
  final PatAccount account;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const _PatTile({
    required this.account,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivate,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.blue.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.blue.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 16,
              color: isActive ? AppColors.blue : AppColors.textDim,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.blue
                        : AppColors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${account.token.substring(0, account.token.length.clamp(0, 12))}••••',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                      color: AppColors.blue, fontSize: 10),
                ),
              ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Confirm Dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  const _ConfirmDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textStrong, fontSize: 15)),
      content: Text(message,
          style: const TextStyle(
              color: AppColors.textDim, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear',
              style: TextStyle(color: AppColors.red)),
        ),
      ],
    );
  }
}


