import customtkinter as ctk  # pyright: ignore[reportMissingImports]
from tkinter import ttk, messagebox, filedialog
import matplotlib.pyplot as plt  # pyright: ignore[reportMissingModuleSource]
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg  # pyright: ignore[reportMissingModuleSource]
import sqlite3
import csv

# Database file
DB_FILE = "inventory.db"

# App Setup
ctk.set_appearance_mode("light")
ctk.set_default_color_theme("blue")

app = ctk.CTk()
app.title("Inventory Management System")
app.geometry("1000x700")
app.resizable(True, True)

# Global Variables
product_data = []
selected_item = None  # Treeview iid (string) of the selected product


# ----------------- Database helpers -----------------
def init_db():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute(
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


def fetch_products():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("SELECT id, product, quantity, status FROM products")
    rows = cursor.fetchall()
    conn.close()
    return [{"id": r[0], "product": r[1], "quantity": r[2], "status": r[3]} for r in rows]


def insert_product_db(product, quantity, status):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO products (product, quantity, status) VALUES (?, ?, ?)",
        (product, quantity, status),
    )
    conn.commit()
    last_id = cursor.lastrowid
    conn.close()
    return last_id


def update_product_db(product_id, product, quantity, status):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE products SET product=?, quantity=?, status=? WHERE id=?",
        (product, quantity, status, product_id),
    )
    conn.commit()
    conn.close()


def delete_product_db(product_id):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM products WHERE id=?", (product_id,))
    conn.commit()
    conn.close()


# ----------------- UI helper functions -----------------
def show_frame(frame):
    frame.tkraise()
    if frame == dashboard_frame:
        update_dashboard()
    elif frame == reports_frame:
        update_chart()


def get_status_from_quantity(quantity):
    if quantity == 0:
        return "Out of Stock"
    elif quantity <= 10:
        return "Low Stock"
    else:
        return "In Stock"


def add_product():
    product = entry_product.get().strip()
    quantity_text = entry_quantity.get().strip()

    if not (product and quantity_text.isdigit()):
        messagebox.showwarning(
            "Input Error", "Please enter a valid product name and numeric quantity."
        )
        return

    quantity = int(quantity_text)
    status = get_status_from_quantity(quantity)

    # Insert into DB and get ID
    new_id = insert_product_db(product, quantity, status)

    # Update in-memory list and Treeview (use DB id as iid so updates/deletes are safe)
    item = {"id": new_id, "product": product, "quantity": quantity, "status": status}
    product_data.append(item)
    tree_products.insert(
        "", "end", iid=str(new_id), values=(product, quantity, status)
    )

    if status in ("Low Stock", "Out of Stock"):
        messagebox.showwarning("Stock Warning", f"'{product}' is {status}!")

    entry_product.delete(0, "end")
    entry_quantity.delete(0, "end")
    update_dashboard()


def select_product(event):
    global selected_item
    selected_item = tree_products.focus()  # this is the iid string (we store DB id as iid)
    if not selected_item:
        return

    values = tree_products.item(selected_item, "values")
    if values:
        entry_product.delete(0, "end")
        entry_quantity.delete(0, "end")
        entry_product.insert(0, values[0])
        entry_quantity.insert(0, values[1])


def update_product():
    global selected_item
    if not selected_item:
        messagebox.showwarning("Selection Error", "Please select a product to update.")
        return

    product = entry_product.get().strip()
    quantity_text = entry_quantity.get().strip()

    if not (product and quantity_text.isdigit()):
        messagebox.showwarning(
            "Input Error", "Please enter valid product name and numeric quantity."
        )
        return

    quantity = int(quantity_text)
    status = get_status_from_quantity(quantity)

    product_id = int(selected_item)

    # Update DB
    update_product_db(product_id, product, quantity, status)

    # Update Treeview
    tree_products.item(selected_item, values=(product, quantity, status))

    # Update in-memory list
    for item in product_data:
        if item["id"] == product_id:
            item["product"] = product
            item["quantity"] = quantity
            item["status"] = status
            break

    if status in ("Low Stock", "Out of Stock"):
        messagebox.showwarning("Stock Warning", f"'{product}' is {status}!")

    update_dashboard()
    messagebox.showinfo("Updated", "Product updated successfully.")


def delete_product():
    global selected_item
    if not selected_item:
        messagebox.showwarning("Selection Error", "Please select a product to delete.")
        return

    values = tree_products.item(selected_item, "values")
    confirm = messagebox.askyesno("Confirm Delete", f"Delete product '{values[0]}'?")
    if not confirm:
        return

    product_id = int(selected_item)

    # Delete from DB
    delete_product_db(product_id)

    # Delete from Treeview and in-memory list
    tree_products.delete(selected_item)
    product_data[:] = [p for p in product_data if p["id"] != product_id]
    selected_item = None

    entry_product.delete(0, "end")
    entry_quantity.delete(0, "end")

    update_dashboard()
    messagebox.showinfo("Deleted", "Product deleted successfully.")


def update_dashboard():
    total_products = len(product_data)
    total_quantity = sum(p["quantity"] for p in product_data)
    low_stock = sum(1 for p in product_data if p["quantity"] <= 10)

    lbl_total_products.configure(text=f"Total Products: {total_products}")
    lbl_total_quantity.configure(text=f"Total Quantity: {total_quantity}")
    lbl_low_stock.configure(text=f"Low Stock Items (≤10): {low_stock}")

    for widget in dashboard_chart_frame.winfo_children():
        widget.destroy()

    if not product_data or total_quantity == 0:
        lbl_no_data = ctk.CTkLabel(
            dashboard_chart_frame, text="No data to display", text_color="gray"
        )
        lbl_no_data.pack(pady=20)
        return

    products = [p["product"] for p in product_data]
    quantities = [p["quantity"] for p in product_data]

    fig, ax = plt.subplots(figsize=(4.5, 3.5))
    ax.pie(quantities, labels=products, autopct="%1.1f%%", startangle=90)
    ax.set_title("Product Quantity Distribution", fontsize=12)

    canvas = FigureCanvasTkAgg(fig, master=dashboard_chart_frame)
    canvas.draw()
    canvas.get_tk_widget().pack(fill="both", expand=True)


def export_to_csv():
    if not product_data:
        messagebox.showinfo("No Data", "No data available to export.")
        return

    filepath = filedialog.asksaveasfilename(
        defaultextension=".csv", filetypes=[("CSV Files", "*.csv")]
    )
    if not filepath:
        return

    with open(filepath, "w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["Product", "Quantity", "Status"])
        for item in product_data:
            writer.writerow([item["product"], item["quantity"], item["status"]])

    messagebox.showinfo("Export Successful", f"Data exported to {filepath}")


def update_chart():
    for widget in chart_frame.winfo_children():
        widget.destroy()

    if not product_data:
        lbl_no_data = ctk.CTkLabel(chart_frame, text="No data to display", text_color="gray")
        lbl_no_data.pack(pady=20)
        return

    products = [p["product"] for p in product_data]
    quantities = [p["quantity"] for p in product_data]

    fig, ax = plt.subplots(figsize=(5, 3))
    ax.bar(products, quantities)
    ax.set_title("Product Quantities")
    ax.set_xlabel("Products")
    ax.set_ylabel("Quantity")
    plt.xticks(rotation=30, ha="right")

    canvas = FigureCanvasTkAgg(fig, master=chart_frame)
    canvas.draw()
    canvas.get_tk_widget().pack(fill="both", expand=True)


def search_products(event=None):
    query = search_entry.get().strip().lower()

    # Clear Treeview, then re-insert rows that match (keep iid as DB id)
    for item in tree_products.get_children():
        tree_products.delete(item)

    for p in product_data:
        if (
            query in p["product"].lower()
            or query in str(p["quantity"]).lower()
            or query in p["status"].lower()
        ):
            tree_products.insert(
                "", "end", iid=str(p["id"]), values=(p["product"], p["quantity"], p["status"])
            )


# ----------------- UI Layout -----------------
container = ctk.CTkFrame(app, fg_color="white")
container.pack(fill="both", expand=True)

# Top Bar
topbar = ctk.CTkFrame(container, fg_color="#C9E6FF", height=50)
topbar.pack(fill="x")

search_entry = ctk.CTkEntry(topbar, placeholder_text="Search...", width=200)
search_entry.pack(side="right", padx=20, pady=10)
search_entry.bind("<KeyRelease>", search_products)

# Navigation Tabs
nav_frame = ctk.CTkFrame(container, fg_color="white")
nav_frame.pack(fill="x", pady=10)

btn_dashboard = ctk.CTkButton(
    nav_frame, text="Dashboard", width=150, command=lambda: show_frame(dashboard_frame)
)
btn_products = ctk.CTkButton(
    nav_frame, text="Products", width=150, command=lambda: show_frame(products_frame)
)
btn_reports = ctk.CTkButton(
    nav_frame, text="Reports", width=150, command=lambda: show_frame(reports_frame)
)

btn_dashboard.grid(row=0, column=0, padx=10)
btn_products.grid(row=0, column=1, padx=10)
btn_reports.grid(row=0, column=2, padx=10)

# Dashboard Frame
dashboard_frame = ctk.CTkFrame(container, fg_color="white")
lbl_title = ctk.CTkLabel(
    dashboard_frame, text="Dashboard Overview", font=("Arial", 22, "bold")
)
lbl_title.pack(pady=(30, 10))
lbl_total_products = ctk.CTkLabel(dashboard_frame, text="Total Products: 0", font=("Arial", 18))
lbl_total_products.pack(pady=5)
lbl_total_quantity = ctk.CTkLabel(dashboard_frame, text="Total Quantity: 0", font=("Arial", 18))
lbl_total_quantity.pack(pady=5)
lbl_low_stock = ctk.CTkLabel(
    dashboard_frame, text="Low Stock Items (≤10): 0", font=("Arial", 18)
)
lbl_low_stock.pack(pady=5)

dashboard_chart_frame = ctk.CTkFrame(dashboard_frame, fg_color="white")
dashboard_chart_frame.pack(fill="both", expand=True, pady=20)

# Products Frame
products_frame = ctk.CTkFrame(container, fg_color="white")
tree_products = ttk.Treeview(
    products_frame, columns=("Product", "Quantity", "Status"), show="headings", height=10
)
tree_products.heading("Product", text="PRODUCT")
tree_products.heading("Quantity", text="QUANTITY")
tree_products.heading("Status", text="STATUS")
tree_products.pack(padx=20, pady=20, fill="both", expand=True, side="left")
tree_products.bind("<<TreeviewSelect>>", select_product)

# Side Entry Fields
side_frame = ctk.CTkFrame(products_frame, fg_color="white")
side_frame.pack(side="right", fill="y", padx=20)

entry_product = ctk.CTkEntry(side_frame, placeholder_text="Product Name")
entry_product.pack(pady=10)
entry_quantity = ctk.CTkEntry(side_frame, placeholder_text="Quantity")
entry_quantity.pack(pady=10)

btn_add = ctk.CTkButton(side_frame, text="Add Product", command=add_product)
btn_add.pack(pady=10)
btn_update = ctk.CTkButton(
    side_frame, text="Update Product", fg_color="#FFC107", command=update_product
)
btn_update.pack(pady=10)
btn_delete = ctk.CTkButton(
    side_frame, text="Delete Product", fg_color="#E74C3C", command=delete_product
)
btn_delete.pack(pady=10)

# Reports Frame
reports_frame = ctk.CTkFrame(container, fg_color="white")
lbl_report_title = ctk.CTkLabel(
    reports_frame, text="Reports & Analytics", font=("Arial", 22, "bold")
)
lbl_report_title.pack(pady=(20, 10))
btn_export = ctk.CTkButton(reports_frame, text="Export to CSV", command=export_to_csv)
btn_export.pack(pady=(0, 10))
chart_frame = ctk.CTkFrame(reports_frame, fg_color="white")
chart_frame.pack(fill="both", expand=True, padx=20, pady=10)

# Frame Layout Order
for frame in (dashboard_frame, products_frame, reports_frame):
    frame.place(in_=container, x=0, y=100, relwidth=1, relheight=1)


# ----------------- Initialize DB and load data -----------------
init_db()
product_data = fetch_products()

# Populate Treeview using DB ids as iids (keeps selection mapping stable even after searches)
for p in product_data:
    tree_products.insert(
        "", "end", iid=str(p["id"]), values=(p["product"], p["quantity"], p["status"])
    )

show_frame(dashboard_frame)
app.mainloop()