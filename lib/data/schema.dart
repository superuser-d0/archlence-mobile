/// The Archlence database schema, verbatim from the desktop app.
///
/// Generated from a database built by the desktop's own
/// `database.init_db.initialize_database()`, then dumped from
/// `sqlite_master`. It is NOT hand-written and must not be hand-edited:
/// the desktop's shape includes columns appended by past ALTER TABLE
/// migrations, which a re-declaration in Dart would not reproduce.
///
/// `test/desktop_schema.sql` holds the same dump as ground truth, and
/// `schema_parity_test.dart` proves a database created from the list
/// below is identical to it.
///
/// `sqlite_sequence` is omitted: SQLite creates it itself for
/// AUTOINCREMENT tables.
library;

const List<String> desktopSchemaStatements = [
  '''
CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance REAL DEFAULT 0,
            account_type TEXT NOT NULL DEFAULT 'checking',
            credit_limit REAL DEFAULT 0,
            statement_date INTEGER
        , card_number_full TEXT, expiry_date TEXT, cvc_code TEXT, masked_number TEXT, network_logo TEXT, is_frozen INTEGER DEFAULT 0, online_payments_enabled INTEGER DEFAULT 1)
''',
  '''
CREATE TABLE active_assets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_name TEXT NOT NULL,
            asset_code TEXT NOT NULL,
            asset_type TEXT NOT NULL DEFAULT 'Diğer',
            purchase_price TEXT NOT NULL,
            quantity TEXT NOT NULL,
            purchase_date TEXT
        )
''',
  '''
CREATE TABLE active_debts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            debt_name TEXT NOT NULL,
            total_amount TEXT NOT NULL,
            monthly_payment TEXT NOT NULL,
            total_installments INTEGER NOT NULL,
            paid_installments INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1
        , is_auto_pay INTEGER DEFAULT 0, auto_pay_day INTEGER DEFAULT 1, last_auto_pay_date TEXT)
''',
  '''
CREATE TABLE anomaly_dismissals (
            transaction_id INTEGER PRIMARY KEY,
            dismissed_at TEXT NOT NULL
        )
''',
  '''
CREATE TABLE asset_price_cache (
    symbol TEXT PRIMARY KEY,
    price REAL NOT NULL,
    asset_type TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    -- NULL olabilir: sütun eklenmeden önceki satırlar. Okuma tarafı bunu
    -- "Yahoo Finance"a çözer (o dönemde tek sağlayıcı oydu).
    source TEXT
)
''',
  '''
CREATE TABLE balance_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            delta REAL NOT NULL,
            resulting_value REAL,
            source TEXT,
            ref_id INTEGER
        )
''',
  '''
CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            importance TEXT DEFAULT 'extra'
        )
''',
  '''
CREATE TABLE daily_balance_snapshot (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_date TEXT NOT NULL UNIQUE,
            total_balance REAL NOT NULL,
            breakdown_json TEXT
        )
''',
  '''
CREATE TABLE financial_health_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            score REAL NOT NULL,
            breakdown_json TEXT
        )
''',
  '''
CREATE TABLE monthly_budget_plan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            target_month INTEGER DEFAULT 1,
            target_year INTEGER,
            category_name TEXT,
            rollover_enabled INTEGER DEFAULT 0,
            is_template INTEGER DEFAULT 0,
            alert_threshold_pct INTEGER DEFAULT 80
        )
''',
  '''
CREATE TABLE recurring_candidate_dismissals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            candidate_key TEXT NOT NULL,
            dismissed_at TEXT NOT NULL
        )
''',
  '''
CREATE TABLE recurring_operation_markers (
            recurring_payment_id INTEGER NOT NULL,
            due_date TEXT NOT NULL,
            operation_type TEXT NOT NULL,
            transaction_id INTEGER,
            PRIMARY KEY (recurring_payment_id, due_date, operation_type)
        )
''',
  '''
CREATE TABLE recurring_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            amount TEXT NOT NULL,
            category TEXT,
            frequency TEXT NOT NULL DEFAULT 'monthly',
            next_due_date TEXT NOT NULL,
            recurrence_day INTEGER CHECK (recurrence_day BETWEEN 1 AND 31),
            auto_deduct INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            account_id INTEGER DEFAULT 1,
            transaction_type TEXT NOT NULL DEFAULT 'expense'
        )
''',
  '''
CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL DEFAULT 0,
        target_date TEXT,
        status TEXT DEFAULT 'aktif',
        goal_uid TEXT NOT NULL,
        color TEXT,
        auto_deposit INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
    )
''',
  '''
CREATE TABLE savings_migration_quarantine (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quarantined_at TEXT NOT NULL,
            reason TEXT NOT NULL,
            source TEXT NOT NULL,
            legacy_id INTEGER,
            goal_name TEXT,
            target_amount REAL,
            current_amount REAL,
            payload TEXT,
            acknowledged INTEGER NOT NULL DEFAULT 0
        )
''',
  '''
CREATE TABLE savings_migration_state (
            marker TEXT PRIMARY KEY,
            completed_at TEXT NOT NULL,
            detail TEXT
        )
''',
  '''
CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER,
            amount TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT,
            description TEXT,
            transaction_date TEXT, status TEXT DEFAULT 'completed', execution_date TEXT,
            FOREIGN KEY(account_id) REFERENCES accounts(id)
        )
''',
  '''
CREATE INDEX idx_balance_events_ts ON balance_events(ts)
''',
  '''
CREATE UNIQUE INDEX idx_health_history_day
        ON financial_health_history(substr(date, 1, 10))
''',
  '''
CREATE UNIQUE INDEX idx_savings_goals_uid ON savings_goals(goal_uid)
''',
  '''
CREATE INDEX idx_transactions_account_id ON transactions(account_id)
''',
];
