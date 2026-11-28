import 'package:flutter/material.dart';

const ecoOrange = Color(0xFFAB481F);
const ecoForest = Color(0xFF183B34);
const ecoCanvas = Color(0xFFF4F6F2);

ThemeData ecoTheme() {
  final colors = ColorScheme.fromSeed(seedColor: ecoForest).copyWith(
    primary: ecoForest,
    primaryContainer: const Color(0xFFD9EBE1),
    onPrimaryContainer: const Color(0xFF183B34),
    secondary: ecoOrange,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    error: const Color(0xFF9E2724),
    onError: Colors.white,
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF182B25),
    onSurfaceVariant: const Color(0xFF42534B),
    outline: const Color(0xFF74867C),
    outlineVariant: const Color(0xFFDCE5DF),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  return base.copyWith(
    scaffoldBackgroundColor: ecoCanvas,
    textTheme: base.textTheme
        .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface)
        .copyWith(
          headlineSmall: TextStyle(
            color: colors.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: TextStyle(
            color: colors.onSurface,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: ecoCanvas,
      foregroundColor: ecoForest,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: ecoForest,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      iconColor: ecoForest,
      subtitleTextStyle: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFFF0F4F1),
      prefixIconColor: ecoForest,
      suffixIconColor: colors.onSurfaceVariant,
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(elevation: 0, shape: buttonShape),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(0, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(0, 48),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      height: 72,
    ),
  );
}

class EcoBanner extends StatelessWidget {
  const EcoBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ecoForest, Color(0xFF245B4C)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -70,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x225CD5A4), width: 28),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: EcoIcon(icon, onDark: true),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFDBEEE3),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcoIcon extends StatelessWidget {
  const EcoIcon(this.icon, {super.key, this.onDark = false});

  final IconData icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: onDark ? const Color(0xFFDAEFE3) : const Color(0xFFE8F1EB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(icon, color: ecoForest, size: 22),
    ),
  );
}

class EcoSection extends StatelessWidget {
  const EcoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class EcoField extends StatelessWidget {
  const EcoField(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: EcoIcon(icon),
    title: Text(label),
    subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
  );
}
