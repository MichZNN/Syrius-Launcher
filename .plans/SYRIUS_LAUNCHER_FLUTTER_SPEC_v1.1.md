# Syrius Launcher - Flutter implementation specification

**Version:** 1.1  
**Date:** 2026-10-14  
**Target:** macOS first; keep the architecture ready for Windows and Linux  
**Audience:** Codex / Flutter developer  
**Status:** Implementation brief. The SDK path behavior is verified in source; end-to-end wallet isolation has NOT yet been verified on a real Mac.

## 1. Mission

Build a **standalone Flutter desktop application called Syrius Launcher** that lets a user select a named wallet profile and start the **unmodified, officially installed Syrius wallet** with that profile's private application data.

The launcher must reproduce the **exact dark visual style described in section 4**: compact window, dark header and wallet icon, subtle divider, dynamically generated profile cards, green `Active` badge on the selected profile, full-width Zenon-green `Launch Syrius` button, and centered `Add wallet profile` action.

**CRITICAL: On first launch, the application contains ZERO profiles.** No wallet profiles, labels, folders or selected wallet may be seeded automatically. The earlier `Main Wallet` / `Pillar Wallet` / `Sentinel Wallet` names were visual mockup examples **only**; they are never hardcoded as defaults. Every user creates, names, edits and removes their own profiles. Profile descriptions and icons are also user-configurable.

**Do not replace the design with a generic dashboard, sidebar, different palette, larger marketing layout, or a list of text-only buttons.** Preserve its styling and layout, while deriving the list of cards entirely from user-created data.

The launcher is not a wallet: it must **never request, display, transmit, store, log, or decrypt a mnemonic, private key, or Syrius wallet password**. The wallet import/unlock flows remain inside the official Syrius app.

### Non-goals for v1

- Forking or modifying Syrius.
- Embedding a blockchain node or implementing Zenon wallet functionality in the launcher.
- Concurrent multi-wallet sessions. Permit **one Syrius instance at a time** for the first release.
- Automatic migration of existing wallet contents without explicit consent and a tested safe migration routine.
- Automatic transaction, staking, Pillar, or Sentinel functionality.

## 2. Source-verified technical facts

The sources below are pinned wherever possible to the official Syrius `v0.2.4-alphanet` code and its pinned `znn_sdk_dart` SDK `v0.0.7`. Recheck the source if supporting later Syrius versions.

1. Syrius is a Flutter desktop application for macOS, Windows, and Linux. Its `pubspec.yaml` references `znn_sdk_dart` **v0.0.7**.
2. In SDK `lib/src/global.dart`, the default macOS root is calculated as:
   `path.join(Platform.environment['HOME']!, 'Library', 'znn')`.
3. The SDK derives `wallet/` and `syrius/` from that root. The latter is its cache/data directory.
4. In Syrius `lib/main.dart`, startup calls `ensureDirectoriesExist()` and initializes Hive with `Hive.init(znnDefaultPaths.cache.path.toString())`.
5. In Syrius `lib/utils/wallet_utils.dart`, the current wallet path is saved in Hive's `key_store_box`. This means old absolute wallet paths may need special handling when migrating a *previously configured* installation.
6. Syrius uses a tray icon, and its `Exit wallet` menu item is different from merely hiding the app window. In its window-close handler it also performs embedded-node cleanup.
7. The macOS Xcode project identifies the app as `s y r i u s` and uses bundle identifier `network.zenon.syrius`. Do not assume the app or executable is named `Syrius` without spaces.

**Important distinction:** The source verifies that SDK wallet and Hive paths derive from the injected `HOME`. It does **not** prove that every Flutter plugin, WalletConnect store, macOS preferences store, native library, or embedded-node file also stays inside the profile. Verify these before enabling real-money usage.

### Source references

- Official releases: https://github.com/zenon-network/syrius/releases
- Syrius `v0.2.4-alphanet` entry point: https://github.com/zenon-network/syrius/blob/v0.2.4-alphanet/lib/main.dart
- Syrius wallet path persistence: https://github.com/zenon-network/syrius/blob/v0.2.4-alphanet/lib/utils/wallet_utils.dart
- Syrius Hive box names: https://github.com/zenon-network/syrius/blob/v0.2.4-alphanet/lib/utils/constants.dart
- Syrius dependency versions: https://github.com/zenon-network/syrius/blob/v0.2.4-alphanet/pubspec.yaml
- Syrius macOS bundle configuration: https://github.com/zenon-network/syrius/blob/v0.2.4-alphanet/macos/Runner/Configs/AppInfo.xcconfig
- SDK `v0.0.7` path resolution: https://github.com/zenon-network/znn_sdk_dart/blob/v0.0.7/lib/src/global.dart
- Dart `Process.start`: https://api.dart.dev/dart-io/Process/start.html
- Flutter macOS builds/entitlements: https://docs.flutter.dev/platform-integration/macos/building

## 3. Main user flow

1. On a clean installation, the user opens **Syrius Launcher**. The profile collection is empty, no profile is selected, and `Launch Syrius` is disabled.
2. The empty state invites the user to click `Add wallet profile`. Nothing is created or imported without this action.
3. An **Add wallet profile** dialog asks for a required profile name, an optional description, and an icon. The name starts **blank**; the default icon choice can be `Wallet` (this is an icon choice, not a seeded profile).
4. On confirmation, the launcher generates an immutable UUID directory, saves the profile metadata, and selects the newly created profile. The new card renders the user's exact name and description.
5. The user may create any number of additional profiles, select a profile by clicking it, and edit its name, description and icon via the tile's context menu. A user-created profile can also be removed through a confirmed, safe deletion flow.
6. The selected tile shows a green `Active` badge; others show a muted right-chevron. `Active` means **selected**, not necessarily running.
7. User presses `Launch Syrius` for a selected profile.
8. Launcher verifies executable, profile directory, permissions, no conflicting Syrius process, and runtime compatibility.
9. Launcher starts the **real Syrius executable** with `HOME` pointing to the selected profile root.
10. Syrius reads its SDK wallet/Hive files from that profile's own `Library/znn/` folder.
11. On an unconfigured profile, Syrius itself presents its wallet setup/import flow. On a configured profile, the user unlocks in Syrius using the password they previously set.
12. When Syrius exits, the launcher returns to `ready` and permits switching.

**Switching profiles does not copy, move, rename, edit, or symlink any wallet data.** Only the environment of the new child process changes.

## 4. UI DESIGN CONTRACT - pixel-level implementation target

The design shown in the chat is the **visual source of truth** for colors, typography, dimensions, hierarchy and card styling. The three example wallets in that screenshot are **not actual initial data**. Every card must be generated from the persisted profile list; an empty list produces an empty state.

### 4.1 First-launch empty state (mandatory)

```text
+------------------------------------------------------+
|                                                      |
|  [green wallet icon] Syrius Launcher                 |
|                      Select your wallet profile      |
|                                                      |
|  --------------------------------------------------  |
|                                                      |
|                  [wallet outline]                    |
|                                                      |
|                 No wallet profiles yet               |
|             Create a profile to get started          |
|                                                      |
|                                                      |
|  +------------------------------------------------+  |
|  |           [play] Launch Syrius [disabled]      |  |
|  +------------------------------------------------+  |
|                                                      |
|             [+] Add wallet profile                   |
|                                                      |
+------------------------------------------------------+
```

- First-run data: `profiles = []`, `selectedProfileId = null`.
- No cards, sample names, wallet imports, prepopulated metadata, or per-profile directories are created.
- Show a centered, quiet empty-state illustration using an outline wallet icon and two short lines. Avoid a big onboarding panel that breaks the established design.
- The green button **retains its position, size and label**, but is visually disabled and non-clickable without a valid selection.
- The `Add wallet profile` action is the clear way to begin; it stays centered beneath the button.

### 4.2 Populated layout (only AFTER the user creates profiles)

```text
+------------------------------------------------------+
|                                                      |
|  [green wallet icon] Syrius Launcher                 |
|                      Select your wallet profile      |
|                                                      |
|  --------------------------------------------------  |
|                                                      |
|  +------------------------------------------------+  |
|  | [icon] User-defined profile name  [ Active ]   |  |
|  |        User-defined description                |  |
|  +------------------------------------------------+  |
|                                                      |
|  +------------------------------------------------+  |
|  | [icon] Another user's profile             >    |  |
|  |        Optional description                    |  |
|  +------------------------------------------------+  |
|                                                      |
|  +------------------------------------------------+  |
|  |             [play] Launch Syrius               |  |
|  +------------------------------------------------+  |
|                                                      |
|             [+] Add wallet profile                   |
|                                                      |
+------------------------------------------------------+
```

- The screenshot's `Main`, `Pillar`, and `Sentinel` labels were placeholders demonstrating *how* user-created cards look. Do **not** ship any built-in profiles with those or other names.
- A profile card uses the chosen icon, name, optional description, and current selection state. When the description is empty, omit its text rather than inserting a fixed label.
- Support **0, 1, 2, 3, or arbitrarily many** profiles. Keep card content at the top and scroll the list as necessary.
- Right-clicking a tile or using its accessible context menu exposes `Edit profile` and `Remove profile`, without permanently changing the uncluttered screenshot layout.

### 4.2a Exact static labels

| Element | Displayed text |
| --- | --- |
| Heading | `Syrius Launcher` |
| Subtitle | `Select your wallet profile` |
| Empty-state heading | `No wallet profiles yet` |
| Empty-state help | `Create a profile to get started` |
| Selected badge | `Active` |
| Primary action | `Launch Syrius` |
| Secondary action | `Add wallet profile` |
| Profile card title | User-defined `profile.name` |
| Profile card subtitle | User-defined `profile.description`, optional |
| Card icon | User-selected `profile.icon` |
| Context actions | `Edit profile` / `Remove profile` |

**There are no default profile names or default profile descriptions.**

### 4.3 Color tokens

Use these constants consistently; no automatic light theme for v1.

| Token | Hex | Application |
| --- | --- | --- |
| `background` | `#15191F` | Overall app/content background |
| `headerIconBackground` | `#252D38` | Header icon rounded square |
| `profileBackground` | `#232A34` | Each profile tile |
| `separator` | `#333C48` | Thin divider and subtle outer border |
| `primaryGreen` | `#6FF34D` | Zenon-green icon, `Active` text, launch button |
| `headingText` | `#F3F6FA` | Launcher heading |
| `profileTitleText` | `#FFFFFF` | Profile titles |
| `secondaryText` | `#A5ADBA` | Profile descriptions, chevrons, add action |
| `headerSubtitle` | `#98A3B6` | Header subtitle |
| `buttonText` | `#101810` | Dark text and play icon on green button |
| `selectedBadgeBackground` | `#263C2D` | Subtle dark-green `Active` pill |
| `hoverProfileBackground` | `#2B3541` | Hover only; do not change idle tile color |
| `disabledButton` | `#52644E` | Disabled action only |

### 4.4 Measurements and layout

All dimensions below are Flutter logical pixels (dp), not physical screen pixels.

- Preferred desktop content/window size: **460 x 535**; initial Mac window can be approximately 480 x 560 including native chrome. Use the same compact window on first launch, even when there are zero cards. Do not stretch the launcher into a full-screen layout.
- Responsive width: keep contents within **420-500 dp**; at narrower window sizes use safe padding and allow text to truncate gracefully.
- Outer content inset: **20 dp**. Outer corner radius: **22 dp**; optional subtle 1 dp border using `separator`.
- Header icon box: **52 x 52 dp**, radius **12 dp**, background `headerIconBackground`; outline wallet icon **26 dp**, green.
- Header icon to text spacing: **16 dp**.
- Heading typography: **24 dp**, semibold; subtitle **12-13 dp**, normal.
- Header to divider: **22 dp**. Divider thickness: **1 dp**. Divider to first profile: **20 dp**.
- Profile cards: **76 dp** minimum height; radius **12 dp**; background `profileBackground`; horizontal padding **16 dp**.
- Card icon: **24 dp**; gap icon to titles **16 dp**. Selected icon green; other icons muted gray.
- Profile titles: **16 dp**, semibold. Profile subtitles: **12-13 dp**, gray. Two lines stacked with **2-4 dp** between.
- Gap between profile cards: **12 dp**.
- Right chevron: **20 dp**, muted gray, except selected card, which displays badge.
- `Active` badge: height approximately **25 dp**, horizontal inset **10 dp**, 12 dp font, pill radius 100 dp, `selectedBadgeBackground` with green text.
- Last profile card to primary button: **20 dp**.
- Primary green button: full available width, **50 dp** height, radius **12 dp**; centered 18-20 dp dark play icon, **10 dp** gap, **15-16 dp** semibold text.
- Primary button to footer: **16 dp**.
- Footer action: centered + icon 16 dp, text **13-14 dp**, gray. Do not turn this into another filled button.
- Use a system sans-serif font with a macOS-native feel; no new decorative font. Make text accessible and crisp at Retina resolution.
- Maintain a quiet, minimal dark UI: no gradients, illustrations, heavy shadows, charts, sidebar, top navigation tabs, or extra labels on the default view.
- List area scrolls when user-created profiles exceed the available space. Header, `Launch Syrius`, and `Add wallet profile` stay fixed and visible. When there are zero profiles, center the empty-state content within the list area.

### 4.5 Icons

Use Flutter Material outline icons initially (or equivalent vector line icons if the visual weight better matches the original):

- Header: `Icons.account_balance_wallet_outlined`.
- Profile icon options (chosen per user-created profile): wallet `Icons.account_balance_wallet_outlined`, server `Icons.dns_outlined`, shield `Icons.verified_user_outlined`, and optionally other simple line icons.
- If the user does not pick an icon, `Wallet` is an acceptable **icon selection default only**; do not create a wallet profile automatically.
- Unselected tile: `Icons.chevron_right`.
- Primary button: `Icons.play_arrow_rounded`.
- Footer: `Icons.add`.

Colors, alignment and visual weight matter more than the precise icon library. No emoji icons.

### 4.6 Interaction/animation rules

- Clicking or keyboard-activating a tile selects it immediately and stores the selection in metadata.
- Zero profiles means zero selection and no `Active` badge. With one or more profiles, zero or one tile may be selected, and a successful first add automatically selects the newly created profile.
- `Active` means **selected in the launcher**, not necessarily that Syrius is running.
- Hover changes a tile's background subtly to `hoverProfileBackground` (100-150 ms), but the idle appearance remains exactly as specified.
- Clicking the main action shows a small loading/progress indication and prevents double-click launches; on success, return the button to the normal design when not busy.
- While a Syrius instance is running, block launching another and explain how to fully exit Syrius before switching. Do not silently terminate it.
- Keyboard: Tab navigation, Enter/Space to select or activate, visible focus outline, accessible labels.
- Existing UI labels remain in English; user-facing dialogs can follow the same English language for consistency.
- Editing (name, optional description, icon), deletion, and advanced settings must be accessible through a **context menu** (right click on tile / keyboard context menu) or modal, without placing permanent clutter on the default home view. Provide an accessible non-right-click alternative.

### 4.7 Flutter UI reference (presentational component)

This is a **visual skeleton**, not the completed launcher. Wire its callbacks to real services; do not make a mock launch action appear successful. Its `profiles` input is a **dynamic list populated only by the user's actions**. First startup passes an empty list and a null `selectedId`. The actual app must wire the `Edit profile`/`Remove profile` context-menu actions to safe services; see section 7.

```dart
import 'package:flutter/material.dart';

class LauncherPalette {
  static const bg = Color(0xFF15191F);
  static const headerTile = Color(0xFF252D38);
  static const card = Color(0xFF232A34);
  static const divider = Color(0xFF333C48);
  static const green = Color(0xFF6FF34D);
  static const title = Color(0xFFF3F6FA);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA5ADBA);
  static const subtitle = Color(0xFF98A3B6);
  static const buttonInk = Color(0xFF101810);
  static const pill = Color(0xFF263C2D);
  static const hover = Color(0xFF2B3541);
  static const disabled = Color(0xFF52644E);
}

class ProfileViewData {
  const ProfileViewData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
}

class LauncherHomeView extends StatelessWidget {
  const LauncherHomeView({
    super.key,
    required this.profiles,
    required this.selectedId,
    required this.onSelect,
    required this.onLaunch,
    required this.onAdd,
    required this.canLaunch,
    this.launching = false,
  });

  final List<ProfileViewData> profiles;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onLaunch;
  final VoidCallback onAdd;
  final bool canLaunch;
  final bool launching;

  @override
  Widget build(BuildContext context) {
    final hasSelection = profiles.any((p) => p.id == selectedId);
    return Scaffold(
      backgroundColor: LauncherPalette.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: LauncherPalette.bg,
              border: Border.all(color: LauncherPalette.divider),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: LauncherPalette.headerTile,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: LauncherPalette.green,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Syrius Launcher',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: LauncherPalette.title,
                            )),
                          SizedBox(height: 2),
                          Text('Select your wallet profile',
                            style: TextStyle(
                              fontSize: 12,
                              color: LauncherPalette.subtitle,
                            )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: LauncherPalette.divider,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: profiles.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                              color: LauncherPalette.muted, size: 38),
                            SizedBox(height: 16),
                            Text('No wallet profiles yet',
                              style: TextStyle(
                                color: LauncherPalette.title,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                            SizedBox(height: 6),
                            Text('Create a profile to get started',
                              style: TextStyle(
                                color: LauncherPalette.muted, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final selected = p.id == selectedId;
                      return Material(
                        color: LauncherPalette.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelect(p.id),
                          child: SizedBox(
                            height: 76,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(p.icon, size: 24,
                                    color: selected
                                      ? LauncherPalette.green
                                      : LauncherPalette.muted),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(p.name, maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: LauncherPalette.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 3),
                                        Text(p.subtitle, maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: LauncherPalette.muted,
                                            fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: LauncherPalette.pill,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: const Text('Active',
                                        style: TextStyle(
                                          color: LauncherPalette.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                    )
                                  else
                                    const Icon(Icons.chevron_right,
                                      color: LauncherPalette.muted, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: canLaunch && hasSelection && !launching
                      ? onLaunch : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: LauncherPalette.green,
                      disabledBackgroundColor: LauncherPalette.disabled,
                      foregroundColor: LauncherPalette.buttonInk,
                      disabledForegroundColor: LauncherPalette.buttonInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: launching
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded, size: 21),
                    label: Text(launching ? 'Launching...' : 'Launch Syrius',
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add wallet profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: LauncherPalette.muted,
                      textStyle: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

When integrating, remove any space wasted by default `Scaffold`/window margins so the visual result matches the original design. Match the empty-state, card spacing and footer alignment in separate macOS screenshot/golden tests. When the `ListView` viewport expands, keep dynamically created cards at the top, not vertically distributed. Render **no fake profile cards**. Implement the tile context menu for profile editing and removal in `wallet_profile_tile.dart`.

## 5. Profile storage on macOS

### 5.1 Preferred structure

Use a dedicated managed profile root (example uses `<user>` as a placeholder). Only make a UUID folder **after** that user creates a profile:

```text
/Users/<user>/SyriusProfiles/
  <generated-uuid-a>/
    Library/
      znn/
        wallet/               # encrypted wallet files created by Syrius
        syrius/               # Hive boxes, logs and Syrius data
  <generated-uuid-b>/
    Library/znn/...
```

Directory names must use stable generated UUIDs, **not editable wallet labels**, so renaming a profile never changes paths or invalidates stored absolute paths. **The app must not create `<generated-uuid-a>` or `<generated-uuid-b>` on first run**; these are just structural examples. A stable shared parent directory may be created lazily.

Store *only the launcher's own, non-secret profile metadata* in the launcher's platform application-support directory, for example:

```text
~/Library/Application Support/Syrius Launcher/profiles.json
```

The exact launcher metadata directory can be provided by Flutter's `path_provider`, but **do not use `path_provider` to guess Syrius's own storage paths**. The Syrius SDK explicitly defines those paths.

**Actual first-launch metadata** (if persisted immediately, rather than treating a missing file as empty):

```json
{
  "schemaVersion": 1,
  "selectedProfileId": null,
  "syriusAppPath": null,
  "profiles": []
}
```

After a user **manually** creates their first profile, one illustrative entry could look like this (the name and description come from the dialog, not bundled seed data):

```json
{
  "schemaVersion": 1,
  "selectedProfileId": "7e3db53e-2a08-4c53-a418-e7b3abdc1a64",
  "syriusAppPath": null,
  "profiles": [
    {
      "id": "7e3db53e-2a08-4c53-a418-e7b3abdc1a64",
      "name": "My Wallet",
      "description": "Optional user-entered description",
      "icon": "wallet",
      "createdAt": "2026-10-14T00:00:00Z"
    }
  ]
}
```

These are metadata examples, **not** wallet files. Never add a mnemonic or wallet password field to the schema. Normalize/validate `selectedProfileId` against existing entries on every load; if it references a missing profile, safely set it to `null` (or a deliberate documented selection fallback), never synthesize a replacement profile.

### 5.2 First launch / create / edit / remove

- **Zero profiles on clean installation.** Initialize an empty collection. There is no default profile, default label, default description or selected profile.
- Do not create any profile directories or modify any Syrius state until the user explicitly clicks `Add wallet profile` and confirms the form.
- Creation dialog: `Profile name` (required, initially blank), `Description` (optional, initially blank), `Icon` (user-selectable, initial icon selection may be `Wallet`), `Create` and `Cancel`.
- On successful creation, generate an immutable UUID, create an isolated profile root, commit metadata, and select the new profile; show its card. Preserve user-entered names verbatim except for sensible input validation/trim.
- `Edit profile` dialog loads current name, description and icon, and allows all three to change. Saving only updates metadata; it must never rename, move or rewrite the corresponding wallet directory.
- `Remove profile` requires explicit confirmation and a safe Trash workflow for wallet data. Do not delete the running profile. After removal, update selection to a predictable remaining profile, or `null` if none remain. If the final profile is removed, the main screen **returns to the original empty state** with `Launch Syrius` disabled.
- If an existing ordinary Syrius installation is found under `~/Library/znn`, leave it **untouched**. On first launch of a newly created profile, offer a clear choice in a dialog: `Set up this profile in Syrius` or `Learn how to use an existing wallet`.
- For v1, the safest existing-wallet method is to import it via Syrius's own wallet flow into the newly created profile, with secrets entered **only in Syrius**.
- Avoid promising automatic migration until the absolute-path and all native-storage behaviors have been audited and tested.

### 5.3 File safety

- Use private directory permissions where supported (`0700` directory; restrictive file permissions).
- Atomic write for profile metadata: write temporary file, validate, flush, rename.
- Validate UUID/path containment before creating, loading, renaming or removing any profile directories.
- Do not follow untrusted symlinks during destructive operations.
- Never store profiles in a public/temp/synced folder by default.
- On app removal, do not automatically delete wallet data.
- Profile deletion must be explicit, require a second confirmation for nonempty wallets, and preferably move the folder to Trash rather than permanently deleting it.

## 6. How macOS launches the selected wallet (Option A)

**The launcher overrides `HOME` only for the child Syrius process.** It does not change the actual macOS user's HOME or create another macOS user account.

Example input:

```text
Selected: <a profile created by the user>
Profile root: /Users/<user>/SyriusProfiles/<profile-uuid>
HOME injected into Syrius: /Users/<user>/SyriusProfiles/<profile-uuid>
Syrius SDK root: /Users/<user>/SyriusProfiles/<profile-uuid>/Library/znn
Syrius wallet files: .../Library/znn/wallet
Syrius Hive/cache: .../Library/znn/syrius
```

### 6.1 Find the actual Syrius installation

1. Prefer identifying the installed application via its bundle identifier `network.zenon.syrius` (macOS Launch Services or a small platform channel), if straightforward and reliable.
2. Check common locations such as `/Applications/s y r i u s.app` and `~/Applications/s y r i u s.app`.
3. If not found, allow `Locate Syrius...` from a dialog or the settings/context menu.
4. Inspect `Contents/Info.plist` for **`CFBundleExecutable`** and verify that `Contents/MacOS/<CFBundleExecutable>` is present and executable. Do not hard-code guessed casing/spaces.
5. Save the selected `.app` path in launcher metadata and revalidate it on each launch.
6. Reject unknown, missing, non-executable, or suspicious app paths with a useful error; do not invoke arbitrary shell commands.

### 6.2 Launch implementation (Dart outline)

```dart
import 'dart:io';
import 'package:path/path.dart' as p;

Future<Process> launchSyriusMac({
  required String executablePath,
  required String profileRoot,
}) async {
  if (!Platform.isMacOS) {
    throw UnsupportedError('This launcher adapter is macOS-only');
  }

  final binary = File(executablePath);
  final root = Directory(profileRoot);
  if (!await binary.exists() || !await root.exists()) {
    throw StateError('Syrius executable or profile root is missing');
  }

  // The caller must ALSO validate path containment, executable identity,
  // profile permissions, and absence of a conflicting Syrius process.
  final process = await Process.start(
    binary.path,
    const [],
    workingDirectory: p.dirname(binary.path),
    environment: <String, String>{'HOME': root.absolute.path},
    includeParentEnvironment: true,
    runInShell: false,
    mode: ProcessStartMode.normal,
  );

  // Drain child output to avoid deadlocks. Do not persist potentially
  // sensitive stdout/stderr in launcher logs.
  process.stdout.drain<void>();
  process.stderr.drain<void>();
  return process;
}
```

`Process.start` starts the executable with the explicit child environment. `includeParentEnvironment: true` retains necessary system variables. `runInShell: false` avoids quoting/injection issues and preserves exact executable paths, even when the path contains spaces.

This snippet is an **outline**, not the whole process manager: it needs PID tracking, exit handling, conflict detection, error handling, profile state transitions and a tested method for reading `CFBundleExecutable`.

**Do not start Syrius with `open -a ...` for this mechanism.** Launch Services can reuse an already-running app and may not give it the intended `HOME`. Direct execution of the actual bundle executable is the behavior to test.

### 6.3 Switching and exit behavior

- v1 allows only one Syrius instance globally.
- If any Syrius process is already running (including one started manually), do not start a different profile. Display `Syrius is already running. Exit it completely before switching wallets.`
- Do not assume closing the Syrius window quits the app; its tray menu includes `Exit wallet`.
- Do not kill Syrius or its embedded node to switch profiles; allow it to perform proper cleanup.
- Observe the child process's exit code and update the launcher state when it exits.
- After launcher restart, treat saved PIDs as untrusted and verify process identity instead of blindly reusing them.
- Do not treat successful `Process.start` as proof that the wallet UI has fully initialized. Report launch attempt/success honestly and surface an early exit or crash.
- If the launcher itself closes while Syrius is running, avoid leaving stale file locks or a corrupted running-state flag. The Syrius process may continue; rediscover it when reopening the launcher.

## 7. Functional specification

| Feature | Expected behavior |
| --- | --- |
| First-launch home | Zero profile cards; centered empty-state guidance; null selection; disabled `Launch Syrius`; enabled `Add wallet profile`. |
| Select profile | Update selected ID and `Active` badge; persist selection. |
| Launch selected | Start official Syrius with selected profile's custom macOS `HOME`. |
| First Syrius launch of new user-created profile | Syrius, not the launcher, handles creation/import of wallet. |
| Restart same profile | Syrius sees same profile wallet/Hive data; unlock normally with existing password. |
| Switch profile | Require complete previous Syrius exit, then relaunch with other `HOME`; no file moving. |
| Add profile | Modal: required **blank** `Profile name`, blank optional `Description`, icon (`Wallet` / `Server` / `Shield`), `Create`, `Cancel`. Generate a UUID directory only after Create. Select the new profile automatically. |
| Edit profile | Context menu/modal. Edit name, optional description and chosen icon; persist changes without touching the UUID directory or wallet data. |
| Remove profile | Context menu; explicit confirmation; refuse for any running profile; safeguard wallet data and prefer moving its folder to Trash. |
| Delete last profile | Return to empty state, with `selectedProfileId = null`, disabled launch button and no generated demo cards. |
| Order of profiles | Preserve user-created order, append newly created profiles. Optional drag-and-drop reordering in a later version. |
| Locate Syrius | Choose installed `.app` if automatic detection fails. |
| Syrius not installed | Dialog explains and links to official releases; do not download/execute untrusted binaries automatically. |
| Start failure | Show an actionable error; no false success message; remain on launcher. |
| Already running | Block conflicting launch, show guidance to exit via Syrius tray/menu. |
| Background launch | Keep launcher window usable; do not block Flutter UI thread waiting for Syrius exit. |
| Launching UI | Disable duplicate presses, show short busy indication, retain selection. |
| Data protection | Never edit mnemonic/password; no silent migration, no unprompted deletion. |
| Accessibility | Keyboard, screen-reader labels, visible focus, sufficient click/touch targets. |

### 7.1 Modal and error details

Use dark dialogs matching the palette, without modifying the main screen's baseline appearance.

- **Add wallet profile**: begin with a blank name and description; validate trimmed name (1-48 characters), uniqueness of generated ID (labels may duplicate), optional description (max 80), and chosen icon. The `Create` action builds metadata and empty directory as a transaction; roll back safely if either step fails. `Cancel` must create nothing.
- **Edit profile**: prefill user-entered name, description and icon; allow edits to all three fields; only update display metadata and never change the generated UUID path or wallet files. `Cancel` must leave everything unchanged.
- **Remove profile**: require explicit `Remove profile` action and confirmation identifying the profile name; warn that wallet data exists if it does. Prefer moving the complete directory to Trash and only then remove metadata, with appropriate recovery/rollback for partial failures. If moving to Trash fails, stop; no automatic destructive fallback. If it was the last profile, return to an empty list and null selection.
- **Existing wallet**: explain that the user's current standard `~/Library/znn` installation will not be touched. The launcher must not read/ask for mnemonic words.
- **Conflict**: `Syrius is already running. Use "Exit wallet" inside Syrius, then try again.`
- **Missing binary**: `Syrius could not be found. Locate the installed application or download the official release.`

## 8. Application architecture

Keep a shared Flutter UI and profile manager, with a **platform adapter** that owns launch behavior. Do not scatter `Platform.isMacOS` checks throughout widgets.

```text
syrius_launcher/
  README.md
  pubspec.yaml
  lib/
    main.dart
    app.dart
    core/
      theme/
        launcher_palette.dart
        launcher_theme.dart
      models/
        wallet_profile.dart
        launcher_settings.dart
        launch_status.dart
      persistence/
        profile_repository.dart
        json_profile_repository.dart
      services/
        profile_service.dart
        syrius_locator.dart
        process_monitor.dart
        launch_coordinator.dart
      platform/
        syrius_platform_launcher.dart
        macos_syrius_launcher.dart
        windows_syrius_launcher.dart  # stub until supported
        linux_syrius_launcher.dart    # stub until supported
    features/
      home/
        launcher_home_view.dart
        wallet_profile_tile.dart
        profile_dialogs.dart
        launcher_controller.dart
  macos/
  windows/
  linux/
  test/
    profile_repository_test.dart
    profile_service_test.dart
    launch_coordinator_test.dart
    launcher_home_widget_test.dart
    syrius_locator_test.dart
  integration_test/
    macos_profile_isolation_test.dart
```

### 8.1 Key interfaces

```dart
abstract interface class SyriusPlatformLauncher {
  Future<SyriusInstallation?> discoverInstallation();
  Future<LaunchHandle> launch({
    required SyriusInstallation installation,
    required WalletProfile profile,
  });
  Future<bool> isAnySyriusRunning();
}

abstract interface class ProfileRepository {
  Future<List<WalletProfile>> loadProfiles();
  Future<void> saveProfiles(List<WalletProfile> profiles);
  Future<String?> loadSelectedProfileId();
  Future<void> saveSelectedProfileId(String? id);
}
```

Implement lifecycle/state logic in `LaunchCoordinator` / `LauncherController` and keep widgets presentational. Choose one simple state-management approach (e.g. `ChangeNotifier` or Riverpod) and do not add multiple state-management frameworks needlessly.

### 8.2 Runtime states

```text
INITIALIZING -> READY -> LAUNCHING -> RUNNING -> READY
                      |          |
                      +-> ERROR <-+

RUNNING + switch request -> BLOCKED (show conflict dialog)
```

`selectedProfileId` is not the same as `runningProfileId`. Never use the visible `Active` badge as proof of process state. When another wallet is running, either lock selection or allow selection while clearly refusing a second launch; **prefer locking selection in v1** to avoid confusing profile identification.

## 9. Mandatory proof of concept before real-wallet use

Implement the following test **before** completing the full app or trusting profile isolation. Use disposable test wallets and separate disposable test directories. Do not test with funded wallets at first.

1. Install an official macOS Syrius build. Confirm its bundle path/executable by reading `Info.plist`.
2. Confirm the ordinary `~/Library/znn` directory is backed up and record its state without exposing keys.
3. Create two empty profile roots, e.g. `~/SyriusProfiles/test-a` and `~/SyriusProfiles/test-b`.
4. Start Syrius directly with `HOME=<test-a>` and confirm it creates files under `<test-a>/Library/znn/{wallet,syrius}`.
5. Inside Syrius, configure a **disposable** wallet A and close Syrius fully using `Exit wallet`.
6. Start again with `HOME=<test-b>` and configure a different **disposable** wallet B.
7. Quit and relaunch A; confirm Syrius shows A and can unlock using A's password. Repeat for B.
8. Confirm no A profile file was modified by B, and vice versa. In particular check Hive, wallet path persistence, logs, node data, selected address, WalletConnect state, and the embedded-node mode.
9. Monitor filesystem access for writes outside each profile (e.g. through OS tools) and identify any relevant `~/Library/Application Support`, preferences, caches, Keychain, or OS-managed stores shared between launches.
10. Ensure starting Syrius through the launcher does not redirect into an already-running unrelated Syrius process.
11. Verify the ordinary `~/Library/znn` files were not changed or moved by the launcher test.
12. Test directory names with spaces and a profile name with non-ASCII characters (stored label only; generated UUID path remains ASCII).
13. Only mark macOS profile isolation **verified** when repeatable tests demonstrate that all wallet-affecting state is safely separated.

If native/plugin storage remains shared, **do not claim isolation or enable wallet switching for production**. Record which storage is shared and design a narrowly scoped fix. The backup option (symlink/copy-based profile switching) is **not** automatically safe; it must receive its own shutdown, backup, migration, integrity and locking tests. Never implement silent live file swaps.

## 10. Test suite / acceptance criteria

### UI tests

- [ ] **Fresh install displays zero profile cards**, empty-state icon/text and null selection; the `Launch Syrius` action is disabled, while `Add wallet profile` remains enabled.
- [ ] Screenshot/golden test of empty home matches section 4 colors, header, divider, button and footer; no seeded names or generated mock cards.
- [ ] Creating one profile displays exactly that user-entered name/description/icon; selected badge appears on it. Screenshot/golden test of populated home reproduces the reference card styling.
- [ ] Adding a second profile and selecting it moves `Active` badge, without changing the other card's name/icon/description.
- [ ] Edit changes the visible name/description/icon; cancel leaves them unchanged. Right-click and a keyboard-accessible action work.
- [ ] Main action remains exactly labeled `Launch Syrius` when idle, and only enables with a valid selection.
- [ ] Creating enough profiles to exceed the viewport scrolls cards without hiding primary button or changing theme.
- [ ] Keyboard navigation and focus states work.

### Persistence tests

- [ ] A clean install or absent metadata file loads `profiles = []` and `selectedProfileId = null` **without writing any demo profiles**.
- [ ] Restart before any profile is created still shows the empty state; no directories appear automatically.
- [ ] New profiles exist only after user confirms Create; Cancel creates no directories or metadata entries.
- [ ] User-added profiles and selections persist after restart, without duplicates or re-seeding.
- [ ] Editing name/description/icon does not change profile ID or root path.
- [ ] Removing the final profile restores the empty state and clears selection.
- [ ] Metadata updates are atomic and schema-versioned.
- [ ] Malformed metadata is handled without touching wallet data.
- [ ] Remove/delete never operates on a directory outside the managed profile root.

### Process tests

- [ ] Full executable path resolved from installed `.app` and verified.
- [ ] Process receives profile-specific `HOME`; no shell command string is constructed.
- [ ] Running a profile twice does not spawn two Syrius instances.
- [ ] Running standard Syrius outside the launcher blocks conflicting launches.
- [ ] Switching while running cannot mix data or start another process.
- [ ] Syrius error/early exit is reported without false success.
- [ ] Launcher remains responsive while Syrius is running.
- [ ] No wallet-related passwords, seeds, private keys, or full process stdout/stderr appear in launcher logs.

### Real macOS integration tests

- [ ] Two disposable wallet profiles survive restart and keep independent wallets, preferences and session data.
- [ ] Original `~/Library/znn` is preserved, unless the user separately authorizes a validated migration.
- [ ] Embedded node and WalletConnect interactions are tested for collisions/shared persistence.
- [ ] Works on Apple Silicon (arm64); test release build, not debug only.
- [ ] Codesign/notarization and necessary macOS entitlements documented for distribution.

## 11. Implementation order for Codex

**Work in small, reviewable increments.** Avoid one giant untested implementation.

**Phase 0 - Source and feasibility**

1. Establish new Flutter desktop repo/project and check `flutter doctor` on macOS.
2. Confirm installed Syrius version, `CFBundleExecutable`, macOS process behavior and SDK version.
3. Build a tiny standalone `Process.start` test with `HOME` override, not involving real funds.
4. Run the section 9 acceptance experiment. Document findings in `docs/MACOS_PROFILE_ISOLATION.md`.
5. Stop or revise architecture if the profile isolation test fails.

**Phase 1 - Pixel-matched Flutter UI**

1. Implement section 4 theme and home page.
2. Start from `profiles = []` and `selectedProfileId = null`, with centered empty-state guidance and disabled launch button; **never seed demo profiles**.
3. Implement dynamic profile cards rendered from the repository only, selection, Active badge, hover/focus, scrolling, and button loading state.
4. Implement empty-state and populated-state screenshot/golden tests before wiring wallet execution.

**Phase 2 - Profile persistence**

1. Implement `WalletProfile` and versioned JSON repository, with an empty initial list and null selection.
2. Implement safe UUID directory creation **only following explicit Create**, and atomic persistence.
3. Implement Add, Edit (name/description/icon) and Remove via modals/context menus with appropriate confirmation and accessibility.
4. Add tests for paths, creation/cancellation, editing, safe deletion, last-profile removal, atomic metadata writes and empty/nonempty behavior.

**Phase 3 - macOS Syrius process integration**

1. Locate official Syrius app and resolve executable via `Info.plist`.
2. Build the macOS launch adapter; inject `HOME` only into the child process.
3. Implement process locks, global conflict detection and exit monitoring.
4. Connect `Launch Syrius` to the real adapter, replacing all mock behavior.
5. Repeat disposable wallet isolation tests using the complete launcher.

**Phase 4 - Distribute macOS MVP**

1. Run `flutter analyze` and `flutter test`; build with `flutter build macos --release`.
2. Test `.app` on Apple Silicon using a separately installed official Syrius app.
3. Determine correct signing, hardened runtime, file access, process execution and sandbox entitlements. A directly launched external wallet may make Mac App Store sandbox distribution unsuitable for the first release; prefer an explicitly tested direct-download distribution.
4. Sign/notarize package as appropriate and prepare release notes / `.dmg`.

**Phase 5 - Future multiplatform support (NOT part of macOS MVP)**

- Linux SDK path: `HOME/.znn`; implement and test Linux adapter separately.
- Windows SDK path: `AppData/znn` (as read by the SDK). Windows native/Flutter storage may also use `APPDATA`, `LOCALAPPDATA`, `USERPROFILE`; audit before injecting a per-profile environment.
- Do not claim Windows/Linux working solely because the Flutter UI builds on those targets.

## 12. Commands and development setup

Requires a Mac with Flutter stable, Xcode and macOS desktop support installed. Use the current stable toolchain compatible with the intended release build.

```bash
flutter doctor -v
flutter config --enable-macos-desktop
flutter create --platforms=macos,windows,linux syrius_launcher
cd syrius_launcher
flutter pub get
flutter run -d macos
flutter analyze
flutter test
flutter build macos --release
```

Add dependencies only when they solve a specific need. Likely candidates:

- `path` for safe, platform-independent path construction.
- `path_provider` **for launcher metadata only**.
- `window_manager` if needed for fixed initial window sizing/centering.
- `uuid` for immutable profile IDs, or another secure UUID-generation approach.
- A macOS native platform channel only if needed for installed `.app` lookup, `Info.plist` resolution, running-process identity, or Trash behavior.

Do not add `znn_sdk_dart` to Syrius Launcher simply to access wallets; the launcher intentionally should not be able to manipulate wallet keys.

## 13. Explicit instructions for Codex

> Build a macOS-first, multiplatform-ready Flutter desktop app named `Syrius Launcher` according to this specification. Treat section 4 as the **locked visual style**: reproduce its exact palette, header, card hierarchy, spacing, green Active badge, green `Launch Syrius` button and gray `Add wallet profile` action. **On a clean install there are ZERO profiles, NO default names, NO default selection, and NO auto-created profile directories.** Show the specified empty state and disable Launch until a user creates/selects a profile. Profile name, description and icon are fully user-editable; provide Add, Edit and safe Remove workflows and generate cards dynamically from metadata. Never handle wallet secrets. Use a platform adapter to start the existing official Syrius executable with per-profile `HOME`, after first proving that the relevant Syrius version isolates both wallet and other sensitive state. Ensure only one Syrius process is active, avoid any file-moving trick, and do not overwrite the user's ordinary `~/Library/znn`. Write tests, keep code and comments in English, and document results of the macOS isolation experiment. Do not mark a feature complete until tested on a real Mac. Implement in phases and keep unresolved technical assumptions explicit.

## 14. Definition of done (macOS MVP)

The MVP is finished only when:

- The main screen matches the reference **visual design** in both empty and populated states.
- A new install has **zero profiles**, no default wallet names/descriptions/icons assigned to cards, and no selection.
- Users can create an unlimited practical number of profiles, choose each name/description/icon, select profiles, edit all display fields, and safely remove them.
- Creating the first profile selects it; removing the last profile returns to the exact empty state.
- Every profile is backed by a distinct, stable filesystem root.
- The official Syrius app can be launched from the selected root without editing Syrius.
- Two disposable test wallets independently survive repeated launches without accessing or altering the other profile.
- The ordinary preexisting Syrius installation remains intact.
- A second Syrius instance cannot be inadvertently launched while another is active.
- No launcher-managed mnemonic, private key or wallet password exists.
- `flutter analyze`, automated tests and a real macOS release build pass.
- All remaining platform caveats and any native storage that cannot be isolated are recorded, with production use blocked until corrected.

---

**Design principle:** One official Syrius application, zero wallets until the user creates them, then multiple user-defined isolated profiles in one elegantly simple Flutter launcher. No seeded examples, no fragile live file swaps and no wallet secrets in the launcher.
