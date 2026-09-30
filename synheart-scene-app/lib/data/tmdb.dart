import 'dart:convert';

import 'package:http/http.dart' as http;

/// TMDB credentials, passed at build time and never committed:
/// `flutter run --dart-define-from-file=tmdb.json` with
/// `{"TMDB_TOKEN": "<v4 read access token or v3 API key>"}`.
const tmdbToken = String.fromEnvironment('TMDB_TOKEN');

/// The attribution TMDB's terms require wherever its data is shown.
const tmdbAttribution = 'This product uses the TMDB API but is not endorsed or certified by TMDB.';

/// What Scene takes from TMDB for one film: artwork, synopsis, runtime and a
/// trailer. The recommendation tags (intensity, cognitive load, tone …) stay
/// Scene's own curation — no movie API provides them (RFC §6).
class MovieInfo {
  const MovieInfo({
    required this.tmdbId,
    required this.title,
    this.year,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.runtimeMinutes,
    this.trailerYouTubeKey,
  });

  final int tmdbId;

  /// TMDB's title, kept so a wrong match is easy to spot.
  final String title;
  final int? year;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final int? runtimeMinutes;
  final String? trailerYouTubeKey;

  String? posterUrl({String size = 'w342'}) => posterPath == null ? null : 'https://image.tmdb.org/t/p/$size$posterPath';
  String? backdropUrl({String size = 'w780'}) => backdropPath == null ? null : 'https://image.tmdb.org/t/p/$size$backdropPath';

  Uri? get trailerUrl => trailerYouTubeKey == null ? null : Uri.https('www.youtube.com', '/watch', {'v': trailerYouTubeKey});

  Uri get tmdbUrl => Uri.https('www.themoviedb.org', '/movie/$tmdbId');

  Map<String, Object?> toJson() => {
        'id': tmdbId,
        'title': title,
        'year': year,
        'poster': posterPath,
        'backdrop': backdropPath,
        'overview': overview,
        'runtime': runtimeMinutes,
        'trailer': trailerYouTubeKey,
      };

  factory MovieInfo.fromJson(Map<String, dynamic> m) => MovieInfo(
        tmdbId: m['id'] as int,
        title: m['title'] as String,
        year: m['year'] as int?,
        posterPath: m['poster'] as String?,
        backdropPath: m['backdrop'] as String?,
        overview: m['overview'] as String?,
        runtimeMinutes: m['runtime'] as int?,
        trailerYouTubeKey: m['trailer'] as String?,
      );
}

/// A thin TMDB v3 client: search by title and year, then details with videos.
class TmdbClient {
  TmdbClient(this.token, {http.Client? client}) : _http = client ?? http.Client();

  final String token;
  final http.Client _http;

  bool get isConfigured => token.isNotEmpty;

  /// A v4 read-access token is a JWT (sent as a Bearer header); anything else
  /// is treated as a v3 API key (sent as `api_key`).
  bool get _isBearer => token.startsWith('eyJ');

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final uri = Uri.https('api.themoviedb.org', '/3$path', {...query, if (!_isBearer) 'api_key': token});
    final res = await _http.get(uri, headers: {if (_isBearer) 'Authorization': 'Bearer $token', 'Accept': 'application/json'});
    if (res.statusCode != 200) throw TmdbException(res.statusCode, path);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// The TMDB id for a title and year, or null without a confident match.
  Future<int?> findId(String title, int year) async {
    final body = await _get('/search/movie', {'query': title, 'include_adult': 'false'});
    final results = (body['results'] as List? ?? const []).whereType<Map<String, dynamic>>();
    for (final r in results) {
      final y = _year(r['release_date'] as String?);
      final sameYear = y != null && (y - year).abs() <= 1;
      if (sameYear && (titlesMatch(title, r['title'] as String?) || titlesMatch(title, r['original_title'] as String?))) {
        return r['id'] as int;
      }
    }
    return null;
  }

  Future<MovieInfo> details(int id) async {
    final m = await _get('/movie/$id', {'append_to_response': 'videos'});
    final videos = ((m['videos'] as Map<String, dynamic>?)?['results'] as List? ?? const []).whereType<Map<String, dynamic>>();
    Map<String, dynamic>? pick(bool Function(Map<String, dynamic>) test) {
      for (final v in videos) {
        if (v['site'] == 'YouTube' && test(v)) return v;
      }
      return null;
    }

    final trailer = pick((v) => v['type'] == 'Trailer' && v['official'] == true) ?? pick((v) => v['type'] == 'Trailer');
    return MovieInfo(
      tmdbId: id,
      title: m['title'] as String? ?? '',
      year: _year(m['release_date'] as String?),
      posterPath: m['poster_path'] as String?,
      backdropPath: m['backdrop_path'] as String?,
      overview: (m['overview'] as String?)?.trim().isEmpty ?? true ? null : (m['overview'] as String).trim(),
      runtimeMinutes: (m['runtime'] as num?)?.toInt(),
      trailerYouTubeKey: trailer?['key'] as String?,
    );
  }

  void close() => _http.close();

  static int? _year(String? date) => date == null || date.length < 4 ? null : int.tryParse(date.substring(0, 4));

  /// "Glass Onion" matches "Glass Onion: A Knives Out Mystery"; case and
  /// punctuation are ignored.
  static bool titlesMatch(String a, String? b) {
    if (b == null) return false;
    // Apostrophes vanish ("Ocean's" = "Oceans"); other punctuation separates words.
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp("['\u2019]"), '').replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final x = norm(a);
    final y = norm(b);
    return x == y || y.startsWith('$x ') || x.startsWith('$y ');
  }
}

class TmdbException implements Exception {
  const TmdbException(this.statusCode, this.path);
  final int statusCode;
  final String path;

  @override
  String toString() => statusCode == 401 ? 'TMDB rejected the token (401).' : 'TMDB request $path failed ($statusCode).';
}
