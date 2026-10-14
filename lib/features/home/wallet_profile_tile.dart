import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/models/wallet_profile.dart';
import '../../core/theme/launcher_palette.dart';

enum ProfileMenuAction { edit, remove }

/// One user-created profile card (spec 4.4).
///
/// Edit/Remove are reachable by right-click, the keyboard context-menu key
/// (or Shift+F10), a "more" button that only appears on hover/focus, and
/// screen-reader custom actions. The idle card shows none of that.
class WalletProfileTile extends StatefulWidget {
  const WalletProfileTile({
    super.key,
    required this.profile,
    required this.selected,
    required this.running,
    required this.onSelect,
    required this.onMenuAction,
  });

  final WalletProfile profile;
  final bool selected;
  final bool running;
  final VoidCallback onSelect;
  final ValueChanged<ProfileMenuAction> onMenuAction;

  @override
  State<WalletProfileTile> createState() => _WalletProfileTileState();
}

class _WalletProfileTileState extends State<WalletProfileTile> {
  bool _hovered = false;
  bool _focusHighlight = false;
  bool _focusWithin = false;
  final _tileKey = GlobalKey();

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => widget.onSelect(),
    ),
    _OpenMenuIntent: CallbackAction<_OpenMenuIntent>(
      onInvoke: (_) => _openMenuAtTile(),
    ),
  };

  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.contextMenu): _OpenMenuIntent(),
    SingleActivator(LogicalKeyboardKey.f10, shift: true): _OpenMenuIntent(),
  };

  Future<void> _openMenu(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<ProfileMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: ProfileMenuAction.edit,
          height: 36,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit profile'),
        ),
        PopupMenuItem(
          value: ProfileMenuAction.remove,
          height: 36,
          child: _MenuRow(icon: Icons.delete_outline, label: 'Remove profile'),
        ),
      ],
    );
    if (action != null) widget.onMenuAction(action);
  }

  void _openMenuAtTile() {
    final box = _tileKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _openMenu(box.localToGlobal(Offset(box.size.width - 24, box.size.height)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final selected = widget.selected;
    final showMore = _hovered || _focusWithin;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: [
        profile.name,
        if (profile.description.isNotEmpty) profile.description,
        if (widget.running) 'Syrius running',
      ].join(', '),
      hint: selected ? null : 'Select profile',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Edit profile'): () =>
            widget.onMenuAction(ProfileMenuAction.edit),
        const CustomSemanticsAction(label: 'Remove profile'): () =>
            widget.onMenuAction(ProfileMenuAction.remove),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _focusWithin = value),
        child: FocusableActionDetector(
          actions: _actions,
          shortcuts: _shortcuts,
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) =>
              setState(() => _focusHighlight = value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect,
            onSecondaryTapUp: (details) => _openMenu(details.globalPosition),
            child: AnimatedContainer(
              key: _tileKey,
              duration: const Duration(milliseconds: 120),
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _hovered
                    ? LauncherPalette.hoverProfileBackground
                    : LauncherPalette.profileBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusHighlight
                      ? LauncherPalette.primaryGreen
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    profile.icon.iconData,
                    size: 24,
                    color: selected
                        ? LauncherPalette.primaryGreen
                        : LauncherPalette.secondaryText,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _Titles(profile: profile)),
                  if (widget.running) ...[
                    const SizedBox(width: 8),
                    const _RunningDot(),
                  ],
                  if (showMore) ...[
                    const SizedBox(width: 4),
                    _MoreButton(onPressed: _openMenuAtTile),
                  ],
                  const SizedBox(width: 8),
                  if (selected)
                    const _ActiveBadge()
                  else
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: LauncherPalette.secondaryText,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenMenuIntent extends Intent {
  const _OpenMenuIntent();
}

class _Titles extends StatelessWidget {
  const _Titles({required this.profile});

  final WalletProfile profile;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LauncherPalette.profileTitleText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (profile.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                profile.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LauncherPalette.secondaryText,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: LauncherPalette.selectedBadgeBackground,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'Active',
        style: TextStyle(
          color: LauncherPalette.primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Small indicator that Syrius is currently running for this profile.
class _RunningDot extends StatelessWidget {
  const _RunningDot();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Syrius is running',
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: LauncherPalette.primaryGreen,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Profile options',
      icon: const Icon(Icons.more_horiz, size: 18),
      color: LauncherPalette.secondaryText,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        hoverColor: LauncherPalette.separator,
        focusColor: LauncherPalette.separator,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: LauncherPalette.secondaryText),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
