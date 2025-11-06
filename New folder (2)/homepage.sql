import customtkinter as ctk  # pyright: ignore[reportMissingImports]
from tkinter import messagebox
import subprocess
import sys
import sqlite3
import hashlib
import os

# Database file for users
DB_FILE = "users.db"


def hash_password(password: str) -> str:
    """Return a SHA-256 hex digest for the given password."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def init_db():
    """Create users table if it doesn't exist and add a default admin if DB is empty."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            position TEXT NOT NULL
        )
        """
    )
    conn.commit()

    # If there are no users, create a default admin account (admin / 1234)
    cursor.execute("SELECT COUNT(*) FROM users")
    count = cursor.fetchone()[0]
    if count == 0:
        try:
            cursor.execute(
                "INSERT INTO users (name, email, password, position) VALUES (?, ?, ?, ?)",
                ("admin", "admin@example.com", hash_password("1234"), "Admin"),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            pass
    conn.close()


def create_user(name: str, email: str, password: str, position: str) -> (bool, str):
    """Insert a new user into the DB. Returns (success, message)."""
    if not (name and email and password and position):
        return False, "All fields are required."

    hashed = hash_password(password)
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO users (name, email, password, position) VALUES (?, ?, ?, ?)",
            (name, email, hashed, position),
        )
        conn.commit()
        conn.close()
        return True, "User created successfully."
    except sqlite3.IntegrityError as e:
        # Unique constraint failed for name or email
        msg = str(e).lower()
        if "name" in msg or "unique" in msg and "name" in msg:
            return False, "Username already exists."
        if "email" in msg or "unique" in msg and "email" in msg:
            return False, "Email already registered."
        return False, "User creation failed: " + str(e)
    except Exception as e:
        return False, "Error: " + str(e)


def get_user_by_name(name: str):
    """Return user row dict or None by username."""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("SELECT id, name, email, password, position FROM users WHERE name = ?", (name,))
    row = cursor.fetchone()
    conn.close()
    if not row:
        return None
    return {"id": row[0], "name": row[1], "email": row[2], "password": row[3], "position": row[4]}


def verify_user(name: str, password: str) -> bool:
    """Return True if credentials match a user in DB."""
    user = get_user_by_name(name)
    if not user:
        return False
    return user["password"] == hash_password(password)


# App Setup
ctk.set_appearance_mode("light")
ctk.set_default_color_theme("blue")

app = ctk.CTk()
app.title("Inventory Management System")
app.geometry("1000x700")
app.resizable(True, True)

# Container for Frames
container = ctk.CTkFrame(app, fg_color="white")
container.pack(expand=True, fill="both")


def show_login():
    signup_frame.pack_forget()
    login_frame.pack(expand=True, fill="both")


def show_signup():
    login_frame.pack_forget()
    signup_frame.pack(expand=True, fill="both")


# Login Page
login_frame = ctk.CTkFrame(container, fg_color="white")

login_title = ctk.CTkLabel(login_frame, text="LOGIN", text_color="black", font=("Helvetica", 28, "bold"))
login_title.pack(pady=(40, 10))

login_subtitle = ctk.CTkLabel(login_frame, text="Don’t have an account?", text_color="black", font=("Arial", 12))
login_subtitle.pack()

signup_link = ctk.CTkLabel(login_frame, text="Sign Up", text_color="blue", font=("Arial", 12, "bold"), cursor="hand2")
signup_link.pack(pady=(0, 30))
signup_link.bind("<Button-1>", lambda e: show_signup())

# Username
username_label = ctk.CTkLabel(login_frame, text="NAME", text_color="gray", font=("Arial", 10, "bold"))
username_label.pack(padx=90)
username_entry = ctk.CTkEntry(login_frame, width=250, height=35, corner_radius=0, border_width=1, border_color="black")
username_entry.pack(pady=(5, 20))

# Password
password_label = ctk.CTkLabel(login_frame, text="PASSWORD", text_color="gray", font=("Arial", 10, "bold"))
password_label.pack(padx=90)
password_entry = ctk.CTkEntry(login_frame, width=250, height=35, corner_radius=0, border_width=1, border_color="black", show="*")
password_entry.pack(pady=(5, 20))


# Login Function (now uses DB)
def login():
    username = username_entry.get().strip()
    password = password_entry.get().strip()

    if not username or not password:
        messagebox.showerror("Login Failed", "Please enter both username and password.")
        return

    if verify_user(username, password):
        messagebox.showinfo("Login Success", f"Welcome, {username}!")
        app.destroy()  # close login window
        # run dashboard.py in same interpreter
        subprocess.run([sys.executable, "dashboard.py"])
    else:
        messagebox.showerror("Login Failed", "Invalid username or password.")


login_button = ctk.CTkButton(login_frame, text="LOGIN", width=100, height=35, fg_color="black",
                             hover_color="#333", text_color="white", command=login)
login_button.pack(pady=20)

# Signup Page
signup_frame = ctk.CTkFrame(container, fg_color="white")

signup_title = ctk.CTkLabel(signup_frame, text="CREATE NEW ACCOUNT", text_color="black", font=("Helvetica", 24, "bold"))
signup_title.pack(pady=(40, 5))

already_label = ctk.CTkLabel(signup_frame, text="Already Registered?", text_color="black", font=("Arial", 12))
already_label.pack()

login_link = ctk.CTkLabel(signup_frame, text="Login", text_color="blue", font=("Arial", 12, "bold"), cursor="hand2")
login_link.pack(pady=(0, 30))
login_link.bind("<Button-1>", lambda e: show_login())

# Name
name_label = ctk.CTkLabel(signup_frame, text="NAME", text_color="gray", font=("Arial", 10, "bold"))
name_label.pack(padx=90)
name_entry = ctk.CTkEntry(signup_frame, width=250, height=35, corner_radius=0, border_width=1, border_color="black")
name_entry.pack(pady=(5, 20))

# Email
email_label = ctk.CTkLabel(signup_frame, text="EMAIL", text_color="gray", font=("Arial", 10, "bold"))
email_label.pack(padx=90)
email_entry = ctk.CTkEntry(signup_frame, width=250, height=35, corner_radius=0, border_width=1, border_color="black")
email_entry.pack(pady=(5, 20))

# Password
signup_password_label = ctk.CTkLabel(signup_frame, text="PASSWORD", text_color="gray", font=("Arial", 10, "bold"))
signup_password_label.pack(padx=90)
signup_password_entry = ctk.CTkEntry(signup_frame, width=250, height=35, corner_radius=0, border_width=1, border_color="black", show="*")
signup_password_entry.pack(pady=(5, 20))

# Position Dropdown
position_label = ctk.CTkLabel(signup_frame, text="POSITION", text_color="gray", font=("Arial", 10, "bold"))
position_label.pack(padx=90)
position_option = ctk.CTkOptionMenu(signup_frame, values=["Admin", "Manager", "Staff"], fg_color="white", text_color="black", button_color="black", dropdown_text_color="black")
position_option.pack(pady=(5, 20))
# Give a sensible default
position_option.set("Staff")


# Signup Button (now creates DB user)
def signup():
    name = name_entry.get().strip()
    email = email_entry.get().strip()
    password = signup_password_entry.get().strip()
    position = position_option.get().strip()

    success, msg = create_user(name, email, password, position)
    if success:
        messagebox.showinfo("Success", f"Account created for {name}!")
        # after signup, go to login page
        name_entry.delete(0, "end")
        email_entry.delete(0, "end")
        signup_password_entry.delete(0, "end")
        position_option.set("Staff")
        show_login()
    else:
        messagebox.showerror("Error", msg)


signup_button = ctk.CTkButton(signup_frame, text="SIGN UP", width=100, height=35,
                              fg_color="black", hover_color="#333", text_color="white",
                              command=signup)
signup_button.pack(pady=20)

# Default Page
login_frame.pack(expand=True, fill="both")

# Back Button
def go_back():
    app.destroy()  # Close this window


back_btn = ctk.CTkButton(
    container,
    text="BACK",
    width=80,
    height=30,
    fg_color="red",
    hover_color="#333",
    command=go_back)

# Place the button at the bottom-right corner
back_btn.place(relx=0.95, rely=0.95, anchor="se")


# Initialize DB and ensure default admin exists
init_db()

app.mainloop()