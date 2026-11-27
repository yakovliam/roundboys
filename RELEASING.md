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

All active plug-ins have these files on the prepared local checkout.
No original executable is required for a release build.
Back up these ignored files in private storage.

A build runner can use an external directory with this layout:

```text
<asset-root>/decapitator/assets/...
<asset-root>/decapitator/reference/presets/...
<asset-root>/little-radiator/assets/...
<asset-root>/little-radiator/reference/presets/...
<asset-root>/little-alter-boy/assets/...
<asset-root>/little-alter-boy/reference/presets/...
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
The command signs all AUs and the installer.
It submits the installer to Apple and attaches the notarization ticket.
It stops if a signing or notarization step fails.
Check `signed` and `notarized` in `manifest.json` before team delivery.

## Delivery

Create a draft prerelease after a successful build:

```sh
gh release create test-v0.1.0 --draft --prerelease \
  --title 'RoundBoys 0.1.0' --notes-file release/NOTES.md \
  dist/roundboys-0.1.0-macos-arm64/*.pkg \
  dist/roundboys-0.1.0-macos-arm64/*.zip \
  dist/roundboys-0.1.0-macos-arm64/SHA256SUMS.txt \
  dist/roundboys-0.1.0-macos-arm64/manifest.json
```

Inspect the draft before publishing it.
Publishing makes the release files public because this repository is public.
Use a private delivery channel if the team needs restricted access.
The workflow creates drafts only. It does not publish them.

## GitHub Actions artifacts

The **Build test artifacts** workflow uses a local Apple silicon Mac runner.
It runs after a push to `main`. It also supports manual runs.
The workflow builds all active plug-ins and runs the native AU checks.
Download the installer artifact from the Actions run page.
Artifacts remain available for 30 days. Test logs remain available for 14 days.
The manual run accepts a version and can also create a draft prerelease.

The raw images and preset fixtures stay on the local Mac.
No raw asset archive is uploaded to GitHub.
Built plug-ins contain the images needed by their editors.
The distribution artifacts include those plug-ins.

Start one local runner for one queued build:

```sh
python3 tools/run_ci_runner.py
```

The helper downloads the official GitHub runner and checks its published hash.
It registers a temporary runner with the `roundboys` label.
It sets the local asset directory for the build.
It runs one job and then exits. It does not install a background service.
It needs GitHub CLI authentication with repository administration access.
A second Mac can use the same helper after its local assets are restored.
A build stays queued when no runner is online.
The workflow never runs pull request code.
Run this helper only for trusted changes on `main`.

The workflow uses a local signature without Apple notarization.
Use the signing process above for normal team delivery.
Do not store Apple credentials in the workflow or the repository.

## Checks and rollback

The release command runs formatting, Rust tests, Clippy, and native AU checks.
It checks the architecture, signature, and bundle version.
The native checks cover state recall, preset import, and editor creation.
The Decapitator check also covers user presets and meter movement.
Check real playback and automation in the audio host before publishing each release.
Full original sound matching remains open.

Keep the previous release installer for rollback.
Close the audio host before installing either version.
Run the previous installer to restore the previous test components.
The installer does not remove saved presets or host projects.
