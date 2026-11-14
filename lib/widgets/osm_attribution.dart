import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "© OpenStreetMap contributors" attribution label (v1.5.0),
/// required by the ODbL licence for every OpenStreetMap view.
///
/// A small translucent label pinned to a map corner; tapping it
/// opens the OpenStreetMap copyright page. Google Maps views do NOT
/// use this — the SDK draws its own attribution.
///
/// NOTE: flutter_map ships `SimpleAttributionWidget` for this, but
/// its Row ("flutter_map | © <source>") sizes to its content and
/// overflows the map under the widget-test font, whose glyphs are
/// much wider than Roboto — the smoke tests fail on it even though
/// it fits on a real device. This label shows the same text and tap
/// behaviour, and ellipsizes instead of overflowing if it ever runs
/// wider than the map.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key, this.alignment = Alignment.bottomRight});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
        child: Container(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            '© OpenStreetMap contributors',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
