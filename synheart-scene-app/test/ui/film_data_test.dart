import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scene/app/movie_info_store.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/tmdb.dart';
import 'package:scene/main.dart';

import '../support/fake_signals.dart';

void main() {
  testWidgets('Why this movie? shows the TMDB synopsis, a trailer and the attribution', (tester) async {
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final client = MockClient((req) async {
      if (req.url.path == '/3/search/movie') {
        return http.Response(jsonEncode({
          'results': [
            {'id': 807, 'title': 'Se7en', 'release_date': '1995-09-22'},
          ],
        }), 200);
      }
      return http.Response(jsonEncode({
        'id': 807,
        'title': 'Se7en',
        'release_date': '1995-09-22',
        'runtime': 127,
        'overview': 'Two detectives hunt a killer.',
        'videos': {
          'results': [
            {'site': 'YouTube', 'type': 'Trailer', 'official': true, 'key': 'abc'},
          ],
        },
      }), 200);
    });
    final movies = MovieInfoStore(client: TmdbClient('k', client: client));
    await movies.refresh(allFilms.where((f) => f.id == 'se7en'));

    await tester.pumpWidget(SceneApp(signals: FakeSignals(), movieInfo: movies));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Card).first, matching: find.text('Se7en')).last);
    await tester.pumpAndSettle();

    expect(find.text('Why this movie?'), findsOneWidget);
    expect(find.text('Two detectives hunt a killer.'), findsOneWidget);
    expect(find.text('Watch trailer'), findsOneWidget);
    expect(find.textContaining('not endorsed or certified by TMDB'), findsOneWidget);
  });
}
