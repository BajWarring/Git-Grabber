import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class StorageService {
  static const _reposKey = 'saved_repos_v2';
  static const _activePatKey = 'active_pat_label';
  static const _patPrefix = 'pat_token_';
  static const _patListKey = 'pat_accounts_list';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Saved Repos ──────────────────────────────────────────────────────────

  Future<List<SavedRepo>> loadSavedRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_reposKey) ?? [];
    return raw
        .map((s) {
          try {
            return SavedRepo.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedRepo>()
        .toList()
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
  }

  Future<void> saveRepo(SavedRepo repo) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSavedRepos();

    // Replace if already exists
    final filtered =
        existing.where((r) => r.fullName != repo.fullName).toList();
    filtered.insert(0, repo);

    // Keep max 30 recent repos
    final trimmed = filtered.take(30).toList();
    await prefs.setStringList(
        _reposKey, trimmed.map((r) => r.toJsonString()).toList());
  }

  Future<void> removeRepo(String fullName) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSavedRepos();
    final filtered =
        existing.where((r) => r.fullName != fullName).toList();
    await prefs.setStringList(
        _reposKey, filtered.map((r) => r.toJsonString()).toList());
  }

  Future<void> clearAllRepos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reposKey);
  }

  // ─── PAT Accounts ─────────────────────────────────────────────────────────

  Future<List<PatAccount>> loadPatAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final labels = prefs.getStringList(_patListKey) ?? [];
    final accounts = <PatAccount>[];
    for (final label in labels) {
      final token = await _secure.read(key: '$_patPrefix$label');
      if (token != null && token.isNotEmpty) {
        accounts.add(PatAccount(label: label, token: token));
      }
    }
    return accounts;
  }

  Future<void> savePatAccount(String label, String token) async {
    if (label.isEmpty || token.isEmpty) return;
    await _secure.write(key: '$_patPrefix$label', value: token);
    final prefs = await SharedPreferences.getInstance();
    final labels = prefs.getStringList(_patListKey) ?? [];
    if (!labels.contains(label)) {
      labels.add(label);
      await prefs.setStringList(_patListKey, labels);
    }
  }

  Future<void> removePatAccount(String label) async {
    await _secure.delete(key: '$_patPrefix$label');
    final prefs = await SharedPreferences.getInstance();
    final labels = prefs.getStringList(_patListKey) ?? [];
    labels.remove(label);
    await prefs.setStringList(_patListKey, labels);
    // If removed was active, clear active
    final active = prefs.getString(_activePatKey);
    if (active == label) {
      await prefs.remove(_activePatKey);
    }
  }

  Future<String?> getActivePat() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString(_activePatKey);
    if (label == null) return null;
    return await _secure.read(key: '$_patPrefix$label');
  }

  Future<String?> getActivePatLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activePatKey);
  }

  Future<void> setActivePatLabel(String? label) async {
    final prefs = await SharedPreferences.getInstance();
    if (label == null) {
      await prefs.remove(_activePatKey);
    } else {
      await prefs.setString(_activePatKey, label);
    }
  }

  // ─── Legacy single-PAT migration ─────────────────────────────────────────

  Future<void> migrateLegacyPat() async {
    const legacyKey = 'github_pat';
    final legacyToken = await _secure.read(key: legacyKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await savePatAccount('Default', legacyToken);
      await setActivePatLabel('Default');
      await _secure.delete(key: legacyKey);
    }
  }
}
