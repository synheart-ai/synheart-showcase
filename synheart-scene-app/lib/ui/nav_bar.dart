import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'theme.dart';

/// The four tabs of the floating bottom bar.
enum SceneTab {
  home('Home', Icons.home_outlined, Icons.home_rounded, Routes.tonight),
  clips('Clips', Icons.video_library_outlined, Icons.video_library, Routes.clips),
  search('Search', Icons.search, Icons.search, Routes.search),
  myScene('My Scene', Icons.person_outline, Icons.person, Routes.myScene);

  const SceneTab(this.label, this.icon, this.selectedIcon, this.path);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// A floating, pill-shaped bottom bar in the style of a cinema app. Inside
/// the tab shell [onTap] switches branches; elsewhere (a title page) it goes
/// to the tab's root.
class SceneNavBar extends StatelessWidget {
  const SceneNavBar({super.key, required this.current, this.onTap});

  final SceneTab? current;
  final void Function(SceneTab tab)? onTap;

  @override
  // Like system bars, the bar caps text scaling so it never grows past its
  // pill; its labels still scale up to 1.3×.
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xF2262626),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: SceneColors.line),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
        ),
        child: Row(
          children: [
            for (final tab in SceneTab.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: tab == current,
                  label: tab.label,
                  child: ExcludeSemantics(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(29),
                      onTap: () => onTap != null ? onTap!(tab) : context.go(tab.path),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: tab == current ? const Color(0xFF3D3D3D) : Colors.transparent,
                          borderRadius: BorderRadius.circular(29),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (tab == SceneTab.myScene)
                                const _Avatar(size: 26)
                              else
                                Icon(tab == current ? tab.selectedIcon : tab.icon, size: 26, color: tab == current ? SceneColors.ink : SceneColors.sage),
                              const SizedBox(height: 3),
                              Text(
                                tab.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: tab == current ? FontWeight.w700 : FontWeight.w500,
                                  color: tab == current ? SceneColors.ink : SceneColors.sage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The profile avatar: Scene's red mark on a red-to-purple tile.
class SceneAvatar extends StatelessWidget {
  const SceneAvatar({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => _Avatar(size: size);
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.22),
      gradient: const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFFDC1929)], begin: Alignment.topRight, end: Alignment.bottomLeft),
    ),
    child: ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: Image.asset('assets/scene_mark.png', fit: BoxFit.contain, excludeFromSemantics: true),
    ),
  );
}
