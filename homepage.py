import customtkinter as ctk
from tkinter import messagebox
import subprocess
import sys

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

# Login Function
def login():
    username = username_entry.get()
    password = password_entry.get()
    if username == "admin" and password == "1234":
        messagebox.showinfo("Login Success", f"Welcome, {username}!")
        app.destroy()  # close login window
        subprocess.run([sys.executable, "dashboard.py"])  # open inventory system
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

# Signup Button
def signup():
    name = name_entry.get()
    email = email_entry.get()
    password = signup_password_entry.get()
    position = position_option.get()

    if not name or not email or not password:
        messagebox.showerror("Error", "Please fill in all fields.")
    else:
        messagebox.showinfo("Success", f"Account created for {name}!")

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

app.mainloop()