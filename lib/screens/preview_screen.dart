import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github-dark-dimmed.dart';
import '../app_theme.dart';
import '../models/models.dart';

class PreviewScreen extends StatefulWidget {
  final TreeItem item;
  final Future<String> Function(TreeItem) fetchContent;

  const PreviewScreen({
    super.key,
    required this.item,
    required this.fetchContent,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String? _content;
  bool _loading = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content = await widget.fetchContent(widget.item);
      if (mounted) {
        setState(() {
          _content = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _content = '// Error loading file: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _copy() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  String _hlLang(String ext) {
    const map = {
      'js': 'javascript',
      'ts': 'typescript',
      'jsx': 'javascript',
      'tsx': 'typescript',
      'dart': 'dart',
      'py': 'python',
      'rb': 'ruby',
      'go': 'go',
      'rs': 'rust',
      'kt': 'kotlin',
      'java': 'java',
      'swift': 'swift',
      'c': 'c',
      'cpp': 'cpp',
      'h': 'c',
      'cs': 'csharp',
      'css': 'css',
      'scss': 'scss',
      'html': 'html',
      'xml': 'xml',
      'json': 'json',
      'yaml': 'yaml',
      'yml': 'yaml',
      'md': 'markdown',
      'sh': 'bash',
      'bash': 'bash',
      'sql': 'sql',
      'php': 'php',
      'gradle': 'groovy',
    };
    return map[ext.toLowerCase()] ?? 'plaintext';
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.item.ext;
    final color = extColor(ext);
    final isBinary = _isBinaryExt(ext);

    return Scaffold(
      backgroundColor: const Color(0xFF060910),
      body: Column(
        children: [
          // App Bar
          SafeArea(
            bottom: false,
            child: Container(
              height: 52,
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border:
                    Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textBase, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Icon(_fileIcon(ext),
                      size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.item.displayName,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.item.size > 0)
                    Text(
                      _fmtBytes(widget.item.size),
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  const SizedBox(width: 8),
                  // Copy button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? Container(
                            key: const ValueKey('copied'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.green.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded,
                                    size: 13, color: AppColors.green),
                                SizedBox(width: 4),
                                Text('Copied',
                                    style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 11)),
                              ],
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('copy'),
                            icon: const Icon(Icons.copy_rounded,
                                size: 17, color: AppColors.textDim),
                            onPressed: _content != null ? _copy : null,
                            tooltip: 'Copy',
                          ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.blue, strokeWidth: 2),
                  )
                : isBinary
                    ? _buildBinaryPlaceholder(ext, color)
                    : _buildCode(),
          ),

          // Footer: line count
          if (!_loading && _content != null && !isBinary)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border:
                    Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${_content!.split('\n').length} lines',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  Text(
                    ext.isNotEmpty ? ext.toUpperCase() : 'PLAIN',
                    style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.6),
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCode() {
    final content = _content ?? '';
    final lang = _hlLang(widget.item.ext);

    // For very long files, fall back to plain text to avoid jank
    if (content.length > 50000) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.textBase,
            height: 1.6,
          ),
        ),
      );
    }

    // Trimmed theme to avoid white background
    final theme = Map<String, TextStyle>.from(githubDarkDimmedTheme);
    theme['root'] =
        const TextStyle(backgroundColor: Color(0xFF060910));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: HighlightView(
        content,
        language: lang,
        theme: theme,
        padding: const EdgeInsets.all(14),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.65,
        ),
      ),
    );
  }

  Widget _buildBinaryPlaceholder(String ext, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(
              _fileIcon(ext),
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.item.displayName,
            style: const TextStyle(
                color: AppColors.textStrong, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            'Binary file — preview not available',
            style:
                TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtBytes(widget.item.size),
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  bool _isBinaryExt(String ext) {
    const binary = {
      'png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'bmp',
      'pdf', 'zip', 'rar', 'tar', 'gz', '7z',
      'mp3', 'mp4', 'wav', 'ogg', 'flac',
      'ttf', 'otf', 'woff', 'woff2', 'eot',
      'exe', 'dll', 'so', 'dylib', 'class',
      'apk', 'ipa', 'aab',
    };
    return binary.contains(ext.toLowerCase());
  }

  IconData _fileIcon(String ext) {
    const map = {
      'dart': Icons.flutter_dash,
      'js': Icons.javascript_rounded,
      'ts': Icons.code_rounded,
      'py': Icons.code_rounded,
      'kt': Icons.android_rounded,
      'md': Icons.article_rounded,
      'json': Icons.data_object_rounded,
      'html': Icons.html_rounded,
      'css': Icons.css_rounded,
      'xml': Icons.code_rounded,
      'yaml': Icons.settings_rounded,
      'yml': Icons.settings_rounded,
      'sh': Icons.terminal_rounded,
      'png': Icons.image_rounded,
      'jpg': Icons.image_rounded,
      'jpeg': Icons.image_rounded,
      'svg': Icons.image_rounded,
      'pdf': Icons.picture_as_pdf_rounded,
    };
    return map[ext] ?? Icons.insert_drive_file_rounded;
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '${b} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
