# app/main.py
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/add', methods=['POST'])
def add():
    data = request.get_json()
    num1 = data.get('num1')
    num2 = data.get('num2')
    if not isinstance(num1, (int, float)) or not isinstance(num2, (int, float)):
        return jsonify({"error": "Invalid input, please provide numbers."}), 400
    result = num1 + num2
    return jsonify({"result": result})

@app.route('/subtract', methods=['POST'])
def subtract():
    data = request.get_json()
    num1 = data.get('num1')
    num2 = data.get('num2')
    if not isinstance(num1, (int, float)) or not isinstance(num2, (int, float)):
        return jsonify({"error": "Invalid input, please provide numbers."}), 400
    result = num1 - num2
    return jsonify({"result": result})

@app.route('/multiply', methods=['POST'])
def multiply():
    data = request.get_json()
    num1 = data.get('num1')
    num2 = data.get('num2')
    if not isinstance(num1, (int, float)) or not isinstance(num2, (int, float)):
        return jsonify({"error": "Invalid input, please provide numbers."}), 400
    result = num1 * num2
    return jsonify({"result": result})

@app.route('/divide', methods=['POST'])
def divide():
    data = request.get_json()
    num1 = data.get('num1')
    num2 = data.get('num2')
    if not isinstance(num1, (int, float)) or not isinstance(num2, (int, float)):
        return jsonify({"error": "Invalid input, please provide numbers."}), 400
    if num2 == 0:
        return jsonify({"error": "Cannot divide by zero u dummy."}), 400
    result = num1 / num2
    return jsonify({"result": result})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
