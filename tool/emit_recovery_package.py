"""Writes a REAL key recovery package using the desktop's own service, and
reads a mobile-written one back with it.

`lib/backup/key_recovery_service.dart` is a port of a parser fed untrusted
input, and the only way to know it reads the desktop's packages is to hand it
one the desktop actually wrote — not one assembled here from a reading of the
format. The second direction matters just as much: a user who exports a key on
the phone has to be able to use it on the desktop.

    cd <desktop checkout>
    ./aeadvenv/bin/python <mobile>/tool/emit_recovery_package.py \
        <mobile>/test/desktop_key_recovery.json

    # and, to check the traffic the other way:
    ./aeadvenv/bin/python <mobile>/tool/emit_recovery_package.py \
        <mobile>/test/desktop_key_recovery.json --verify <mobile-written.json>

The passphrase and the key are FIXED so the Dart test can assert the exact
bytes that come back out, rather than only that something 32 bytes long did.
The salt and nonce still come from the desktop's own `os.urandom`, so the file
is not reproducible byte for byte and is committed rather than regenerated.

`keyring` is deliberately NOT installed in that venv: without it the desktop's
provider falls back to a file, and the key this script writes is the key it
uses. With a Secret Service available it would pick up the developer's own.
"""
import json
import os
import shutil
import sys
import tempfile

PASSPHRASE = "desktop-written-recovery"
KEY = bytes(range(32))

args = [a for a in sys.argv[1:] if not a.startswith("--")]
verify_index = sys.argv.index("--verify") if "--verify" in sys.argv else None
mobile_package = sys.argv[verify_index + 1] if verify_index is not None else None
if len(args) < 1:
    raise SystemExit(__doc__)
destination = os.path.abspath(args[0])

sys.path.insert(0, os.getcwd())

home = tempfile.mkdtemp(prefix="archlence-emit-")
os.environ["ARCHLENCE_HOME"] = home
try:
    from utils.app_paths import data_dir
    from utils.key_provider import FileKeyProvider

    os.makedirs(data_dir(), exist_ok=True)
    provider = FileKeyProvider(os.path.join(data_dir(), "encryption.key"))
    provider.store_key(KEY)

    from services import key_recovery_service as krs

    krs.export_recovery_package(destination, PASSPHRASE, provider)

    # Read it back THROUGH THE PUBLIC ENTRY POINT, so what is committed is
    # proven rather than the staging copy it was built from.
    assert krs.read_recovery_package(destination, PASSPHRASE) == KEY, (
        "the package does not carry the fixed key"
    )
    payload = json.loads(open(destination, encoding="utf-8").read())
    assert payload["format"] == "archlence-key-recovery-v1", payload["format"]
    print(f"wrote {destination}")
    print(f"  fingerprint {payload['key_fingerprint']}")

    if mobile_package:
        # The other direction: a package the PHONE wrote, opened by the
        # desktop's own reader. This is the half a Dart test cannot speak for.
        recovered = krs.read_recovery_package(
            os.path.abspath(mobile_package), PASSPHRASE
        )
        assert recovered == KEY, "the mobile package does not carry the key"
        print(f"read back {mobile_package}: the desktop opens what the phone wrote")
finally:
    shutil.rmtree(home, ignore_errors=True)
