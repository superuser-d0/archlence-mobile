"""Writes a REAL backup package using the desktop's own `create_backup`.

The reader in `lib/backup/` is a port of an untrusted-input parser, and the
only way to know it reads the desktop's packages is to hand it one the desktop
actually wrote — not one assembled here from a reading of the format.

    cd <desktop checkout>
    python3 -m venv aeadvenv
    ./aeadvenv/bin/pip install pycryptodome platformdirs
    ./aeadvenv/bin/python <mobile>/tool/emit_backup_package.py \
        <mobile>/test/desktop_backup.archlence-backup

The passphrase and the encryption key are FIXED (see the constants below) so
the Dart test can assert the exact key that comes back out of the package,
rather than only that something 32 bytes long did. Everything random in the
package — the recovery salt and nonce, the authentication salt — still comes
from the desktop's own code, so the file is not reproducible byte for byte and
is committed rather than regenerated on each run.

`keyring` is deliberately NOT installed in that venv: without it the desktop's
`create_platform_key_provider` falls back to the file provider, and the key
this script writes is the key its encryption uses. With a Secret Service
available it would pick up whatever the developer's session keyring holds.
"""
import os
import shutil
import sys
import tempfile

PASSPHRASE = "desktop-written-backup"
KEY = bytes(range(32))

if len(sys.argv) != 2:
    raise SystemExit(__doc__)
destination = os.path.abspath(sys.argv[1])

sys.path.insert(0, os.getcwd())

home = tempfile.mkdtemp(prefix="archlence-emit-")
os.environ["ARCHLENCE_HOME"] = home
try:
    from utils.app_paths import data_dir
    from utils.key_provider import FileKeyProvider

    os.makedirs(data_dir(), exist_ok=True)
    FileKeyProvider(os.path.join(data_dir(), "encryption.key")).store_key(KEY)

    # Imported only after the key is in place: `database.db` resolves DB_NAME
    # from `data_dir()` at import time.
    from database.db import DB_NAME, get_connection
    from database.init_db import initialize_database
    from services import backup_service as bs
    from utils.crypto import encrypt

    initialize_database()
    assert bs.verify_database_key(DB_NAME, KEY) == 0, (
        "a fresh database should have no encrypted rows"
    )

    conn = get_connection()
    with conn:
        conn.execute(
            "INSERT INTO accounts (name, type, balance, account_type) "
            "VALUES (?, ?, ?, ?)",
            ("Vadesiz", "asset", 1500.0, "checking"),
        )
        # Every table in ENCRYPTED_FIELDS that the mobile app reads, so the
        # count in the metadata is not one table's worth.
        conn.execute(
            "INSERT INTO transactions (account_id, amount, type, category, "
            "description, transaction_date, status) VALUES (?,?,?,?,?,?,?)",
            (1, encrypt("1234.56"), "expense", "Market",
             encrypt("haftalık alışveriş"), "2026-08-20 10:00:00", "completed"),
        )
        # A blank description: it passes through UNENCRYPTED, and a reader
        # that counted it would disagree with the desktop about the total.
        conn.execute(
            "INSERT INTO transactions (account_id, amount, type, category, "
            "description, transaction_date, status) VALUES (?,?,?,?,?,?,?)",
            (1, encrypt("89.90"), "expense", "Ulaşım", "",
             "2026-08-21 08:30:00", "completed"),
        )
        conn.execute(
            "INSERT INTO active_debts (debt_name, total_amount, "
            "monthly_payment, total_installments) VALUES (?,?,?,?)",
            (encrypt("Buzdolabı"), encrypt("12000.00"), encrypt("1000.00"), 12),
        )
        conn.execute(
            "INSERT INTO active_assets (asset_name, asset_code, asset_type, "
            "purchase_price, quantity, purchase_date) VALUES (?,?,?,?,?,?)",
            ("Altın", "GRAM-ALTIN", "Emtia", encrypt("2450.00"),
             encrypt("3"), "2026-07-01"),
        )
        conn.execute(
            "INSERT INTO recurring_payments (name, amount, category, "
            "frequency, next_due_date, recurrence_day, account_id, "
            "transaction_type) VALUES (?,?,?,?,?,?,?,?)",
            (encrypt("Netflix"), encrypt("229.99"), "Dijital Abonelik",
             "monthly", "2026-09-05", 5, 1, "expense"),
        )
        conn.execute(
            "INSERT INTO savings_goals (goal_name, target_amount, "
            "current_amount, goal_uid, created_at) VALUES (?,?,?,?,?)",
            (encrypt("Tatil"), 50000.0, 7500.0, "emit-fixture-uid",
             "2026-06-01 12:00:00"),
        )
    conn.close()

    result = bs.create_backup(
        destination,
        PASSPHRASE,
        db_path=DB_NAME,
        key_path=os.path.join(data_dir(), "encryption.key"),
    )
    # `create_backup` verifies before it returns, so reaching here means the
    # desktop can read what it wrote. Read it once more THROUGH THE PUBLIC
    # ENTRY POINT so the committed file is proven, not just the staging copy.
    verified = bs.verify_backup(destination, PASSPHRASE)
    assert verified["key"] == KEY, "the package does not carry the fixed key"

    print("wrote      %s" % destination)
    print("passphrase %s" % PASSPHRASE)
    print("aead rows  %d" % result["aead_records_verified"])
    print("db sha256  %s" % result["database_sha256"])
finally:
    shutil.rmtree(home, ignore_errors=True)
