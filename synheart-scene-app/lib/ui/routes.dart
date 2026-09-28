import 'package:go_router/go_router.dart';

import 'dna_screen.dart';
import 'profile_screen.dart';
import 'welcome_screen.dart';
import 'widgets.dart';

/// The eight MVP screens (plan §9). "Taste vs. Taste + State" is the toggle
/// on Tonight's Picks plus the side-by-side compare view.
abstract final class Routes {
  static const welcome = '/';
  static const profile = '/profile';
  static const dna = '/dna';
  static const checkIn = '/check-in';
  static const state = '/state';
  static const tonight = '/tonight';
  static const compare = '/compare';
  static String why(String filmId) => '/why/$filmId';
}

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
        GoRoute(path: Routes.dna, builder: (_, _) => const DnaScreen()),
        GoRoute(path: Routes.checkIn, builder: (_, _) => const ComingNext('Synheart check-in')),
        GoRoute(path: Routes.state, builder: (_, _) => const ComingNext('Your current state')),
        GoRoute(path: Routes.tonight, builder: (_, _) => const ComingNext("Tonight's picks")),
        GoRoute(path: Routes.compare, builder: (_, _) => const ComingNext('What changed?')),
        GoRoute(path: '/why/:id', builder: (_, _) => const ComingNext('Why this movie?')),
      ],
    );
