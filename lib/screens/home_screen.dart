import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _storage    = StorageService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<SavedRepo>  _savedRepos   = [];
  List<PatAccount> _patAccounts  = [];
  String?          _activePatLabel;
  bool             _loading      = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Rebuild whenever theme changes so AppColors getters re-evaluate
    themeModeNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeChange);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  Future<void> _load() async {
    await _storage.migrateLegacyPat();
    final repos       = await _storage.loadSavedRepos();
    final pats        = await _storage.loadPatAccounts();
    final activeLabel = await _storage.getActivePatLabel();
    if (mounted) {
      setState(() {
        _savedRepos      = repos;
        _patAccounts     = pats;
        _activePatLabel  = activeLabel;
      });
    }
  }

  Future<void> _openRepo(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    String owner, repo;
    final urlMatch =
        RegExp(r'github\.com/([^/\?#]+)/([^/\?#]+)').firstMatch(trimmed);
    if (urlMatch != null) {
      owner = urlMatch.group(1)!.trim();
      repo  = urlMatch.group(2)!
          .replaceAll(RegExp(r'\.git$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\?#].*$'), '')
          .trim();
    } else if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      owner = parts[0].trim();
      repo  = parts[1].trim();
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
      final svc   = GitHubService(token: token);
      final info  = await svc.fetchRepo(owner, repo);
      await _storage.saveRepo(info.toSavedRepo());

      if (!mounted) return;
      setState(() => _loading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RepoScreen(info: info, storage: _storage),
        ),
      );
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
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
                    color: AppColors.blue, strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Git Grabber',
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Repo Explorer',
                style: TextStyle(color: AppColors.textDim, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),

          // ── Theme toggle ──
          GestureDetector(
            onTap: () {
              themeModeNotifier.value = isDark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 16,
                color: isDark ? AppColors.yellow : AppColors.textBase,
              ),
            ),
          ),

          // ── Token button ──
          _ChipButton(
            icon: Icons.key_rounded,
            label: _activePatLabel ?? 'Add Token',
            active: _activePatLabel != null,
            onTap: _showPatSheet,
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 14,
                  fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'owner/repo or GitHub URL',
                prefixIcon: Icon(Icons.search,
                    color: AppColors.textDim, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: AppColors.textDim, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _openRepo,
              textInputAction: TextInputAction.go,
            ),
          ),
          const SizedBox(width: 8),
          _SearchButton(onTap: () => _openRepo(_searchCtrl.text)),
        ],
      ),
    );
  }

  // ─── PAT status bar ───────────────────────────────────────────────────────

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
                ? 'Using token: $_activePatLabel'
                : 'No token — public repos only (60 req/hr)',
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
                style: TextStyle(
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

  // ─── Recent repos list ────────────────────────────────────────────────────

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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.account_tree_outlined,
                  color: AppColors.textMuted, size: 32),
            ),
            const SizedBox(height: 16),
            Text('No repos yet',
                style: TextStyle(
                    color: AppColors.textBase,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Search for a GitHub repo above to get started',
                style:
                    TextStyle(color: AppColors.textDim, fontSize: 13),
                textAlign: TextAlign.center),
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
              Text('Recent Repos',
                  style: TextStyle(
                      color: AppColors.textBase,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => _ConfirmDialog(
                      title: 'Clear history?',
                      message: 'This will remove all saved repos.',
                    ),
                  );
                  if (confirm == true) {
                    await _storage.clearAllRepos();
                    _load();
                  }
                },
                child: Text('Clear all',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
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

  // ─── PAT / OAuth sheet ────────────────────────────────────────────────────

  void _showPatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthSheet(
        accounts: _patAccounts,
        activeLabel: _activePatLabel,
        storage: _storage,
        onChanged: _load,
      ),
    );
  }
}

// ─── Repo Card ────────────────────────────────────────────────────────────────

class _RepoCard extends StatelessWidget {
  final SavedRepo repo;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RepoCard(
      {required this.repo, required this.onTap, required this.onRemove});

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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.source_rounded,
                  color: AppColors.textDim, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(repo.fullName,
                      style: TextStyle(
                          color: AppColors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace')),
                  if (repo.description != null &&
                      repo.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(repo.description!,
                        style: TextStyle(
                            color: AppColors.textDim, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    if (repo.language != null) ...[
                      _Tag(
                          label: repo.language!,
                          color: extColor(repo.language!.toLowerCase())),
                      const SizedBox(width: 6),
                    ],
                    if (repo.stars > 0) ...[
                      const Icon(Icons.star_rounded,
                          size: 10, color: AppColors.yellow),
                      const SizedBox(width: 3),
                      Text(_fmtNum(repo.stars),
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 10)),
                      const SizedBox(width: 6),
                    ],
                    Icon(Icons.access_time_rounded,
                        size: 10, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(_timeAgo(repo.lastAccessed),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded,
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

// ─── Tag Chip ─────────────────────────────────────────────────────────────────

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
      child: Text(label,
          style:
              TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8))),
    );
  }
}

// ─── Chip Button ──────────────────────────────────────────────────────────────

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
              : AppColors.card,
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

// ─── Auth Sheet (PAT + GitHub OAuth) ─────────────────────────────────────────

class _AuthSheet extends StatefulWidget {
  final List<PatAccount> accounts;
  final String? activeLabel;
  final StorageService storage;
  final VoidCallback onChanged;

  const _AuthSheet({
    required this.accounts,
    required this.activeLabel,
    required this.storage,
    required this.onChanged,
  });

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // PAT tab
  final _labelCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _tokenVisible = false;

  // OAuth tab
  final _clientIdCtrl = TextEditingController();
  bool _oauthLoading = false;
  bool _oauthCancelled = false;
  String? _oauthUserCode;
  String? _oauthVerificationUri;
  String _oauthStatus = '';

  List<PatAccount> _accounts = [];
  String? _activeLabel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _accounts    = widget.accounts;
    _activeLabel = widget.activeLabel;
    _loadClientId();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _labelCtrl.dispose();
    _tokenCtrl.dispose();
    _clientIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClientId() async {
    final id = await widget.storage.getOAuthClientId();
    if (id != null && mounted) setState(() => _clientIdCtrl.text = id);
  }

  // ── PAT save ────────────────────────────────────────────────────────────

  Future<void> _addPat() async {
    final label = _labelCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (label.isEmpty || token.isEmpty) return;

    await widget.storage.savePatAccount(label, token);
    await widget.storage.setActivePatLabel(label);

    setState(() {
      _accounts.removeWhere((a) => a.label == label);
      _accounts.insert(0, PatAccount(label: label, token: token));
      _activeLabel = label;
      _labelCtrl.clear();
      _tokenCtrl.clear();
    });
    widget.onChanged();
  }

  // ── GitHub OAuth Device Flow ─────────────────────────────────────────────

  Future<void> _startOAuth() async {
    final clientId = _clientIdCtrl.text.trim();
    if (clientId.isEmpty) {
      setState(() => _oauthStatus = 'Enter your GitHub OAuth App Client ID first.');
      return;
    }

    await widget.storage.saveOAuthClientId(clientId);

    setState(() {
      _oauthLoading   = true;
      _oauthCancelled = false;
      _oauthStatus    = 'Requesting device code…';
      _oauthUserCode  = null;
    });

    try {
      final flow = await GitHubService.startDeviceFlow(clientId);
      if (!mounted) return;

      setState(() {
        _oauthUserCode       = flow.userCode;
        _oauthVerificationUri = flow.verificationUri;
        _oauthStatus         =
            'Enter the code below at the page that will open in your browser.';
      });

      // Open browser
      await launchUrl(
        Uri.parse(flow.verificationUri),
        mode: LaunchMode.externalApplication,
      );

      // Poll for token
      final token = await GitHubService.pollDeviceFlow(
        clientId: clientId,
        deviceCode: flow.deviceCode,
        intervalSeconds: flow.interval,
        onWaiting: () {
          if (mounted) setState(() => _oauthStatus = 'Waiting for authorisation…');
        },
        isCancelled: () => _oauthCancelled || !mounted,
      );

      if (!mounted) return;

      // Fetch username to use as label
      final svc  = GitHubService(token: token);
      final user = await svc.fetchCurrentUser();
      final label = user?['login'] as String? ?? 'GitHub Account';

      await widget.storage.savePatAccount(label, token);
      await widget.storage.setActivePatLabel(label);

      setState(() {
        _accounts.removeWhere((a) => a.label == label);
        _accounts.insert(0, PatAccount(label: label, token: token));
        _activeLabel    = label;
        _oauthLoading   = false;
        _oauthUserCode  = null;
        _oauthStatus    = 'Signed in as $label ✓';
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _oauthLoading  = false;
        _oauthUserCode = null;
        _oauthStatus   = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _cancelOAuth() {
    setState(() {
      _oauthCancelled = true;
      _oauthLoading   = false;
      _oauthUserCode  = null;
      _oauthStatus    = 'Cancelled.';
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row
          Row(
            children: [
              const Icon(Icons.key_rounded,
                  color: AppColors.blue, size: 16),
              const SizedBox(width: 8),
              Text('Authentication',
                  style: TextStyle(
                      color: AppColors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded,
                    color: AppColors.textDim, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.textDim,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.3)),
              ),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'PAT Token'),
                Tab(text: 'GitHub Login'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab content
          SizedBox(
            // Keep sheet height sensible
            height: _oauthLoading ? 300 : null,
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildPatTab(),
                _buildOAuthTab(),
              ],
            ),
          ),

          // Saved tokens (both tabs share this)
          if (_accounts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Saved Tokens',
                style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: _accounts
                    .map((a) => _PatTile(
                          account: a,
                          isActive: a.label == _activeLabel,
                          onActivate: () async {
                            await widget.storage
                                .setActivePatLabel(a.label);
                            setState(() => _activeLabel = a.label);
                            widget.onChanged();
                          },
                          onDelete: () async {
                            await widget.storage
                                .removePatAccount(a.label);
                            setState(() {
                              _accounts.removeWhere(
                                  (x) => x.label == a.label);
                              if (_activeLabel == a.label) {
                                _activeLabel = null;
                              }
                            });
                            widget.onChanged();
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── PAT Tab ──────────────────────────────────────────────────────────────

  Widget _buildPatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tokens are stored encrypted on device.\nCreate yours at github.com/settings/tokens',
          style: TextStyle(color: AppColors.textDim, fontSize: 11),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _labelCtrl,
                style: TextStyle(
                    color: AppColors.textStrong, fontSize: 13),
                decoration: InputDecoration(
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
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'ghp_xxxx…',
                  prefixIcon: Icon(Icons.token_rounded,
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
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── OAuth Tab ────────────────────────────────────────────────────────────

  Widget _buildOAuthTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign in with your GitHub account via OAuth Device Flow.\nRequires a GitHub OAuth App — create one at github.com/settings/developers',
          style: TextStyle(color: AppColors.textDim, fontSize: 11),
        ),
        const SizedBox(height: 14),

        // Client ID field
        TextField(
          controller: _clientIdCtrl,
          style: TextStyle(color: AppColors.textStrong, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'OAuth App Client ID',
            prefixIcon: Icon(Icons.apps_rounded,
                size: 16, color: AppColors.textDim),
            isDense: true,
          ),
          enabled: !_oauthLoading,
        ),
        const SizedBox(height: 12),

        // Status / code display
        if (_oauthUserCode != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text('Enter this code in your browser:',
                    style: TextStyle(
                        color: AppColors.textDim, fontSize: 11)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _oauthUserCode!,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _oauthUserCode!));
                      },
                      child: Icon(Icons.copy_rounded,
                          size: 16, color: AppColors.textDim),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                        _oauthVerificationUri ?? 'https://github.com/login/device'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    _oauthVerificationUri ?? 'github.com/login/device',
                    style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (_oauthStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                if (_oauthLoading) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        color: AppColors.blue,
                        strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _oauthStatus,
                    style: TextStyle(
                        color: _oauthStatus.endsWith('✓')
                            ? AppColors.green
                            : AppColors.textDim,
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _oauthLoading ? null : _startOAuth,
                icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                label: Text(
                    _oauthLoading ? 'Waiting…' : 'Sign in with GitHub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF238636).withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            if (_oauthLoading) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _cancelOAuth,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── PAT Tile ─────────────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.blue.withValues(alpha: 0.1)
              : AppColors.surface,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.label,
                      style: TextStyle(
                          color: isActive
                              ? AppColors.blue
                              : AppColors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(
                    '${account.token.substring(0, account.token.length.clamp(0, 12))}••••',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Active',
                    style: TextStyle(
                        color: AppColors.blue, fontSize: 10)),
              ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded,
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style:
              TextStyle(color: AppColors.textStrong, fontSize: 15)),
      content: Text(message,
          style: TextStyle(color: AppColors.textDim, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              Text('Cancel', style: TextStyle(color: AppColors.textDim)),
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
