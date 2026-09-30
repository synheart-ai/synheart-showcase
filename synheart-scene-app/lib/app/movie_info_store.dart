import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tmdb.dart';
import '../data/tmdb_ids.dart';
import '../domain/film.dart';

/// Artwork, synopses and trailers from TMDB for the curated catalogue.
///
/// Cached on the device so the demo still works offline (RFC §9.10): films
/// already fetched keep their posters with no network. Without a token, or
/// before anything is fetched, screens fall back to Scene's typographic
/// posters. Ranking never depends on anything in here.
class MovieInfoStore extends ChangeNotifier {
  MovieInfoStore({this.prefs, TmdbClient? client}) : client = client ?? TmdbClient(tmdbToken) {
    _load();
  }

  final SharedPreferences? prefs;
  final TmdbClient client;
  static const _key = 'scene.tmdb.v1';

  /// Film id → info, or null when TMDB has no confident match.
  final _info = <String, MovieInfo?>{};
  bool _loading = false;
  String? _error;

  bool get enabled => client.isConfigured;
  bool get loading => _loading;
  String? get error => _error;

  /// Films with TMDB data.
  int get matched => _info.values.whereType<MovieInfo>().length;

  MovieInfo? operator [](String filmId) => _info[filmId];

  void _load() {
    final raw = prefs?.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in m.entries) {
        _info[e.key] = e.value == null ? null : MovieInfo.fromJson(e.value as Map<String, dynamic>);
      }
    } catch (_) {
      // An unreadable cache is refetched.
    }
  }

  void _persist() => prefs?.setString(_key, jsonEncode({for (final e in _info.entries) e.key: e.value?.toJson()}));

  /// Fetch whatever is not cached yet. Safe to call at every start.
  Future<void> refresh(Iterable<Film> films) async {
    if (!enabled || _loading) return;
    final missing = films.where((f) => !_info.containsKey(f.id)).toList();
    if (missing.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      for (final f in missing) {
        final id = tmdbIds[f.id] ?? await client.findId(f.title, f.year);
        final info = id == null ? null : await client.details(id);
        _info[f.id] = info;
        if (info?.runtimeMinutes != null && (info!.runtimeMinutes! - f.runtimeMinutes).abs() > 5) {
          // The curated runtime drives the 90-minute filter; flag, don't overwrite.
          debugPrint('TMDB runtime for ${f.id}: ${info.runtimeMinutes} min, catalogue says ${f.runtimeMinutes}');
        }
        _persist();
        notifyListeners();
      }
    } catch (e) {
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Forget everything fetched (for a new token or a re-match).
  Future<void> clear() async {
    _info.clear();
    await prefs?.remove(_key);
    notifyListeners();
  }
}
