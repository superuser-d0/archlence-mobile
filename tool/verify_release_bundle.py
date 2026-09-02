"""Checks a built App Bundle before it is uploaded, from the artifact itself.

The release guard in `android/app/build.gradle.kts` refuses to BUILD a release
without a keystore. It cannot check what it built. This does the other half:
it opens the finished `.aab` and asks what certificate is actually inside it.

Two failures it catches that nothing else does:

  * **The wrong key.** `key.properties` naming a different keystore builds
    perfectly and produces a bundle Play refuses with "signed with the wrong
    key" — or worse, accepts under a different app. The fingerprint below is
    the one recorded in the roadmap's "The key that was on the other machine",
    and is what a Play upload key reset asks for.
  * **The debug key.** The Flutter template signs release builds with the SDK's
    debug key so `flutter run --release` works out of the box. That key is
    identical on every machine on earth. `CN=Android Debug` in a release
    bundle is the one failure that looks exactly like success.

Nothing here needs the keystore's password: a certificate is public, it
travels inside anything it signs, and reading it out of the artifact is the
point — it reports what the build DID, not what a config file said it would.

    python3 tool/verify_release_bundle.py \\
        build/app/outputs/bundle/release/app-release.aab

Exits non-zero and says why if anything is off. `--fingerprint` overrides the
expected value, for the day the upload key is rotated; when it is, change the
constant here and the roadmap together.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

# The release certificate, from the roadmap. Not a secret -- anyone can read
# it out of a published artifact -- and written here so a wrong key is caught
# by a machine rather than by Play.
EXPECTED_SHA256 = (
    "DF:1C:75:A4:0F:C6:51:92:32:E7:91:E0:37:0E:EE:C3:"
    "BD:1C:DB:62:17:E3:B3:6D:2E:74:EE:68:9F:78:6E:6B"
)
EXPECTED_OWNER_CN = "Superuser-d0"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("bundle", help="path to app-release.aab")
parser.add_argument("--fingerprint", default=EXPECTED_SHA256)
args = parser.parse_args()

if not os.path.isfile(args.bundle):
    raise SystemExit(f"no such bundle: {args.bundle}")

keytool = shutil.which("keytool")
if keytool is None:
    java_home = os.environ.get("JAVA_HOME", "")
    candidate = os.path.join(java_home, "bin", "keytool")
    keytool = candidate if java_home and os.path.isfile(candidate) else None
if keytool is None:
    raise SystemExit("keytool not found -- set JAVA_HOME or put it on PATH")

problems: list[str] = []

with zipfile.ZipFile(args.bundle) as bundle:
    names = bundle.namelist()

    # 1. Signed at all. An unsigned bundle is structurally valid and
    #    `bundletool validate` accepts it, so its absence must be checked
    #    rather than assumed -- see "The release guard fired too late".
    blocks = [
        n for n in names
        if re.fullmatch(r"META-INF/[^/]+\.(RSA|DSA|EC)", n)
    ]
    if not blocks:
        raise SystemExit(
            f"{args.bundle} carries no signature block at all. It is UNSIGNED.\n"
            "A build that failed can leave one of these behind; check that the "
            "build you meant to use actually succeeded."
        )
    if len(blocks) > 1:
        problems.append(f"{len(blocks)} signature blocks, expected 1: {blocks}")

    # 2. R8. Its absence is not proof of anything on its own, but its
    #    presence is proof the release pipeline ran as a release.
    if not any(n.startswith("BUNDLE-METADATA/com.android.tools/r8") for n in names):
        problems.append("no r8 metadata -- was this built as a release?")

    with tempfile.NamedTemporaryFile(suffix=".der", delete=False) as handle:
        handle.write(bundle.read(blocks[0]))
        cert_path = handle.name

try:
    printed = subprocess.run(
        [keytool, "-printcert", "-file", cert_path],
        capture_output=True, text=True, check=True,
    ).stdout
finally:
    os.unlink(cert_path)

owner = next((l.split(":", 1)[1].strip() for l in printed.splitlines()
              if l.startswith("Owner:")), "")
found = next((l.split("SHA256:", 1)[1].strip() for l in printed.splitlines()
              if "SHA256:" in l), "")
valid = next((l.split("Valid from:", 1)[1].strip() for l in printed.splitlines()
              if l.startswith("Valid from:")), "")

print(f"bundle      {args.bundle}")
print(f"signature   {blocks[0]}")
print(f"owner       {owner}")
print(f"validity    {valid}")
print(f"sha256      {found}")

if "CN=Android Debug" in owner:
    problems.append(
        "signed with the SDK's DEBUG key. That key is identical on every "
        "machine; Play refuses it and an app carrying it can never be updated "
        "by a real one."
    )
elif f"CN={EXPECTED_OWNER_CN}" not in owner:
    problems.append(f"owner is {owner!r}, expected CN={EXPECTED_OWNER_CN}")

def normalise(value: str) -> str:
    return value.replace(":", "").replace(" ", "").upper()

if normalise(found) != normalise(args.fingerprint):
    problems.append(
        f"certificate is NOT the expected one.\n"
        f"    expected  {args.fingerprint}\n"
        f"    found     {found}"
    )

if problems:
    print()
    for problem in problems:
        print(f"FAIL  {problem}")
    sys.exit(1)

print("\nSigned by the expected release certificate.")
