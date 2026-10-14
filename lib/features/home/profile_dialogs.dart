import 'package:flutter/material.dart';

import '../../core/models/wallet_profile.dart';
import '../../core/theme/launcher_palette.dart';

typedef ProfileFormResult = ({
  String name,
  String description,
  ProfileIcon icon,
});

/// Add (when [initial] is null) or Edit dialog. Returns null on Cancel.
/// [onSubmit] performs the actual change; when it throws, the error is shown
/// inside the dialog and the dialog stays open.
Future<bool> showProfileFormDialog(
  BuildContext context, {
  WalletProfile? initial,
  required Future<void> Function(ProfileFormResult result) onSubmit,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ProfileFormDialog(initial: initial, onSubmit: onSubmit),
  );
  return saved ?? false;
}

class _ProfileFormDialog extends StatefulWidget {
  const _ProfileFormDialog({required this.initial, required this.onSubmit});

  final WalletProfile? initial;
  final Future<void> Function(ProfileFormResult result) onSubmit;

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late ProfileIcon _icon = widget.initial?.icon ?? ProfileIcon.defaultChoice;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit((
        name: _name.text,
        description: _description.text,
        icon: _icon,
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_isEdit ? 'Edit profile' : 'Add wallet profile'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: WalletProfile.maxNameLength,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: LauncherPalette.headingText),
                decoration: const InputDecoration(labelText: 'Profile name'),
                validator: WalletProfile.validateName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLength: WalletProfile.maxDescriptionLength,
                style: const TextStyle(color: LauncherPalette.headingText),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                validator: WalletProfile.validateDescription,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Icon',
                style: TextStyle(
                  color: LauncherPalette.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              _IconPicker(
                value: _icon,
                onChanged: (icon) => setState(() => _icon = icon),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: LauncherPalette.errorText,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.onChanged});

  final ProfileIcon value;
  final ValueChanged<ProfileIcon> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final icon in ProfileIcon.values)
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: icon == value,
            label: '${icon.label} icon',
            child: Tooltip(
              message: icon.label,
              child: InkWell(
                onTap: () => onChanged(icon),
                borderRadius: BorderRadius.circular(10),
                focusColor: LauncherPalette.hoverProfileBackground,
                hoverColor: LauncherPalette.hoverProfileBackground,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 56,
                  height: 48,
                  decoration: BoxDecoration(
                    color: icon == value
                        ? LauncherPalette.selectedBadgeBackground
                        : LauncherPalette.profileBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: icon == value
                          ? LauncherPalette.primaryGreen
                          : LauncherPalette.separator,
                    ),
                  ),
                  child: Icon(
                    icon.iconData,
                    size: 22,
                    color: icon == value
                        ? LauncherPalette.primaryGreen
                        : LauncherPalette.secondaryText,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Confirmation for removing a profile. When the profile contains wallet
/// files, a second explicit confirmation (checkbox) is required.
Future<bool> showRemoveProfileDialog(
  BuildContext context, {
  required WalletProfile profile,
  required bool hasWalletData,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _RemoveProfileDialog(profile: profile, hasWalletData: hasWalletData),
  );
  return confirmed ?? false;
}

class _RemoveProfileDialog extends StatefulWidget {
  const _RemoveProfileDialog({
    required this.profile,
    required this.hasWalletData,
  });

  final WalletProfile profile;
  final bool hasWalletData;

  @override
  State<_RemoveProfileDialog> createState() => _RemoveProfileDialogState();
}

class _RemoveProfileDialogState extends State<_RemoveProfileDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final canConfirm = !widget.hasWalletData || _acknowledged;
    return AlertDialog(
      scrollable: true,
      title: const Text('Remove profile'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Remove '),
                  TextSpan(
                    text: '"${widget.profile.name}"',
                    style: const TextStyle(
                      color: LauncherPalette.headingText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' from the launcher? Its folder will be moved to the '
                        'Trash, not permanently deleted.',
                  ),
                ],
              ),
            ),
            if (widget.hasWalletData) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LauncherPalette.profileBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LauncherPalette.errorText),
                ),
                child: const Text(
                  'This profile contains Syrius wallet files. Make sure you '
                  'have a backup of its seed before removing it. Emptying the '
                  'Trash afterwards deletes the wallet files permanently.',
                  style: TextStyle(color: LauncherPalette.headingText),
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: (value) =>
                    setState(() => _acknowledged = value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: LauncherPalette.primaryGreen,
                checkColor: LauncherPalette.buttonText,
                title: const Text(
                  'I understand this profile contains wallet data',
                  style: TextStyle(
                    color: LauncherPalette.headingText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: LauncherPalette.errorText,
            foregroundColor: LauncherPalette.buttonText,
          ),
          child: const Text('Remove profile'),
        ),
      ],
    );
  }
}

Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: SizedBox(width: 360, child: SelectableText(message)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

const alreadyRunningMessage =
    'Syrius is already running. Use "Exit wallet" inside Syrius, then try '
    'again.';

Future<void> showAlreadyRunningDialog(BuildContext context) {
  return showMessageDialog(
    context,
    title: 'Syrius is running',
    message:
        '$alreadyRunningMessage\n\nClosing the Syrius window is not enough: '
        'open the Syrius menu-bar (tray) icon and choose "Exit wallet" so it '
        'can shut down cleanly.',
  );
}

enum SyriusNotFoundChoice { locate, download }

Future<SyriusNotFoundChoice?> showSyriusNotFoundDialog(BuildContext context) {
  return showDialog<SyriusNotFoundChoice>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Syrius not found'),
      content: const SizedBox(
        width: 360,
        child: Text(
          'Syrius could not be found. Locate the installed application or '
          'download the official release.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SyriusNotFoundChoice.download),
          child: const Text('Official releases'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(SyriusNotFoundChoice.locate),
          child: const Text('Locate Syrius...'),
        ),
      ],
    ),
  );
}

enum FirstRunChoice { setUp, learn }

/// Shown before the first launch of an empty profile when an ordinary Syrius
/// installation exists under the real home folder (spec 5.2).
Future<FirstRunChoice?> showFirstRunChoiceDialog(
  BuildContext context, {
  required WalletProfile profile,
}) {
  return showDialog<FirstRunChoice>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('New profile'),
      content: SizedBox(
        width: 380,
        child: Text(
          '"${profile.name}" does not contain a wallet yet. Syrius will show '
          'its own setup screen, where you can create a new wallet or import '
          'an existing one.\n\nYour existing Syrius installation in '
          '~/Library/znn will not be touched.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(FirstRunChoice.learn),
          child: const Text('Learn how to use an existing wallet'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(FirstRunChoice.setUp),
          child: const Text('Set up this profile in Syrius'),
        ),
      ],
    ),
  );
}

Future<void> showExistingWalletHelpDialog(BuildContext context) {
  return showMessageDialog(
    context,
    title: 'Using an existing wallet',
    message:
        'The launcher never copies or moves wallet files, and it never asks '
        'for your seed words or password.\n\n'
        'To use a wallet you already have in this profile:\n'
        '1. Select the profile and choose "Set up this profile in Syrius".\n'
        '2. In Syrius, choose the import option and enter your seed there '
        '(only inside Syrius).\n'
        '3. Choose a password for this profile in Syrius.\n\n'
        'Your current Syrius installation in ~/Library/znn stays unchanged.',
  );
}
