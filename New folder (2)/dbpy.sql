import os
import sqlite3
import hashlib
import binascii
import datetime

# Path to the SQLite database file (same DB used by dashboard.py)
DB_PATH = os.path.join(os.path.dirname(__file__), "inventory.db")


def get_connection():
    """Return a sqlite3 connection with Row access."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Create the users table if it doesn't exist and ensure a default admin exists."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            position TEXT,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.commit()
    conn.close()

    # Ensure default admin exists
    if not get_user_by_name("admin"):
        try:
            create_user("admin", "admin@example.com", "1234", "Admin")
            print("Default admin user created (name: admin, password: 1234).")
        except Exception:
            # ignore concurrency / race issues creating admin
            pass


def _hash_password(password: str) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256. Returns salt$hash in hex."""
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100_000)
    salt_hex = binascii.hexlify(salt).decode("ascii")
    dk_hex = binascii.hexlify(dk).decode("ascii")
    return f"{salt_hex}${dk_hex}"


def _verify_password(stored: str, password: str) -> bool:
    """Verify a password against the stored salt$hash string."""
    try:
        salt_hex, hash_hex = stored.split("$")
    except ValueError:
        return False
    salt = binascii.unhexlify(salt_hex)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100_000)
    return binascii.hexlify(dk).decode("ascii") == hash_hex


def create_user(name: str, email: str, password: str, position: str = None) -> int:
    """Insert a new user. Returns the new user's id. Raises ValueError on error."""
    if not name or not email or not password:
        raise ValueError("Name, email and password are required.")
    hashed = _hash_password(password)
    created_at = datetime.datetime.utcnow().isoformat() + "Z"
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO users (name, email, password, position, created_at) VALUES (?, ?, ?, ?, ?)",
            (name, email, hashed, position, created_at),
        )
        conn.commit()
        user_id = cur.lastrowid
    except sqlite3.IntegrityError as e:
        conn.rollback()
        msg = str(e).lower()
        if "unique" in msg and "name" in msg:
            raise ValueError("A user with that name already exists.") from e
        if "unique" in msg and "email" in msg:
            raise ValueError("A user with that email already exists.") from e
        raise ValueError("Could not create user: " + str(e)) from e
    finally:
        conn.close()
    return user_id


def get_user_by_name(name: str):
    """Return a Row for the user with the given name, or None."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE name = ?", (name,))
    row = cur.fetchone()
    conn.close()
    return row


def get_user_by_email(email: str):
    """Return a Row for the user with the given email, or None."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE email = ?", (email,))
    row = cur.fetchone()
    conn.close()
    return row


def verify_user_credentials(name_or_email: str, password: str):
    """Verify credentials. Accepts either name or email. Returns user row on success, else None."""
    user = get_user_by_name(name_or_email)
    if not user:
        user = get_user_by_email(name_or_email)
    if not user:
        return None
    if _verify_password(user["password"], password):
        return user
    return None