import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

/// Register native titles only after MaterialApp loads its locale delegates.
class LocalizedQuickActions extends StatefulWidget {
  const LocalizedQuickActions({super.key, required this.child});
  final Widget child;

  @override
  State<LocalizedQuickActions> createState() => _LocalizedQuickActionsState();
}

class _LocalizedQuickActionsState extends State<LocalizedQuickActions> {
  Locale? _registeredLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (locale == _registeredLocale) return;
    _registeredLocale = locale;
    final items = <ShortcutItem>[
      for (final entry in const {
        'controls_lock_on': 'controlsLockOn',
        'controls_lock_off': 'controlsLockOff',
        'controls_light_toggle': 'controlsLightToggle',
        'controls_speed_4': 'controlsSpeed4',
      }.entries)
        ShortcutItem(
          type: entry.key,
          localizedTitle: context.tr('quickActions.${entry.value}'),
        ),
    ];
    const QuickActions().setShortcutItems(items).catchError((Object error) {
      debugPrint('Cannot update quick-action titles: $error');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
