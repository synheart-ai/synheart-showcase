import 'package:go_router/go_router.dart';

import 'check_in_screen.dart';
import 'compare_screen.dart';
import 'dna_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';
import 'state_screen.dart';
import 'tonight_screen.dart';
import 'welcome_screen.dart';
import 'why_screen.dart';

/// The eight MVP screens (plan §9). "Taste vs. Taste + State" is the toggle
/// on Tonight's Picks plus the side-by-side compare view.
abstract final class Routes {
  static const welcome = '/';
  static const profile = '/profile';
  static const dna = '/dna';
  static const editProfile = '/profile/edit';
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
        GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
        GoRoute(path: Routes.checkIn, builder: (_, _) => const CheckInScreen()),
        GoRoute(path: Routes.state, builder: (_, _) => const StateScreen()),
        GoRoute(path: Routes.tonight, builder: (_, _) => const TonightScreen()),
        GoRoute(path: Routes.compare, builder: (_, _) => const CompareScreen()),
        GoRoute(path: '/why/:id', builder: (_, st) => WhyScreen(filmId: st.pathParameters['id']!)),
      ],
    );
