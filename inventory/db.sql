import os
import hashlib
import binascii
import datetime
import mysql.connector
from mysql.connector import errorcode

# Configuration - override with environment variables in production
DB_HOST = os.environ.get("DB_HOST", "127.0.0.1")
DB_PORT = int(os.environ.get("DB_PORT", 3306))
DB_USER = os.environ.get("DB_USER", "inventory_user")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "inventory_pass")
DB_NAME = os.environ.get("DB_NAME", "inventory_db")

# Helper to get a connection (connected to the target database)
def get_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        autocommit=False,
    )

# Helper to get a server-level connection (no database) for creating DB if needed
def get_server_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        autocommit=True,
    )

# ---------------- Password hashing ----------------
def _hash_password(password: str) -> str:
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

# ---------------- Database initialization ----------------
def ensure_database_exists():
    """Create the database (DB_NAME) if it does not exist."""
    try:
        conn = get_server_connection()
        cur = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        cur.close()
        conn.close()
    except mysql.connector.Error as e:
        raise RuntimeError(f"Could not ensure database exists: {e}")

def init_db():
    """Create required tables if missing and ensure default admin exists."""
    ensure_database_exists()
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        # Users table
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(150) NOT NULL UNIQUE,
                email VARCHAR(255) NOT NULL UNIQUE,
                password VARCHAR(512) NOT NULL,
                position VARCHAR(50),
                created_at DATETIME NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """
        )
        # Products table
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS products (
                id INT AUTO_INCREMENT PRIMARY KEY,
                product VARCHAR(255) NOT NULL,
                quantity INT NOT NULL,
                status VARCHAR(50) NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """
        )
        conn.commit()
        cur.close()
    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()

    # Ensure default admin account exists
    try:
        if not get_user_by_name("admin"):
            create_user("admin", "admin@example.com", "1234", "Admin")
    except Exception:
        # ignore creation race or other small errors
        pass

# ---------------- Users (auth) ----------------
def create_user(name: str, email: str, password: str, position: str = None) -> int:
    if not name or not email or not password:
        raise ValueError("Name, email and password are required.")
    hashed = _hash_password(password)
    created_at = datetime.datetime.utcnow()
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO users (name, email, password, position, created_at) VALUES (%s, %s, %s, %s, %s)",
            (name, email, hashed, position, created_at),
        )
        conn.commit()
        user_id = cur.lastrowid
        cur.close()
        return user_id
    except mysql.connector.IntegrityError as e:
        conn.rollback()
        msg = str(e).lower()
        if "duplicate" in msg and "name" in msg:
            raise ValueError("A user with that name already exists.") from e
        if "duplicate" in msg and "email" in msg:
            raise ValueError("A user with that email already exists.") from e
        raise ValueError("Could not create user: " + str(e)) from e
    finally:
        conn.close()

def get_user_by_name(name: str):
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT id, name, email, password, position, created_at FROM users WHERE name = %s", (name,))
        row = cur.fetchone()
        cur.close()
        return row
    finally:
        conn.close()

def get_user_by_email(email: str):
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT id, name, email, password, position, created_at FROM users WHERE email = %s", (email,))
        row = cur.fetchone()
        cur.close()
        return row
    finally:
        conn.close()

def verify_user_credentials(name_or_email: str, password: str):
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
    try:
        cur = conn.cursor()
        cur.execute("INSERT INTO products (product, quantity, status) VALUES (%s, %s, %s)", (product, quantity, status))
        conn.commit()
        last_id = cur.lastrowid
        cur.close()
        return last_id
    finally:
        conn.close()

def fetch_products():
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT id, product, quantity, status FROM products")
        rows = cur.fetchall()
        cur.close()
        return [{"id": r["id"], "product": r["product"], "quantity": r["quantity"], "status": r["status"]} for r in rows]
    finally:
        conn.close()

def update_product(product_id: int, product: str, quantity: int, status: str) -> None:
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE products SET product=%s, quantity=%s, status=%s WHERE id=%s", (product, quantity, status, product_id))
        conn.commit()
        cur.close()
    finally:
        conn.close()

def delete_product(product_id: int) -> None:
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM products WHERE id=%s", (product_id,))
        conn.commit()
        cur.close()
    finally:
        conn.close()