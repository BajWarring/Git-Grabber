import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';
import 'preview_screen.dart';

class RepoScreen extends StatefulWidget {
  final RepoInfo info;
  final StorageService storage;

  const RepoScreen({super.key, required this.info, required this.storage});

  @override
  State<RepoScreen> createState() => _RepoScreenState();
}

class _RepoScreenState extends State<RepoScreen> {
  List<TreeItem> _tree     = [];
  List<String>   _branches = [];
  String         _currentBranch = '';
  bool           _loading  = true;
  bool           _truncated = false;
  String         _status   = '';
  String         _errorMsg = '';

  TreeNode?           _rootNode;
  List<VisibleNode>   _visible = [];

  final Map<String, String> _contentCache = {};

  bool   _exporting      = false;
  double _exportProgress = 0;
  String _exportFile     = '';
  String _exportTitle    = '';
  bool   _exportDone     = false;
  bool   _exportIsTxt    = false;

  @override
  void initState() {
    super.initState();
    _currentBranch = widget.info.defaultBranch;
    _loadBranches();
    _loadTree(_currentBranch);
    themeModeNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  Future<void> _loadBranches() async {
    final token = await widget.storage.getActivePat();
    final svc   = GitHubService(token: token);
    final branches =
        await svc.fetchBranches(widget.info.owner, widget.info.name);
    if (mounted) setState(() => _branches = branches);
  }

  Future<void> _loadTree(String branch) async {
    setState(() {
      _loading  = true;
      _errorMsg = '';
      _status   = 'Loading $branch…';
    });

    try {
      final token = await widget.storage.getActivePat();
      final svc   = GitHubService(token: token);
      final result = await svc.fetchTree(
          widget.info.owner, widget.info.name, branch);

      _tree          = result.items;
      _truncated     = result.truncated;
      _currentBranch = branch;
      _contentCache.clear();

      _buildVirtualTree();

      final fileCount = _tree.where((i) => i.isFile).length;
      setState(() {
        _loading = false;
        _status  =
            '$fileCount files${_truncated ? ' (truncated)' : ''}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading  = false;
          _errorMsg =
              e.toString().replaceFirst('Exception: ', '');
          _status   = 'Error';
        });
      }
    }
  }

  // ─── Virtual tree ─────────────────────────────────────────────────────────

  void _buildVirtualTree() {
    final root = TreeNode(name: '', path: '', isDir: true);
    for (final item in _tree) {
      final parts = item.path.split('/');
      TreeNode cur = root;
      for (int i = 0; i < parts.length; i++) {
        final part  = parts[i];
        final isLast = i == parts.length - 1;
        if (!cur.children.containsKey(part)) {
          cur.children[part] = TreeNode(
            name:  part,
            path:  item.path,
            isDir: !isLast || item.isDir,
            item:  isLast && item.isFile ? item : null,
          );
        }
        cur = cur.children[part]!;
      }
    }
    _rootNode = root;
    _rebuildVisible();
  }

  void _rebuildVisible() {
    final list = <VisibleNode>[];
    void visit(TreeNode node, int depth) {
      final sorted = node.children.entries.toList()
        ..sort((a, b) {
          final da = a.value.isDir ? 0 : 1;
          final db = b.value.isDir ? 0 : 1;
          if (da != db) return da - db;
          return a.key.compareTo(b.key);
        });
      for (final e in sorted) {
        list.add(VisibleNode(node: e.value, depth: depth));
        if (e.value.isDir && e.value.isExpanded) visit(e.value, depth + 1);
      }
    }
    if (_rootNode != null) visit(_rootNode!, 0);
    setState(() => _visible = list);
  }

  void _toggleFolder(TreeNode node) {
    node.isExpanded = !node.isExpanded;
    _rebuildVisible();
  }

  // ─── Selection ────────────────────────────────────────────────────────────

  void _setChecked(TreeNode node, bool val) {
    if (node.item != null) _tree[node.item!.idx].checked = val;
    for (final child in node.children.values) { _setChecked(child, val); }
  }

  void _toggleAll(bool val) {
    for (final item in _tree) { item.checked = val; }
    setState(() {});
  }

  int get _selectedCount =>
      _tree.where((i) => i.isFile && i.checked).length;

  // ─── Content (cached) ─────────────────────────────────────────────────────

  Future<String> _fetchContent(TreeItem file) async {
    if (_contentCache.containsKey(file.sha)) return _contentCache[file.sha]!;
    final token   = await widget.storage.getActivePat();
    final svc     = GitHubService(token: token);
    final content = await svc.fetchFileContent(file);
    _contentCache[file.sha] = content;
    return content;
  }

  // ─── Rename dialog ────────────────────────────────────────────────────────

  /// Shows a dialog asking the user to confirm / change the export filename.
  /// Returns the final name (without extension) or `null` if cancelled.
  Future<String?> _showRenameDialog({
    required String defaultName,
    required bool isTxt,
  }) async {
    final ctrl = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isTxt
                  ? Icons.description_rounded
                  : Icons.folder_zip_rounded,
              color: isTxt ? AppColors.green : AppColors.blue,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Save as…',
              style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rename the file before saving:',
              style: TextStyle(
                  color: AppColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 13,
                  fontFamily: 'monospace'),
              decoration: InputDecoration(
                suffixText: isTxt ? '.txt' : '.zip',
                suffixStyle:
                    TextStyle(color: AppColors.textDim, fontSize: 12),
                hintText: 'filename',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.textDim)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isTxt ? AppColors.green : AppColors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Export',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Export ZIP ───────────────────────────────────────────────────────────

  Future<void> _exportZip() async {
    final selected = _tree.where((i) => i.isFile && i.checked).toList();
    if (selected.isEmpty) {
      _showSnack('No files selected. Use checkboxes to select files.');
      return;
    }

    final defaultName =
        '${widget.info.name}_$_currentBranch';
    final fileName = await _showRenameDialog(
        defaultName: defaultName, isTxt: false);
    if (fileName == null) return; // user cancelled

    _startExport(selected.length, false, fileName);

    try {
      final archive = Archive();
      for (int i = 0; i < selected.length; i++) {
        final file = selected[i];
        setState(() {
          _exportProgress = i / selected.length;
          _exportFile     = file.displayName;
        });
        final content = await _fetchContent(file);
        final bytes   = utf8.encode(content);
        archive.addFile(ArchiveFile(file.path, bytes.length, bytes));
      }

      setState(() {
        _exportProgress = 1.0;
        _exportFile     = '';
      });

      final zipData = ZipEncoder().encode(archive)!;
      final dir     = await getTemporaryDirectory();
      final outFile = File('${dir.path}/$fileName.zip');
      await outFile.writeAsBytes(zipData);

      setState(() => _exportDone = true);
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        await Share.shareXFiles(
          [XFile(outFile.path, mimeType: 'application/zip')],
          subject: '$fileName.zip',
        );
      }
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── Export TXT ───────────────────────────────────────────────────────────

  Future<void> _exportTxt() async {
    final selected = _tree.where((i) => i.isFile && i.checked).toList();
    if (selected.isEmpty) {
      _showSnack('No files selected. Use checkboxes to select files.');
      return;
    }

    final defaultName =
        '${widget.info.name}_$_currentBranch';
    final fileName = await _showRenameDialog(
        defaultName: defaultName, isTxt: true);
    if (fileName == null) return; // user cancelled

    _startExport(selected.length, true, fileName);

    try {
      const sep = '====================';
      final lines = <String>[];

      lines.add('FILE STRUCTURE');
      lines.add(sep);
      for (final f in selected) { lines.add(f.path); }
      lines.add('');
      lines.add('');

      for (int i = 0; i < selected.length; i++) {
        final file = selected[i];
        setState(() {
          _exportProgress = i / selected.length;
          _exportFile     = file.displayName;
        });
        final content = await _fetchContent(file);
        lines.add(sep);
        lines.add('FILE: ${file.path}');
        lines.add(sep);
        lines.add('');
        lines.add(content);
        lines.add('');
        lines.add('');
      }

      setState(() {
        _exportProgress = 1.0;
        _exportFile     = '';
        _exportDone     = true;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      final dir     = await getTemporaryDirectory();
      final outFile = File('${dir.path}/$fileName.txt');
      await outFile.writeAsString(lines.join('\n'));

      if (mounted) {
        await Share.shareXFiles(
          [XFile(outFile.path, mimeType: 'text/plain')],
          subject: '$fileName.txt',
        );
      }
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _startExport(int total, bool isTxt, String fileName) {
    setState(() {
      _exporting      = true;
      _exportProgress = 0;
      _exportFile     = '';
      _exportDone     = false;
      _exportIsTxt    = isTxt;
      _exportTitle    =
          '${isTxt ? 'Building' : 'Packing'} $total file${total != 1 ? 's' : ''} → $fileName${isTxt ? '.txt' : '.zip'}';
    });
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildAppBar(),
              _buildToolbar(),
              Expanded(child: _buildBody()),
              _buildBottomBar(),
            ],
          ),
          if (_exporting) _buildExportOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.textBase, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.info.name,
                      style: TextStyle(
                          color: AppColors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace')),
                  Text(widget.info.owner,
                      style: TextStyle(
                          color: AppColors.textDim, fontSize: 11)),
                ],
              ),
            ),
            if (_branches.isNotEmpty)
              _BranchChip(
                  branches: _branches,
                  current: _currentBranch,
                  onChanged: _loadTree)
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.merge_type_rounded,
                        size: 12, color: AppColors.textDim),
                    const SizedBox(width: 4),
                    Text(_currentBranch,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textDim)),
                  ],
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _loading
                  ? AppColors.yellow
                  : _errorMsg.isNotEmpty
                      ? AppColors.red
                      : AppColors.green,
            ),
          ),
          const SizedBox(width: 8),
          Text(_status,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textDim)),
          const Spacer(),
          _ToolChip(
              label: 'All',
              icon: Icons.check_box_rounded,
              onTap: () => _toggleAll(true)),
          const SizedBox(width: 6),
          _ToolChip(
              label: 'None',
              icon: Icons.check_box_outline_blank_rounded,
              onTap: () => _toggleAll(false)),
          if (_selectedCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$_selectedCount',
                  style: const TextStyle(
                      color: AppColors.blue, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_errorMsg.isNotEmpty) return _buildError();
    if (_visible.isEmpty) {
      return Center(
          child: Text('No files found',
              style: TextStyle(color: AppColors.textDim)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      itemCount: _visible.length,
      itemBuilder: (_, i) => _buildTreeRow(_visible[i]),
    );
  }

  Widget _buildTreeRow(VisibleNode vn) {
    final node  = vn.node;
    final isDir = node.isDir;
    final item  = node.item;
    final ext   = node.ext;
    final color = isDir ? AppColors.yellow : extColor(ext);

    bool? checkVal;
    if (isDir) {
      final all = _allFilesInNode(node);
      final cnt = all.where((i) => i.checked).length;
      checkVal = cnt == 0 ? false : cnt == all.length ? true : null;
    } else {
      checkVal = item?.checked ?? false;
    }

    return GestureDetector(
      onTap: () {
        if (isDir) {
          _toggleFolder(node);
        } else if (item != null) {
          _openPreview(item);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: EdgeInsets.only(
          left: 8.0 + vn.depth * 16.0,
          right: 8,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: isDir
                  ? AnimatedRotation(
                      turns: node.isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 14, color: AppColors.textDim),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                final newVal = checkVal != true;
                if (isDir) {
                  _setChecked(node, newVal);
                } else if (item != null) {
                  _tree[item.idx].checked = newVal;
                }
                setState(() {});
              },
              child: _Checkbox(value: checkVal),
            ),
            const SizedBox(width: 8),
            Icon(
              isDir
                  ? (node.isExpanded
                      ? Icons.folder_open_rounded
                      : Icons.folder_rounded)
                  : _fileIcon(ext),
              size: 15,
              color: color,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                    color: AppColors.textBase,
                    fontSize: 12.5,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isDir && ext.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Text(ext,
                    style: TextStyle(
                        fontSize: 9,
                        color: color.withValues(alpha: 0.7),
                        fontFamily: 'monospace')),
              ),
            if (!isDir && item != null && item.size > 0) ...[
              const SizedBox(width: 6),
              Text(_fmtBytes(item.size),
                  style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace')),
            ],
          ],
        ),
      ),
    );
  }

  List<TreeItem> _allFilesInNode(TreeNode node) {
    final result = <TreeItem>[];
    if (node.item != null) result.add(node.item!);
    for (final child in node.children.values) {
      result.addAll(_allFilesInNode(child));
    }
    return result;
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportZip,
                icon: const Icon(Icons.folder_zip_rounded, size: 16),
                label: Text(
                    '.zip${_selectedCount > 0 ? ' ($_selectedCount)' : ''}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textStrong,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportTxt,
                icon: const Icon(Icons.description_rounded, size: 16),
                label: Text(
                    '.txt${_selectedCount > 0 ? ' ($_selectedCount)' : ''}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textBase,
                  side: BorderSide(color: AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Export Overlay ───────────────────────────────────────────────────────

  Widget _buildExportOverlay() {
    final accentColor =
        _exportIsTxt ? AppColors.green : AppColors.blue;
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _exportDone ? 1.0 : _exportProgress,
                    color: accentColor,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    strokeWidth: 2.5,
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    _exportDone
                        ? Icons.check_rounded
                        : (_exportIsTxt
                            ? Icons.description_rounded
                            : Icons.folder_zip_rounded),
                    color:
                        _exportDone ? AppColors.green : accentColor,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _exportDone ? 'Ready!' : _exportTitle,
              style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              _exportFile.isEmpty
                  ? '${(_exportProgress * 100).toInt()}%'
                  : _exportFile,
              style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                value: _exportDone ? 1.0 : _exportProgress,
                backgroundColor:
                    Colors.white.withValues(alpha: 0.05),
                valueColor:
                    AlwaysStoppedAnimation<Color>(accentColor),
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Skeleton / Error ─────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 12,
      itemBuilder: (_, i) => Container(
        height: 32,
        margin: EdgeInsets.only(left: (i % 3) * 16.0, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.red, size: 26),
            ),
            const SizedBox(height: 16),
            Text(_errorMsg,
                style: TextStyle(
                    color: AppColors.textBase, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _loadTree(_currentBranch),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                side: BorderSide(
                    color: AppColors.blue.withValues(alpha: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _openPreview(TreeItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PreviewScreen(item: item, fetchContent: _fetchContent),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  IconData _fileIcon(String ext) {
    const map = {
      'dart': Icons.flutter_dash,       'js':   Icons.javascript_rounded,
      'ts':   Icons.code_rounded,       'py':   Icons.code_rounded,
      'kt':   Icons.android_rounded,    'md':   Icons.article_rounded,
      'json': Icons.data_object_rounded,'html': Icons.html_rounded,
      'css':  Icons.css_rounded,        'xml':  Icons.code_rounded,
      'yaml': Icons.settings_rounded,   'yml':  Icons.settings_rounded,
      'sh':   Icons.terminal_rounded,   'png':  Icons.image_rounded,
      'jpg':  Icons.image_rounded,      'jpeg': Icons.image_rounded,
      'svg':  Icons.image_rounded,      'pdf':  Icons.picture_as_pdf_rounded,
    };
    return map[ext] ?? Icons.insert_drive_file_rounded;
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ─── Branch Chip ─────────────────────────────────────────────────────────────

class _BranchChip extends StatelessWidget {
  final List<String> branches;
  final String current;
  final ValueChanged<String> onChanged;

  const _BranchChip(
      {required this.branches,
      required this.current,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _BranchSheet(
            branches: branches, current: current, onChanged: onChanged),
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type_rounded,
                size: 12, color: AppColors.textDim),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(current,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textDim),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BranchSheet extends StatelessWidget {
  final List<String> branches;
  final String current;
  final ValueChanged<String> onChanged;

  const _BranchSheet(
      {required this.branches,
      required this.current,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Switch Branch',
              style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: branches.length,
              itemBuilder: (_, i) {
                final b        = branches[i];
                final isActive = b == current;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (!isActive) onChanged(b);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.blue.withValues(alpha: 0.1)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? AppColors.blue.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.merge_type_rounded,
                            size: 14,
                            color: isActive
                                ? AppColors.blue
                                : AppColors.textDim),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(b,
                                style: TextStyle(
                                    color: isActive
                                        ? AppColors.blue
                                        : AppColors.textBase,
                                    fontSize: 13,
                                    fontFamily: 'monospace'))),
                        if (isActive)
                          const Icon(Icons.check_rounded,
                              size: 14, color: AppColors.blue),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checkbox Widget ──────────────────────────────────────────────────────────

class _Checkbox extends StatelessWidget {
  final bool? value;
  const _Checkbox({required this.value});

  @override
  Widget build(BuildContext context) {
    final isChecked = value == true;
    final isIndet   = value == null;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: isChecked
            ? AppColors.blue
            : isIndet
                ? AppColors.blue.withValues(alpha: 0.4)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (isChecked || isIndet)
              ? AppColors.blue
              : AppColors.textMuted,
          width: 1.5,
        ),
      ),
      child: isChecked
          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
          : isIndet
              ? const Icon(Icons.remove_rounded,
                  size: 11, color: Colors.white)
              : null,
    );
  }
}

// ─── Toolbar Chip ─────────────────────────────────────────────────────────────

class _ToolChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolChip(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textDim),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}
