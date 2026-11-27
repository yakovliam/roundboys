#!/usr/bin/env python3
"""Run one trusted Actions job on the local Mac, without a background service."""
import argparse
import hashlib
import json
import os
import platform
import signal
import subprocess
import time
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = "yakovliam/roundboys"


def api(path, post=False):
    command = ["gh", "api", path]
    if post:
        command += ["--method", "POST"]
    return json.loads(subprocess.check_output(command, text=True))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=1800, help="Maximum runner lifetime in seconds")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("Use an Apple silicon Mac")
    assets = Path(os.environ.get("ROUNDBOYS_ASSET_ROOT", ROOT / ".local/build-assets")).resolve()
    for slug in ["decapitator", "little-radiator"]:
        for folder in ["assets", "reference/presets"]:
            if not (assets / slug / folder).is_dir():
                parser.error(f"Missing local assets: {assets / slug / folder}")
    release = api("repos/actions/runner/releases/latest")
    package = next(x for x in release["assets"] if x["name"].startswith("actions-runner-osx-arm64-")
                   and x["name"].endswith(".tar.gz"))
    expected = package.get("digest", "")
    if not expected.startswith("sha256:"):
        raise RuntimeError("The official runner package has no published SHA-256 digest")
    cache = ROOT / ".local/runner-cache"
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / package["name"]
    if not archive.exists():
        temporary = archive.with_suffix(".download")
        urllib.request.urlretrieve(package["browser_download_url"], temporary)
        temporary.replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected.split(":", 1)[1]:
        raise RuntimeError("The runner archive hash differs")
    name = "roundboys-one-job-" + uuid.uuid4().hex[:12]
    runner = ROOT / ".local/runners" / name
    runner.mkdir(parents=True)
    subprocess.run(["tar", "-xzf", archive, "-C", runner], check=True)
    token = api(f"repos/{REPO}/actions/runners/registration-token", post=True)["token"]
    subprocess.run([runner / "config.sh", "--url", f"https://github.com/{REPO}", "--token", token,
                    "--name", name, "--labels", "roundboys", "--unattended", "--ephemeral",
                    "--disableupdate", "--work", "_work"], cwd=runner, check=True)
    env = {**os.environ, "ROUNDBOYS_ASSET_ROOT": str(assets)}
    # The temporary token stays in memory and the runner configuration command only.
    process = subprocess.Popen([runner / "run.sh"], cwd=runner, env=env, start_new_session=True)
    try:
        code = process.wait(timeout=args.timeout)
        if code:
            raise RuntimeError(f"Runner exits with code {code}")
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        # Completed ephemeral runners remove their registration automatically.
        # Remove any remaining registration after cancellation or timeout.
        for item in api(f"repos/{REPO}/actions/runners")["runners"]:
            if item["name"] == name:
                subprocess.run(["gh", "api", f"repos/{REPO}/actions/runners/{item['id']}",
                                "--method", "DELETE"], check=True)
    print("The one-job runner stops. No background service remains.")


if __name__ == "__main__":
    main()
