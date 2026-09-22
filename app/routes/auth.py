from flask import Blueprint, jsonify, request
from app.services.auth_service import register, authenticate

auth_bp = Blueprint('auth', __name__, url_prefix='/api/v1/auth')

@auth_bp.route('/register', methods=['POST'])
def register_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Username and password are required."}), 400

    try:
        user = register(username, password)
        return jsonify({"message": "User registered successfully.", "user_id": user.id}), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

@auth_bp.route('/login', methods=['POST'])
def login_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Username and password are required."}), 400

    user = authenticate(username, password)
    if user:
        return jsonify({"message": "Authentication successful.", "user_id": user.id}), 200
    else:
        return jsonify({"error": "Invalid username or password."}), 401