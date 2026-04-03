"""Simple calculator with intentional issues for review testing."""

import os

# Hardcoded DB connection (security issue)
DB_PASSWORD = "admin123"

def divide(a, b):
    """Divide two numbers."""
    return a / b  # No zero-division check

def calculate_average(numbers):
    """Calculate average of a list."""
    total = 0
    for n in numbers:
        total += n
    return total / len(numbers)  # Empty list will crash

def process_user_input(raw_input):
    """Process raw user input and execute."""
    result = eval(raw_input)  # eval on user input - security vulnerability
    return result

def fetch_data(url):
    """Fetch data from URL."""
    import urllib.request
    response = urllib.request.urlopen(url)  # No timeout, no error handling
    return response.read()
