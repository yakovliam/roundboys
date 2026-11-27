# Test releases

The repository is public. Keep private evidence and assets outside Git.
The user confirms permission to reproduce the interface.
The source build needs the local images. A fresh clone alone cannot build the editor.

## Local assets

For each active plug-in, keep these local directories:

```text
plugins/<plugin>/assets/interface/       Required interface images
plugins/<plugin>/assets/roundboys-faceplate-generated.png
plugins/<plugin>/reference/presets/      Native test fixtures
```

Both active plug-ins have these files on the prepared local checkout.
No original executable is required for a release build.
Back up these ignored files in private storage.

A build runner can use an external directory with this layout:

```text
<asset-root>/decapitator/assets/...
<asset-root>/decapitator/reference/presets/...
<asset-root>/little-radiator/assets/...
<asset-root>/little-radiator/reference/presets/...
```

Set `ROUNDBOYS_ASSET_ROOT` to that directory.
The release command restores the local files before each build.

## Signing

The default build uses a local signature. It has no Apple notarization.
It is suitable for controlled local testing. It does not provide a normal Gatekeeper installation experience.
Do not present it as a signed production release.

For normal team installation, obtain Apple Developer ID certificates.
Keep the private keys in the Mac keychain.
Set these environment variables to the certificate names and stored profile name:

```sh
export ROUNDBOYS_APP_IDENTITY='Developer ID Application: Your Company (TEAMID)'
export ROUNDBOYS_INSTALLER_IDENTITY='Developer ID Installer: Your Company (TEAMID)'
export ROUNDBOYS_NOTARY_PROFILE='roundboys-notary'
python3 tools/release.py --version 0.1.1
```

Store the Apple notarization credentials with `xcrun notarytool store-credentials` before the build.
Do not put passwords, certificates, or private keys in Git.
The command signs both AUs and the installer.
It submits the installer to Apple and attaches the notarization ticket.
It stops if a signing or notarization step fails.
Check `signed` and `notarized` in `manifest.json` before team delivery.

## Delivery

Create a draft prerelease after a successful build:

```sh
gh release create test-v0.1.0 --draft --prerelease \
  --title 'RoundBoys Test Bench 0.1.0' --notes-file release/NOTES.md \
  dist/roundboys-0.1.0-macos-arm64/*.pkg \
  dist/roundboys-0.1.0-macos-arm64/*.zip \
  dist/roundboys-0.1.0-macos-arm64/SHA256SUMS.txt \
  dist/roundboys-0.1.0-macos-arm64/manifest.json
```

Inspect the draft before publishing it.
Publishing makes the release files public because this repository is public.
Use a private delivery channel if the team needs restricted access.
The workflow creates drafts only. It does not publish them.

## Build runner

Register a dedicated Apple silicon Mac as a GitHub Actions runner.
Assign the `roundboys` label.
Keep a user logged in so the native editor checks can use the window server.
Install Rust, Xcode tools, Python 3, and GitHub CLI.
Provide the private local assets through `ROUNDBOYS_ASSET_ROOT`.
Set the repository variables with the same names as the environment variables above.
Use the manual **Build a test release** workflow.
The workflow accepts a numeric version and creates a draft prerelease.
It does not run code from pull requests.
Runner registration and Apple credentials remain separate setup steps.

## Checks and rollback

The release command runs formatting, Rust tests, Clippy, and native AU checks.
It checks the architecture, signature, and bundle version.
The native checks cover state recall, preset import, and editor creation.
The Decapitator check also covers user presets and meter movement.
Check real playback and automation in REAPER before publishing each release.
Full original sound matching remains open.

Keep the previous release installer for rollback.
Close the audio host before installing either version.
Run the previous installer to restore the previous test components.
The installer does not remove saved presets or host projects.
