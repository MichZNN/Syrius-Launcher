# macOS profile isolation

**Status: NOT VERIFIED.** Do not use funded wallets with Syrius Launcher until
the experiment below has passed on a real Mac and the results are recorded
here.

## Installed Syrius (checked 2026-10-14)

| Item | Value |
| --- | --- |
| App path | `/Applications/s y r i u s.app` |
| `CFBundleIdentifier` | `network.zenon.syrius` |
| `CFBundleExecutable` | `s y r i u s` (with spaces) |
| `CFBundleShortVersionString` | `v0.2.4-alphanet` (same version the spec was written for) |
| Architectures | universal (`x86_64`, `arm64`) |
| App Sandbox | **off** (`com.apple.security.app-sandbox = false`) |

Because Syrius is not sandboxed, it does not use a container directory, so a
HOME override can in principle redirect its SDK paths
(`$HOME/Library/znn/{wallet,syrius}`).

## How the launcher starts Syrius

- The executable is started directly with `Process.start`. The launcher never
  uses `open -a` and never runs a shell.
- `HOME=<~/SyriusProfiles/<uuid>>` is set for the child process only. The
  rest of the environment is inherited.
- Syrius is started in `ProcessStartMode.detached`. It gets no stdio pipes, so
  its output is never captured, and it cannot be killed by SIGPIPE if the
  launcher quits first. The launcher tracks the process by pid instead: it
  checks `NSRunningApplication` for the bundle id, plus `pgrep -x` on the
  executable name.
- The Syrius launcher itself runs **without** App Sandbox. A sandboxed parent
  would pass its sandbox on to Syrius.

## Open questions the experiment must answer

1. Does Syrius write the `wallet/` and `syrius/` (Hive) files only under the
   injected HOME?
2. **macOS preferences / `NSUserDefaults`** (for example `shared_preferences`
   or `window_manager` state) are resolved by CoreFoundation. CF uses
   `CFFIXED_USER_HOME`, not necessarily `HOME`. Check whether
   `~/Library/Preferences/network.zenon.syrius.plist` is shared between
   profiles. If it holds wallet-affecting state, a narrowly scoped fix could
   also set `CFFIXED_USER_HOME` for the child process. That fix is untested
   and is not implemented.
3. Does `path_provider` inside Syrius (if used) resolve to the real home
   (`NSHomeDirectory`)?
4. Where does the embedded node write its data? Is that data shared?
5. WalletConnect storage, logs, Keychain items.
6. Single-instance behaviour: does a second Syrius started with a different
   HOME hand over to the running one? (The launcher blocks this anyway.)

## Experiment (spec section 9)

Use **disposable** wallets only. Make a backup of `~/Library/znn` first.

```bash
# 0. Backup and fingerprint the ordinary installation (no keys are printed)
cp -Rp ~/Library/znn ~/znn-backup-$(date +%Y%m%d)
find ~/Library/znn -type f -exec stat -f '%m %z %N' {} + | sort > /tmp/znn-before.txt

# 1. Two empty test profiles
mkdir -p ~/SyriusProfiles/test-a ~/SyriusProfiles/test-b

# 2. In a second terminal, record file writes by Syrius outside the profiles
sudo fs_usage -w -f filesys | grep -i 's y r i u s' | grep -v SyriusProfiles > /tmp/syrius-writes.txt

# 3. Start profile A directly (this is the same thing the launcher does)
HOME=~/SyriusProfiles/test-a "/Applications/s y r i u s.app/Contents/MacOS/s y r i u s"
```

1. In Syrius, create disposable wallet A. Then quit Syrius through the tray
   icon with **Exit wallet**.
2. Check that the following directories exist:
   `~/SyriusProfiles/test-a/Library/znn/wallet` and `.../syrius`.
3. Repeat with `test-b` and disposable wallet B.
4. Start A again and unlock it with A's password. Start B again and do the
   same with B's password. Each profile must show its own wallet.
5. Compare `/tmp/syrius-writes.txt`. Note every path outside the profiles,
   especially `~/Library/Preferences`, `~/Library/Application Support`,
   `~/Library/Caches` and anything in the Keychain.
6. Compare the fingerprint of `~/Library/znn` with `/tmp/znn-before.txt`. It
   must not have changed.
7. Repeat steps 1–6 through Syrius Launcher itself, with profiles made with
   **Add wallet profile**.

## Results

| Date | Syrius version | Result | Shared state found |
| --- | --- | --- | --- |
| 2026-10-14 | v0.2.4-alphanet | **Partial: NOT isolated** | WalletConnect state in `NSUserDefaults` |

### 2026-10-14: first real run (two profiles created and launched through the launcher)

**Isolated (works as intended):**

- Each profile has its own `Library/znn/wallet/` and `Library/znn/syrius/`
  (Hive boxes, `key_store_box`, logs).
- The two profiles have different wallet addresses (visible in the
  per-address Hive box names).
- The ordinary `~/Library/znn` was last modified at 11:06. The launcher was
  first started at 11:42, so the launcher did not touch it.

**Shared between ALL profiles and the ordinary installation:**

- `~/Library/Preferences/network.zenon.syrius.plist` (`NSUserDefaults`,
  written through Flutter `shared_preferences`) contains the complete
  **WalletConnect v2 state**:
  - `flutter.wc@2:core:*//pairings`, `sessions`, `proposals`, `keychain`
  - `jsonRpcHistory`, `pendingRequests`, `authKeys`
  - and the related keys.

  Risk: a dApp pairing or session approved in profile A remains known when
  profile B is running. Requests from that dApp could then reach the wrong
  wallet. The WalletConnect symmetric keys are also shared.
- `NSOSPLastRootDirectory` (last folder of an open panel) is shared. This is
  harmless.

**Tried and rejected:** setting `CFFIXED_USER_HOME` does **not** redirect
`NSUserDefaults` on this macOS version. `cfprefsd` ignores it. A probe with
`defaults write` landed in the real `~/Library/Preferences`.

**Conclusion:** wallet files and Hive data are isolated, but WalletConnect
is not. Until a tested fix exists, do not use WalletConnect in launcher
profiles. Production use stays blocked (spec section 9).

### Mitigation in the launcher (since 2026-10-14)

- A one-time warning before the first launch says that WalletConnect data is
  shared by all profiles.
- **Syrius Launcher → WalletConnect...** in the menu bar offers two options:
  - **Clear WalletConnect data now**: needs confirmation and is refused while
    Syrius runs.
  - **Clear WalletConnect data before each launch**: off by default.
- Clearing removes only keys that start with `flutter.wc@2:` from the
  `network.zenon.syrius` preferences domain. It goes through `CFPreferences`
  (cfprefsd) and never edits the plist file directly. Other Syrius
  preferences stay untouched. This was verified on a probe domain.
- Clearing also affects the ordinary Syrius installation, because the
  domain is the same. The confirmation dialog says so.

### Bridge test plan: is shared WalletConnect state a real problem?

Syrius can hold several WalletConnect connections at the same time. Because
the store is shared, the question is what Syrius does with a session that
was approved by another profile. Use disposable wallets A and B, and keep
"clear before each launch" **off**.

1. Launch profile A and connect the Bridge to Syrius through WalletConnect.
   Note A's address as the Bridge shows it.
2. Exit Syrius with **Exit wallet**. Launch profile B **without** touching
   the Bridge.
3. In B, open Syrius's WalletConnect screen. Is A's Bridge session listed?
4. In the Bridge, refresh. Does it still show as connected? Does it now show
   **B's** address, or still A's?
5. Start an action in the Bridge that needs a signature. Does the request
   appear in B? Which address does the request show? **Reject it.**
6. Also connect the Bridge in B. Now launch A again: are there two sessions?
   Which address does each session report?
7. Repeat with "clear before each launch" **on**. Every launch must start
   with zero sessions, and the Bridge must ask to pair again.

Record the results below. If any step shows a session approved in A acting
on B (or the other way round), "clear before each launch" should become the
default, or be enforced.

| Step | Observation |
| --- | --- |
| 3 | _pending_ |
| 4 | _pending_ |
| 5 | _pending_ |
| 6 | _pending_ |
| 7 | _pending_ |

### Still to check

- Embedded node: not used in the 2026-10-14 test. Check where it stores its
  data before anyone enables it in a profile.
- Keychain items (Keychain Access → search for "syrius" / "zenon").
- A full `fs_usage` trace for writes outside the profile folder.
