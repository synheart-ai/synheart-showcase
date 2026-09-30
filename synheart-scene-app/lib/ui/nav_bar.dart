import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'state_sheet.dart';
import 'theme.dart';

/// The four places of the floating bottom bar.
enum SceneTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  rightNow('Right now', Icons.favorite_border, Icons.favorite),
  search('Search', Icons.search, Icons.search),
  myScene('Movie DNA', Icons.person_outline, Icons.person);

  const SceneTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// A floating, pill-shaped bottom bar in the style of a cinema app: Home,
/// Right now (the current state sheet), Search and Movie DNA.
class SceneNavBar extends StatelessWidget {
  const SceneNavBar({super.key, required this.current});

  final SceneTab current;

  void _go(BuildContext context, SceneTab tab) {
    if (tab == current && tab != SceneTab.rightNow) return;
    switch (tab) {
      case SceneTab.home:
        context.go(Routes.tonight);
      case SceneTab.rightNow:
        showStateSheet(context);
      case SceneTab.search:
        context.push(Routes.search);
      case SceneTab.myScene:
        context.push(Routes.dna);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xF2262626),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: SceneColors.line),
          ),
          child: Row(children: [
            for (final tab in SceneTab.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: tab == current,
                  label: tab.label,
                  child: ExcludeSemantics(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _go(context, tab),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: tab == current ? const Color(0xFF3D3D3D) : Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(tab == current ? tab.selectedIcon : tab.icon,
                              size: 24, color: tab == SceneTab.rightNow && tab != current ? SceneColors.accent : SceneColors.ink),
                          const SizedBox(height: 2),
                          Text(tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: tab == current ? FontWeight.w700 : FontWeight.w500,
                                color: tab == current ? SceneColors.ink : SceneColors.sage,
                              )),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}
