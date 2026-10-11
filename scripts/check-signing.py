#!/usr/bin/env python3
"""Verify update identity continuity and rejection of same-name unsigned code."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

identity = os.environ.get("WHISPER_SIGNING_IDENTITY", "Whisper Bubble Personal Signing")
root = Path(__file__).resolve().parent.parent


def run(arguments):
    result = subprocess.run(arguments, text=True, capture_output=True)
    if result.returncode:
        raise SystemExit(result.stderr.strip())
    return result.stdout + result.stderr


with tempfile.TemporaryDirectory(prefix="whisper-bubble-identity-check-") as directory:
    paths = []
    requirements = []
    for product, name in [("WhisperCoreChecks", "first-build"), ("WhisperAccessibilityChecks", "changed-build")]:
        target = Path(directory) / name
        shutil.copyfile(root / "build/spm/debug" / product, target)
        target.chmod(0o700)
        run(["codesign", "--force", "--sign", identity, "--timestamp=none", "--identifier", "local.whisperbubble.app", "--options", "runtime", str(target)])
        description = run(["codesign", "-d", "-r-", str(target)])
        requirement = next(line.split("designated => ", 1)[1] for line in description.splitlines() if "designated => " in line)
        paths.append(target)
        requirements.append(requirement)
    assert requirements[0] == requirements[1], "Identity changed between binaries"
    assert "certificate" in requirements[0] or "anchor" in requirements[0], "Identity must bind to the signing certificate"
    assert "cdhash" not in requirements[0], "Identity must survive code changes"
    for target, other in zip(paths, reversed(requirements)):
        run(["codesign", "--verify", "--strict", "-R", "=" + other, str(target)])
    impostor = Path(directory) / "same-identifier-ad-hoc"
    shutil.copyfile(paths[0], impostor)
    impostor.chmod(0o700)
    run(["codesign", "--force", "--sign", "-", "--identifier", "local.whisperbubble.app", str(impostor)])
    rejected = subprocess.run(["codesign", "--verify", "--strict", "-R", "=" + requirements[0], str(impostor)], text=True, capture_output=True)
    assert rejected.returncode == 3, "Same-name ad-hoc code must fail the certificate requirement"
    print("PASS: different builds retain the same certificate-bound identity")
    print("PASS: both builds satisfy the other's designated requirement")
    print("PASS: same-identifier ad-hoc executable is rejected")
    print("Designated requirement:", requirements[0])
