# erase-install

A zsh script (`erase-install.sh`, ~5000 lines) that downloads, reinstalls, upgrades or erases macOS using `startosinstall`. It runs as root, usually from an MDM policy (e.g. Jamf Self Service), and shows user dialogs via [swiftDialog](https://github.com/swiftDialog/swiftDialog). Full user documentation is in the wiki: https://github.com/grahampugh/erase-install/wiki

## Layout

- `erase-install.sh` - the main script. Version is set in the `version="X.Y"` variable near the top.
- `erase-install-launcher.sh`, `erase-install-launch-script-example*.sh`, `set-credentials.sh` - helper/example scripts.
- `Makefile` - builds the installer pkg (`pkg/erase-install/`), bundling the script, icons and swiftDialog pkgs. Package version is read from `version=` in `erase-install.sh`. Needs signing identity and GitHub tokens, so do not run it casually.
- `_tests/` - ad-hoc test scripts (no test framework).
- `CHANGELOG.md` - release notes, newest first.

## Branches

- `main` - latest production track; PRs go here.
- `release` - the current latest release.
- `legacy` - versions up to 27.x, for macOS 10.15 and older.
- Numbered branches (e.g. `44.0`) - the work for an upcoming version, published as pre-releases.

## Versioning and CHANGELOG convention

Pre-release tags and releases have incrementing numbers rather than being deleted and recreated, so testers know what they are running.

When changing a pre-release version that has **already been published**:

1. Bump the minor version in `version="..."` in `erase-install.sh` (e.g. `44.0` -> `44.1`).
2. Amend the existing CHANGELOG section for that version: rename `## [44.0]` to `## [44.1]`, and the `### Updates in` / `### Bugfixes in` headings to match. Add the new note to the existing lists rather than creating a separate section.
3. Reference the GitHub issue, e.g. `(fixes #604)`.

For a brand-new full release, the major version is always incremented.

## Conventions and gotchas

- Commit messages follow Conventional Commits (see the global instructions).
- Script is zsh (`#!/bin/zsh`), uses `writelog "[function_name] message"` for logging to `/Library/Management/erase-install/log/erase-install.log`.
- Dialogs: one main swiftDialog window is used for the whole run, and its content is changed by writing to the command file (`$dialog_log`). Use the `dialog_*` helpers: `dialog_stage` for information stages (with progress bar, optional blur), `dialog_prompt` for messages that need a button press (the window exits, and the exit code comes from `wait`), `dialog_cmd` to send a single command (always use it rather than `echo`, because zsh `echo` turns the literal `\n` in localised messages into real newlines). The command file is one-way: buttons can only be enabled/disabled (not added or hidden), and text fields or select lists cannot be added, so `ask_for_credentials` and `select_build_from_dialog` use separate windows (`get_default_dialog_args`) wrapped in `dialog_hide`/`dialog_show`. `--fs` means "blur the screen and disable the button", not a different window type. Commands must work on swiftDialog v2.5.6 (macOS 13-14) as well as v3.
- Separate dialog windows: invoke via `"$dialog_bin" "${dialog_args[@]}"`. `dialog_bin` must be the `dialogcli` binary in `Dialog.app/Contents/MacOS/` where it exists. The raw `Dialog` binary does not display when launched from a root context. `check_for_swiftdialog_app` must select `dialogcli` both for an existing install and after a fresh download (this was the cause of #604).
- swiftDialog is installed as a portable app into `$workdir/Dialog.app` (`/Library/Management/erase-install` by default), not to the system default location. The required version is `swiftdialog_tag_required` (macOS 14 and older get the `swiftdialog_ventura_tag_required` version).
- Always call external commands by full path (e.g. `/usr/bin/grep`, `/bin/rm`, `/bin/sleep`, `/usr/sbin/diskutil`) so the script does not depend on `$PATH`. zsh built-ins (`echo`, `printf`, `kill`, `which`, `cd`, `jobs`, etc.) are used without a path. The vendored `ljt` function is left as upstream provides it.
- Functions are kept in alphabetical (ASCII) order; put new functions in the right place.
- The script needs to support macOS 11+, so avoid features unavailable in older zsh/macOS tools.

## Testing

Use the test options to exercise workflows without destroying the machine, e.g.:

```
sudo ./erase-install.sh --fake-installer --install --beta --update
```

`--fake-installer` simulates the installer and switches on `--test-run`. To test the first-run swiftDialog install path, delete `/Library/Management/erase-install/Dialog.app` first.
