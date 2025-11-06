import os
import sqlite3
import hashlib
import binascii
import datetime

# Use a single DB file shared by homepage.py and dashboard.py
DB_PATH = os.path.join(os.path.dirname(__file__), "inventory.db")


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# ---------------- Users (auth) ----------------
def _hash_password(password: str) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256. Store as salt$hash (hex)."""
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100_000)
    return f"{binascii.hexlify(salt).decode('ascii')}${binascii.hexlify(dk).decode('ascii')}"


def _verify_password(stored: str, password: str) -> bool:
    try:
        salt_hex, hash_hex = stored.split("$")
    except ValueError:
        return False
    salt = binascii.unhexlify(salt_hex)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100_000)
    return binascii.hexlify(dk).decode("ascii") == hash_hex


def create_user(name: str, email: str, password: str, position: str = None) -> int:
    """Create a new user and return id. Raises ValueError on validation/uniqueness errors."""
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
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE name = ?", (name,))
    row = cur.fetchone()
    conn.close()
    return row


def get_user_by_email(email: str):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE email = ?", (email,))
    row = cur.fetchone()
    conn.close()
    return row


def verify_user_credentials(name_or_email: str, password: str):
    """Verify credentials (accepts name or email). Return user Row on success, else None."""
    user = get_user_by_name(name_or_email)
    if not user:
        user = get_user_by_email(name_or_email)
    if not user:
        return None
    if _verify_password(user["password"], password):
        return user
    return None


# ---------------- Products ----------------
def insert_product(product: str, quantity: int, status: str) -> int:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO products (product, quantity, status) VALUES (?, ?, ?)",
        (product, quantity, status),
    )
    conn.commit()
    last_id = cur.lastrowid
    conn.close()
    return last_id


def fetch_products():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, product, quantity, status FROM products")
    rows = cur.fetchall()
    conn.close()
    return [{"id": r["id"], "product": r["product"], "quantity": r["quantity"], "status": r["status"]} for r in rows]


def update_product(product_id: int, product: str, quantity: int, status: str) -> None:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "UPDATE products SET product = ?, quantity = ?, status = ? WHERE id = ?",
        (product, quantity, status, product_id),
    )
    conn.commit()
    conn.close()


def delete_product(product_id: int) -> None:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM products WHERE id = ?", (product_id,))
    conn.commit()
    conn.close()


# ---------------- Initialization ----------------
def init_db():
    """Create users and products tables if missing and ensure default admin exists."""
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
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            status TEXT NOT NULL
        )
        """
    )
    conn.commit()
    conn.close()

    # ensure default admin exists
    if not get_user_by_name("admin"):
        try:
            create_user("admin", "admin@example.com", "1234", "Admin")
            # default admin created
        except Exception:
            # ignore race/duplicate errors
            pass