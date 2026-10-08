import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'check_in_screen.dart';
import 'clips_screen.dart';
import 'current_state_screen.dart';
import 'dna_screen.dart';
import 'edit_profile_screen.dart';
import 'my_scene_screen.dart';
import 'nav_bar.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'tonight_screen.dart';
import 'welcome_screen.dart';
import 'why_screen.dart';

/// Onboarding (Welcome → profile → Movie DNA → check-in), then a
/// state-aware cinema app: four tabs — Home, Clips, Search, My Scene — with
/// title pages, Settings and the check-in over them.
abstract final class Routes {
  static const welcome = '/';
  static const profile = '/profile';
  static const dna = '/dna';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const checkIn = '/check-in';
  static const state = '/state';
  static const tonight = '/home';
  static const clips = '/clips';
  static const search = '/search';
  static const myScene = '/my-scene';
  static String why(String filmId) => '/title/$filmId';
}

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
        GoRoute(path: Routes.dna, builder: (_, _) => const DnaScreen()),
        GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
        GoRoute(path: Routes.checkIn, builder: (_, _) => const CheckInScreen()),
        GoRoute(path: Routes.state, builder: (_, _) => const CurrentStateScreen()),
        GoRoute(path: Routes.settings, builder: (_, st) => SettingsScreen(pendingLink: st.extra as Uri?)),
        GoRoute(path: '/title/:id', builder: (_, st) => WhyScreen(filmId: st.pathParameters['id']!)),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _TabShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: Routes.tonight, builder: (_, _) => const TonightScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: Routes.clips, builder: (_, _) => const ClipsScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: Routes.myScene, builder: (_, _) => const MySceneScreen())]),
          ],
        ),
      ],
    );

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: SceneNavBar(
          current: SceneTab.values[shell.currentIndex],
          onTap: (tab) => shell.goBranch(tab.index, initialLocation: tab.index == shell.currentIndex),
        ),
      );
}
