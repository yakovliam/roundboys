#!/usr/bin/env python3
"""Build a local test release. Never upload or install it automatically."""
import argparse
import hashlib
import json
import os
import platform
import plistlib
import re
import shutil
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
PLUGINS = {"decapitator": "Decapitator", "little-radiator": "LittleRadiator", "little-alter-boy": "LittleAlterBoy"}


def run(args, **kwargs):
    subprocess.run(list(map(str, args)), check=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Three numeric parts, for example 0.1.0")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version):
        parser.error("Use a numeric version: major.minor.patch")
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("This release target requires an Apple silicon Mac")
    app_identity = os.environ.get("ROUNDBOYS_APP_IDENTITY")
    installer_identity = os.environ.get("ROUNDBOYS_INSTALLER_IDENTITY")
    notary = os.environ.get("ROUNDBOYS_NOTARY_PROFILE")
    if bool(app_identity) != bool(installer_identity) or (notary and not app_identity):
        parser.error("Signing requires both identities; notarization also requires signing")
    out = ROOT / "dist" / f"roundboys-{args.version}-macos-arm64"
    out.mkdir(parents=True, exist_ok=False)
    work = out / "work"
    payload = work / "payload/Library/Audio/Plug-Ins/Components"
    payload.mkdir(parents=True)
    major, minor, patch = map(int, args.version.split("."))
    if major > 999 or minor > 999 or patch > 999:
        parser.error("Each version part must be at most 999")
    env = {**os.environ, "ROUNDBOYS_VERSION": args.version,
           "ROUNDBOYS_BUILD_NUMBER": str(major * 1000000 + minor * 1000 + patch + 3)}
    records = []
    for slug, executable in PLUGINS.items():
        plugin = ROOT / "plugins" / slug
        # A runner can restore licensed assets from a private, local asset directory.
        asset_root = os.environ.get("ROUNDBOYS_ASSET_ROOT")
        if asset_root:
            shutil.copytree(Path(asset_root) / slug / "assets", plugin / "assets", dirs_exist_ok=True)
            fixture = Path(asset_root) / slug / "reference/presets"
            if fixture.is_dir():
                shutil.copytree(fixture, plugin / "reference/presets", dirs_exist_ok=True)
        log = out / f"{slug}-checks.txt"
        with log.open("w") as stream:
            for command in [
                ["cargo", "fmt", "--manifest-path", plugin / "Cargo.toml", "--", "--check"],
                ["cargo", "test", "--offline", "--manifest-path", plugin / "Cargo.toml", "--", "--include-ignored"],
                ["cargo", "clippy", "--offline", "--manifest-path", plugin / "Cargo.toml", "--all-targets", "--", "-D", "warnings"],
                ["python3", plugin / "tools/build_au.py"],
            ]:
                run(command, stdout=stream, stderr=subprocess.STDOUT, env=env)
            bundle = plugin / "target" / f"{executable}.component"
            checker = work / f"check-{slug}"
            run(["xcrun", "clang++", "-std=c++17", "-fobjc-arc", plugin / "native/check.mm",
                 "-framework", "Cocoa", "-framework", "AudioToolbox", "-o", checker], stdout=stream, stderr=subprocess.STDOUT)
            run([checker, bundle, out / f"{slug}-editor.png"], stdout=stream, stderr=subprocess.STDOUT)
            binary = bundle / "Contents/MacOS" / executable
            result = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).strip()
            if result != "arm64":
                raise RuntimeError(f"Unexpected architecture: {result}")
            target = payload / bundle.name
            shutil.copytree(bundle, target)
            if app_identity:
                run(["codesign", "--force", "--options", "runtime", "--timestamp", "--sign", app_identity, target])
            run(["codesign", "--verify", "--strict", target])
            info = plistlib.loads((target / "Contents/Info.plist").read_bytes())
            if info["CFBundleShortVersionString"] != args.version:
                raise RuntimeError("Bundle version differs")
            records.append({"plugin": slug, "bundle": target.name, "architecture": result,
                            "binary_sha256": digest(target / "Contents/MacOS" / executable)})
    component_pkg = work / "RoundBoysPayload.pkg"
    component_info = work / "components.plist"
    run(["pkgbuild", "--analyze", "--root", payload.parents[3], component_info])
    components = plistlib.loads(component_info.read_bytes())
    for component in components:
        component["BundleIsRelocatable"] = False
        component["BundleHasStrictIdentifier"] = True
        component["BundleIsVersionChecked"] = False
    component_info.write_bytes(plistlib.dumps(components))
    run(["pkgbuild", "--root", payload.parents[3], "--install-location", "/", "--ownership", "recommended",
         "--component-plist", component_info, "--identifier", "dev.roundboys.payload", "--version", args.version, component_pkg])
    distribution = work / "Distribution.xml"
    distribution.write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>RoundBoys {escape(args.version)}</title>
  <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
  <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="false"/>
  <choices-outline><line choice="default"/></choices-outline>
  <choice id="default" visible="false"><pkg-ref id="dev.roundboys.payload"/></choice>
  <pkg-ref id="dev.roundboys.payload" version="{escape(args.version)}">RoundBoysPayload.pkg</pkg-ref>
</installer-gui-script>
''')
    package = out / f"RoundBoys-{args.version}-macOS-arm64.pkg"
    command = ["productbuild", "--distribution", distribution, "--package-path", work]
    if installer_identity:
        command += ["--sign", installer_identity, "--timestamp"]
    run(command + [package])
    if notary:
        run(["xcrun", "notarytool", "submit", package, "--keychain-profile", notary, "--wait"])
        run(["xcrun", "stapler", "staple", package])
        run(["xcrun", "stapler", "validate", package])
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = {"version": args.version, "commit": revision, "plugins": records,
                "signed": bool(app_identity), "notarized": bool(notary),
                "minimum_macos": "11.0", "format": "AU", "architecture": "arm64",
                "status": "preview; audio models remain provisional"}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # Ship only the installer and manifest. Logs and instructions stay separate.
    archive_root = work / f"RoundBoys-{args.version}"
    archive_root.mkdir()
    for path in [package, out / "manifest.json"]:
        shutil.copyfile(path, archive_root / path.name)
    archive = out / f"RoundBoys-{args.version}-macOS-arm64.zip"
    run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", archive_root, archive])
    (out / "SHA256SUMS.txt").write_text("".join(f"{digest(path)}  {path.name}\n" for path in [package, archive]))
    print(out)


if __name__ == "__main__":
    main()
