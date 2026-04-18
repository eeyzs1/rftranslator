import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResourceEntry {
  final String id;
  final String type;
  final String localPath;
  final String sourceLang;
  final String targetLang;
  final bool isEnabled;

  const ResourceEntry({
    required this.id,
    required this.type,
    required this.localPath,
    required this.sourceLang,
    required this.targetLang,
    this.isEnabled = false,
  });

  ResourceEntry copyWith({
    String? id,
    String? type,
    String? localPath,
    String? sourceLang,
    String? targetLang,
    bool? isEnabled,
  }) {
    return ResourceEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      localPath: localPath ?? this.localPath,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'localPath': localPath,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'isEnabled': isEnabled,
      };

  factory ResourceEntry.fromJson(Map<String, dynamic> json) => ResourceEntry(
        id: json['id'] as String,
        type: json['type'] as String,
        localPath: json['localPath'] as String,
        sourceLang: json['sourceLang'] as String,
        targetLang: json['targetLang'] as String,
        isEnabled: (json['isEnabled'] as bool?) ?? false,
      );

  bool get pathExists {
    try {
      return File(localPath).existsSync() || Directory(localPath).existsSync();
    } catch (_) {
      return false;
    }
  }
}

class ResourceRegistry {
  static const String _kRegistryKey = 'resource_registry';

  static final ResourceRegistry _instance = ResourceRegistry._();
  factory ResourceRegistry() => _instance;
  ResourceRegistry._();

  List<ResourceEntry> _entries = [];
  bool _loaded = false;

  List<ResourceEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kRegistryKey);
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List;
        _entries = list
            .map((e) => ResourceEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[ResourceRegistry] Error loading: $e');
        _entries = [];
      }
    }
    await validateAndCleanup();
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_kRegistryKey, jsonStr);
  }

  Future<void> validateAndCleanup() async {
    final valid = <ResourceEntry>[];
    bool changed = false;
    for (final entry in _entries) {
      if (entry.pathExists) {
        valid.add(entry);
      } else {
        debugPrint('[ResourceRegistry] Cleaning up invalid path: ${entry.id} -> ${entry.localPath}');
        changed = true;
      }
    }
    if (changed) {
      _entries = valid;
      await _save();
    }
  }

  ResourceEntry? getEntry(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<ResourceEntry> getByType(String type) =>
      _entries.where((e) => e.type == type).toList();

  List<ResourceEntry> getEnabledByType(String type) =>
      _entries.where((e) => e.type == type && e.isEnabled).toList();

  List<ResourceEntry> getByLangPair(
    String sourceLang,
    String targetLang, {
    String? type,
  }) {
    return _entries
        .where((e) =>
            e.sourceLang == sourceLang &&
            e.targetLang == targetLang &&
            (type == null || e.type == type))
        .toList();
  }

  ResourceEntry? getEnabledByLangPair(
    String sourceLang,
    String targetLang, {
    String? type,
  }) {
    for (final e in _entries) {
      if (e.sourceLang == sourceLang &&
          e.targetLang == targetLang &&
          (type == null || e.type == type) &&
          e.isEnabled &&
          e.pathExists) {
        return e;
      }
    }
    return null;
  }

  Future<void> addOrUpdate(ResourceEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id && e.type == entry.type);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    await _save();
  }

  Future<void> remove(String id, {String? type}) async {
    _entries = _entries
        .where((e) => !(e.id == id && (type == null || e.type == type)))
        .toList();
    await _save();
  }

  Future<void> setEnabled(String id, bool enabled, {String? type}) async {
    final idx = _entries.indexWhere((e) => e.id == id && (type == null || e.type == type));
    if (idx >= 0) {
      _entries[idx] = _entries[idx].copyWith(isEnabled: enabled);
      await _save();
    }
  }

  Future<void> updatePath(String id, String newPath, {String? type}) async {
    final idx = _entries.indexWhere((e) => e.id == id && (type == null || e.type == type));
    if (idx >= 0) {
      _entries[idx] = _entries[idx].copyWith(localPath: newPath);
      await _save();
    }
  }

  bool isRegistered(String id, {String? type}) {
    return _entries.any((e) => e.id == id && (type == null || e.type == type));
  }

  bool isEnabled(String id, {String? type}) {
    final entry = getEntry(id);
    if (entry == null) return false;
    if (type != null && entry.type != type) return false;
    return entry.isEnabled;
  }
}
