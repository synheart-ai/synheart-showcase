import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scene/app/movie_info_store.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/tmdb.dart';
import 'package:scene/data/tmdb_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake TMDB: /search/movie and /movie/{id}, counting requests.
MockClient fakeTmdb(List<http.Request> seen, {int status = 200}) => MockClient((req) async {
      seen.add(req);
      if (status != 200) return http.Response('{}', status);
      if (req.url.path == '/3/search/movie') {
        final q = req.url.queryParameters['query'];
        final results = switch (q) {
          'Knives Out' => [
              {'id': 1, 'title': 'Knives Out', 'original_title': 'Knives Out', 'release_date': '2019-11-27'},
            ],
          'Glass Onion' => [
              {'id': 2, 'title': 'Glass Onion: A Knives Out Mystery', 'original_title': 'Glass Onion', 'release_date': '2022-11-23'},
            ],
          'Se7en' => [
              {'id': 99, 'title': 'Se7en', 'release_date': '2011-01-01'}, // wrong year
            ],
          _ => <Map<String, Object>>[],
        };
        return http.Response(jsonEncode({'results': results}), 200);
      }
      final id = int.parse(req.url.pathSegments.last);
      return http.Response(
          jsonEncode({
            'id': id,
            'title': id == 1 ? 'Knives Out' : 'Glass Onion: A Knives Out Mystery',
            'release_date': id == 1 ? '2019-11-27' : '2022-11-23',
            'runtime': id == 1 ? 130 : 139,
            'overview': 'A detective investigates.',
            'poster_path': '/p$id.jpg',
            'videos': {
              'results': [
                {'site': 'YouTube', 'type': 'Teaser', 'key': 'teaser'},
                {'site': 'YouTube', 'type': 'Trailer', 'official': false, 'key': 'fan'},
                {'site': 'YouTube', 'type': 'Trailer', 'official': true, 'key': 'official$id'},
              ],
            },
          }),
          200);
    });

void main() {
  group('TmdbClient', () {
    test('a v4 token is a Bearer header; a v3 key is a query parameter', () async {
      final seen = <http.Request>[];
      await TmdbClient('eyJhbGciOi.test', client: fakeTmdb(seen)).findId('Knives Out', 2019);
      expect(seen.last.headers['Authorization'], 'Bearer eyJhbGciOi.test');
      expect(seen.last.url.queryParameters.containsKey('api_key'), isFalse);
      await TmdbClient('abc123', client: fakeTmdb(seen)).findId('Knives Out', 2019);
      expect(seen.last.url.queryParameters['api_key'], 'abc123');
    });

    test('matching needs the year (±1) and the title, including subtitles', () async {
      final c = TmdbClient('k', client: fakeTmdb([]));
      expect(await c.findId('Knives Out', 2019), 1);
      expect(await c.findId('Knives Out', 2020), 1, reason: 'release dates vary by country');
      expect(await c.findId('Glass Onion', 2022), 2);
      expect(await c.findId('Se7en', 1995), isNull, reason: 'a same-title film from another year is not a match');
      expect(TmdbClient.titlesMatch("Ocean's Eleven", 'Oceans Eleven'), isTrue);
      expect(TmdbClient.titlesMatch('Up', 'Upgrade'), isFalse);
    });

    test('details pick the official trailer and keep TMDB\'s title', () async {
      final info = await TmdbClient('k', client: fakeTmdb([])).details(1);
      expect(info.trailerYouTubeKey, 'official1');
      expect(info.trailerUrl.toString(), 'https://www.youtube.com/watch?v=official1');
      expect(info.posterUrl(), 'https://image.tmdb.org/t/p/w342/p1.jpg');
      expect(info.runtimeMinutes, 130);
    });

    test('a rejected token says so', () async {
      final c = TmdbClient('k', client: fakeTmdb([], status: 401));
      await expectLater(c.findId('Knives Out', 2019), throwsA(isA<TmdbException>().having((e) => '$e', 'message', contains('401'))));
    });
  });

  group('MovieInfoStore', () {
    final films = allFilms.where((f) => ['knives-out', 'glass-onion', 'se7en'].contains(f.id)).toList();

    test('without a token it is disabled and makes no requests', () async {
      final seen = <http.Request>[];
      final store = MovieInfoStore(client: TmdbClient('', client: fakeTmdb(seen)));
      await store.refresh(films);
      expect(store.enabled, isFalse);
      expect(seen, isEmpty);
      expect(store['knives-out'], isNull);
    });

    test('fetches once, remembers misses, and serves the cache offline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final seen = <http.Request>[];
      // No pinned ids: this exercises the title-and-year search path.
      final store = MovieInfoStore(prefs: prefs, client: TmdbClient('k', client: fakeTmdb(seen)), pinned: const {});
      await store.refresh(films);
      expect(store.matched, 2);
      expect(store['glass-onion']!.title, 'Glass Onion: A Knives Out Mystery');
      expect(store['se7en'], isNull);

      final before = seen.length;
      await store.refresh(films); // nothing missing — including the remembered miss
      expect(seen.length, before);

      // A new start with the network down still has the posters.
      final offline = MovieInfoStore(prefs: prefs, client: TmdbClient('k', client: fakeTmdb([], status: 503)), pinned: const {});
      expect(offline['knives-out']!.posterPath, '/p1.jpg');
    });

    test('a pinned film is fetched by its id, with no title search', () async {
      SharedPreferences.setMockInitialValues({});
      final seen = <http.Request>[];
      final store = MovieInfoStore(client: TmdbClient('k', client: fakeTmdb(seen)), pinned: const {'knives-out': 1});
      await store.refresh(films.where((f) => f.id == 'knives-out').toList());
      expect(store['knives-out']!.title, 'Knives Out');
      expect(seen.where((r) => r.url.path == '/3/search/movie'), isEmpty);
    });

    test('every catalogue film is pinned (tool/resolve_tmdb.dart)', () {
      expect(allFilms.where((f) => !tmdbIds.containsKey(f.id)).map((f) => f.id), isEmpty);
    });

    test('an API error is reported and nothing is lost', () async {
      final store = MovieInfoStore(client: TmdbClient('k', client: fakeTmdb([], status: 401)));
      await store.refresh(films);
      expect(store.error, contains('401'));
      expect(store.loading, isFalse);
    });
  });
}
