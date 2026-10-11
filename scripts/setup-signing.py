#!/usr/bin/env python3
"""Create one persistent personal signing identity; never change system trust."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile

NAME = "Whisper Bubble Personal Signing"


def run(arguments, input=None):
    result = subprocess.run(arguments, input=input, text=True, capture_output=True)
    if result.returncode:
        # Do not print arguments: the import command contains a temporary password.
        raise SystemExit(f"{Path(arguments[0]).name} failed: {result.stderr.strip()}")
    return result.stdout


os.umask(0o077)
keychain = Path.home() / "Library/Keychains/login.keychain-db"
existing = subprocess.run(["/usr/bin/security", "find-certificate", "-c", NAME, "-p", str(keychain)], text=True, capture_output=True)
if existing.returncode == 0:
    print(f"Reusing existing certificate: {NAME}")
    print("No new signing identity was created.")
    raise SystemExit(0)

openssl = shutil.which("openssl")
if not openssl:
    raise SystemExit("OpenSSL is required for this one-time setup.")

with tempfile.TemporaryDirectory(prefix="whisper-bubble-signing-") as directory:
    temporary = Path(directory)
    certificate = temporary / "certificate.pem"
    private_key = temporary / "private.pem"
    package = temporary / "identity.p12"
    run([openssl, "req", "-new", "-x509", "-newkey", "rsa:3072", "-nodes", "-sha256", "-days", "3650",
         "-subj", f"/CN={NAME}", "-keyout", str(private_key), "-out", str(certificate),
         "-addext", "basicConstraints=critical,CA:FALSE",
         "-addext", "keyUsage=critical,digitalSignature",
         "-addext", "extendedKeyUsage=critical,codeSigning"])
    password = secrets.token_urlsafe(32)
    run([openssl, "pkcs12", "-export", "-in", str(certificate), "-inkey", str(private_key),
         "-out", str(package), "-name", NAME, "-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES",
         "-macalg", "sha1", "-passout", "stdin"], input=password + "\n")
    run(["/usr/bin/security", "import", str(package), "-k", str(keychain), "-P", password,
         "-T", "/usr/bin/codesign"])
    print(f"Created persistent signing identity: {NAME}")
    print("Private key stored in your login Keychain; temporary key files removed.")
    print("Only codesign was added as an allowed signing tool. System trust was not changed.")
