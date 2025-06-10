import json
import os

# File to store user IDs
USER_DATA_FILE = os.path.join(os.path.dirname(__file__), 'user_data.json')

def save_user_id(user_key, user_id):
    """
    Save a user ID to the data file
    
    Args:
        user_key: Key to identify the user (e.g., 'user_a')
        user_id: The user ID to save
    """
    # Load existing data if file exists
    data = {}
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'r') as f:
            data = json.load(f)
    
    # Update with new user ID
    data[user_key] = user_id
    
    # Save back to file
    with open(USER_DATA_FILE, 'w') as f:
        json.dump(data, f)

def load_user_id(user_key):
    """
    Load a user ID from the data file
    
    Args:
        user_key: Key to identify the user (e.g., 'user_a')
    
    Returns:
        The user ID if found, None otherwise
    """
    if not os.path.exists(USER_DATA_FILE):
        return None
        
    with open(USER_DATA_FILE, 'r') as f:
        data = json.load(f)
        return data.get(user_key) 