import pytest
import json

# Assuming your main application logic is in a file named 'app.py'
from app import app

# --- Fixture to set up the test client ---
@pytest.fixture
def client():
    # Set Flask to testing mode
    app.config['TESTING'] = True
    # The 'with' block creates an application context for testing
    with app.test_client() as client:
        yield client

# --- Test Cases ---

# Test the root welcome route (based on your image)
def test_root_route(client):
    """Test the base route to ensure the API is running."""
    rv = client.get('/')
    assert rv.status_code == 200
    # Check for the expected welcome message text
    assert b'Welcome to the Arithmetic API! Use /add, /subtract, /multiply, /divide endpoints.' in rv.data

# Test the /add endpoint with valid data
def test_add_success(client):
    """Test the successful addition of two numbers."""
    # Data to send in the POST request
    data = {"num1": 10, "num2": 5}
    rv = client.post('/add',
                     data=json.dumps(data),
                     content_type='application/json')
    
    # Check for a successful HTTP status code
    assert rv.status_code == 200
    # Check the JSON response content
    json_data = rv.get_json()
    assert json_data['operation'] == 'add'
    assert json_data['result'] == 15.0

# Test the /subtract endpoint with valid data
def test_subtract_success(client):
    """Test the successful subtraction of two numbers."""
    data = {"num1": 100, "num2": 25}
    rv = client.post('/subtract',
                     data=json.dumps(data),
                     content_type='application/json')
    assert rv.status_code == 200
    assert rv.get_json()['result'] == 75.0

# Test the /divide endpoint, including division by zero
def test_divide_by_zero(client):
    """Test that division by zero returns a 400 Bad Request error."""
    data = {"num1": 10, "num2": 0}
    rv = client.post('/divide',
                     data=json.dumps(data),
                     content_type='application/json')
    # Assuming your Flask app handles division by zero and returns a 400
    assert rv.status_code == 400
    # You might also check the error message in the JSON response if your app provides one
    assert 'error' in rv.get_json()
