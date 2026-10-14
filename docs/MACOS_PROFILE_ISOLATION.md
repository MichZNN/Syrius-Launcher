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

| Date | Tester | Syrius version | Result | Shared state found |
| --- | --- | --- | --- | --- |
| _pending_ | | | | |
