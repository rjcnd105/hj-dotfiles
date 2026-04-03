"""API handler with some issues for review testing."""

import json
import sqlite3

def get_user(user_id):
    """Get user by ID from database."""
    conn = sqlite3.connect("app.db")
    # SQL injection vulnerability
    query = f"SELECT * FROM users WHERE id = {user_id}"
    cursor = conn.execute(query)
    result = cursor.fetchone()
    # Connection never closed
    return result

def create_user(request_data):
    """Create a new user."""
    data = json.loads(request_data)
    name = data["name"]  # No validation, KeyError possible
    email = data["email"]

    conn = sqlite3.connect("app.db")
    conn.execute(
        f"INSERT INTO users (name, email) VALUES ('{name}', '{email}')"
    )
    conn.commit()
    return {"status": "created", "name": name}

def delete_all_users():
    """Delete all users - dangerous operation without auth check."""
    conn = sqlite3.connect("app.db")
    conn.execute("DELETE FROM users")
    conn.commit()
    conn.close()
    return {"status": "all users deleted"}
