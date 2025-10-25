from flask import Flask, request, jsonify

app = Flask(__name__)

# --- Arithmetic Logic ---
def calculate(num1, num2, operation):
    if operation == 'add':
        return num1 + num2
    elif operation == 'subtract':
        return num1 - num2
    elif operation == 'multiply':
        return num1 * num2
    elif operation == 'divide':
        if num2 == 0:
            raise ZeroDivisionError("Cannot divide by zero")
        return num1 / num2
    return None

# --- Root Route ---
@app.route('/', methods=['GET'])
def home():
    return "Welcome to the Arithmetic API! Use /add, /subtract, /multiply, /divide endpoints."

# --- Helper Function ---
def process_arithmetic_request(operation):
    data = request.get_json()
    if not data or 'num1' not in data or 'num2' not in data:
        return jsonify({'error': 'Missing num1 or num2 in JSON payload'}), 400

    try:
        num1 = float(data['num1'])
        num2 = float(data['num2'])
        result = calculate(num1, num2, operation)
        return jsonify({'operation': operation, 'result': result}), 200
    except ZeroDivisionError as e:
        return jsonify({'error': str(e)}), 400
    except Exception:
        return jsonify({'error': 'Invalid input type'}), 400

# --- Routes ---
@app.route('/add', methods=['POST'])
def add():
    return process_arithmetic_request('add')

@app.route('/subtract', methods=['POST'])
def subtract():
    return process_arithmetic_request('subtract')

@app.route('/multiply', methods=['POST'])
def multiply():
    return process_arithmetic_request('multiply')

@app.route('/divide', methods=['POST'])
def divide():
    return process_arithmetic_request('divide')

# --- Run the App ---
if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
