from flask import Blueprint, jsonify

health_bp = Blueprint('health', __name__, url_prefix='/health')

@health_bp.route('/', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify(status='healthy'), 200