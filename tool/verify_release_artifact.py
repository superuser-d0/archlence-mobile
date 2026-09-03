"""Checks a built release artifact before it is published, from the artifact itself.

Takes an `.aab` or an `.apk`. Both are checked, because they are signed by
DIFFERENT machinery and only one of them can be read the same way.

The release guard in `android/app/build.gradle.kts` refuses to BUILD a release
without a keystore. It cannot check what it built. This does the other half:
it opens the finished `.aab` and asks what certificate is actually inside it.

Two failures it catches that nothing else does:

  * **The wrong key.** `key.properties` naming a different keystore builds
    perfectly. Off Play there is no upload-key reset to fall back on: the key
    below IS the app signing key, so an APK published under a different one
    can never update the installs made from this one. The fingerprint is the
    one recorded in the roadmap's "The key that was on the other machine".
  * **The debug key.** The Flutter template signs release builds with the SDK's
    debug key so `flutter run --release` works out of the box. That key is
    identical on every machine on earth. `CN=Android Debug` on a published
    artifact is the one failure that looks exactly like success.

Nothing here needs the keystore's password: a certificate is public, it
travels inside anything it signs, and reading it out of the artifact is the
point — it reports what the build DID, not what a config file said it would.

    python3 tool/verify_release_artifact.py \\
        build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

APKs are what every channel outside Play takes -- GitHub Releases,
IzzyOnDroid, F-Droid -- so this is the one that gets run in practice. An
`.aab` is Play's format and nothing else accepts it.

WHY AN APK CANNOT BE READ LIKE A BUNDLE. A bundle is a JAR: its certificate
sits in `META-INF/*.RSA` and `keytool` prints it. An APK signed for
`minSdk 24` normally has NO such entry at all -- AGP skips v1 (JAR) signing
once the minimum SDK understands v2, so the signature lives in the APK
Signing Block instead. Reading an APK the way this script first read bundles
would have called a perfectly good release UNSIGNED. `apksigner` is the tool
that knows all of v1, v2, v3 and v4, so APKs go through it.

Exits non-zero and says why if anything is off. `--fingerprint` overrides the
expected value, for the day the upload key is rotated; when it is, change the
constant here and the roadmap together.
"""

from __future__ import annotations

import argparse
import os
import glob
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
parser.add_argument(
    "artifact", help="path to an .apk or .aab built for release"
)
parser.add_argument("--fingerprint", default=EXPECTED_SHA256)
args = parser.parse_args()

if not os.path.isfile(args.artifact):
    raise SystemExit(f"no such artifact: {args.artifact}")

keytool = shutil.which("keytool")
if keytool is None:
    java_home = os.environ.get("JAVA_HOME", "")
    candidate = os.path.join(java_home, "bin", "keytool")
    keytool = candidate if java_home and os.path.isfile(candidate) else None
if keytool is None:
    raise SystemExit("keytool not found -- set JAVA_HOME or put it on PATH")

problems: list[str] = []
is_apk = args.artifact.lower().endswith(".apk")


def _apk_certificate(path: str) -> str:
    """`apksigner verify --print-certs`, which understands v1 through v4."""
    apksigner = shutil.which("apksigner")
    if apksigner is None:
        sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
        found = sorted(glob.glob(os.path.join(sdk or "", "build-tools", "*", "apksigner")))
        apksigner = found[-1] if found else None
    if apksigner is None:
        raise SystemExit(
            "apksigner not found -- set ANDROID_HOME or put it on PATH. It "
            "lives in the SDK's build-tools, and an APK cannot be verified "
            "without it: a minSdk-24 APK has no META-INF certificate to read."
        )
    result = subprocess.run(
        [apksigner, "verify", "--print-certs", "--verbose", path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise SystemExit(
            f"{path} did not verify as a signed APK:\n{result.stdout}{result.stderr}"
        )
    return result.stdout


def _bundle_certificate(path: str) -> str:
    """A bundle is a JAR: its certificate is an entry, and keytool prints it."""
    keytool = shutil.which("keytool")
    if keytool is None:
        java_home = os.environ.get("JAVA_HOME", "")
        candidate = os.path.join(java_home, "bin", "keytool")
        keytool = candidate if java_home and os.path.isfile(candidate) else None
    if keytool is None:
        raise SystemExit("keytool not found -- set JAVA_HOME or put it on PATH")

    with zipfile.ZipFile(path) as bundle:
        names = bundle.namelist()
        blocks = [
            n for n in names
            if re.fullmatch(r"META-INF/[^/]+\.(RSA|DSA|EC)", n)
        ]
        if not blocks:
            raise SystemExit(
                f"{path} carries no signature block at all. It is UNSIGNED.\n"
                "A build that failed can leave one of these behind; check that "
                "the build you meant to use actually succeeded."
            )
        if len(blocks) > 1:
            problems.append(f"{len(blocks)} signature blocks, expected 1: {blocks}")
        if not any(
            n.startswith("BUNDLE-METADATA/com.android.tools/r8") for n in names
        ):
            problems.append("no r8 metadata -- was this built as a release?")
        with tempfile.NamedTemporaryFile(suffix=".der", delete=False) as handle:
            handle.write(bundle.read(blocks[0]))
            cert_path = handle.name

    try:
        return subprocess.run(
            [keytool, "-printcert", "-file", cert_path],
            capture_output=True, text=True, check=True,
        ).stdout
    finally:
        os.unlink(cert_path)


printed = _apk_certificate(args.artifact) if is_apk else _bundle_certificate(
    args.artifact
)

if is_apk:
    # apksigner prints "Signer #1 certificate DN: ..." and
    # "Signer #1 certificate SHA-256 digest: <hex, no colons>".
    owner = next(
        (l.split(":", 1)[1].strip() for l in printed.splitlines()
         if "certificate DN:" in l),
        "",
    )
    found = next(
        (l.split(":", 1)[1].strip() for l in printed.splitlines()
         if "SHA-256 digest:" in l),
        "",
    )
    schemes = [
        name
        for name, line in (
            ("v1", "Verified using v1 scheme"),
            ("v2", "Verified using v2 scheme"),
            ("v3", "Verified using v3 scheme"),
            ("v4", "Verified using v4 scheme"),
        )
        if f"{line} (" in printed
        and printed.split(line, 1)[1].split("\n", 1)[0].strip().endswith("true")
    ]
    signers = next(
        (l.split(":", 1)[1].strip() for l in printed.splitlines()
         if l.startswith("Number of signers")),
        "?",
    )
    valid = f"schemes {'+'.join(schemes) or 'NONE'}, {signers} signer(s)"
    # A release must be readable by the phones this app supports. v2 is what
    # minSdk 24 relies on; its absence would mean an APK signed only the old
    # way, which newer Android rejects outright.
    if "Verified using v2 scheme" not in printed and (
        "Verified using v3 scheme" not in printed
    ):
        problems.append(
            "signed with neither the v2 nor the v3 scheme -- "
            f"apksigner reported:\n{printed.strip()}"
        )
else:
    owner = next((l.split(":", 1)[1].strip() for l in printed.splitlines()
                  if l.startswith("Owner:")), "")
    found = next((l.split("SHA256:", 1)[1].strip() for l in printed.splitlines()
                  if "SHA256:" in l), "")
    valid = next((l.split("Valid from:", 1)[1].strip()
                  for l in printed.splitlines()
                  if l.startswith("Valid from:")), "")

print(f"artifact    {args.artifact}")
print(f"format      {'APK' if is_apk else 'App Bundle'}")
print(f"owner       {owner}")
print(f"validity    {valid}")
print(f"sha256      {found}")

if "CN=Android Debug" in owner:
    problems.append(
        "signed with the SDK's DEBUG key. That key ships with the SDK and is "
        "identical on every machine on earth, so anyone at all can build an "
        "update for an app carrying it -- and a real key can never replace it "
        "afterwards."
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
