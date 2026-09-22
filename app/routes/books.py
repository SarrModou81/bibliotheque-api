from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from app.services import book_services
from marshmallow import ValidationError
from app.schemas.book_schema import book_schema, books_schema

books_bp = Blueprint('books', __name__, url_prefix='/api/v1/books')


@books_bp.route('/', methods=['GET'])
def list_books():
    return jsonify(book_services.list_books()), 200

@books_bp.route('/<int:book_id>', methods=['GET'])
def get_book(book_id):
    book = book_services.get_book(book_id)
    if book:
        return jsonify(book), 200
    return jsonify({"error": "Book not found"}), 404

@books_bp.route('/<int:book_id>', methods=['DELETE'])
@jwt_required()
def delete_book(book_id):
    book = book_services.delete_book(book_id)
    if book:
        return jsonify({"message": "Book deleted successfully"}), 200
    return jsonify({"error": "Book not found"}), 404

@books_bp.post("/")
@jwt_required()
def create_book():
    try:
        data = book_schema.load(request.get_json() or {})
    except ValidationError as err:
        return jsonify(err.messages), 402
    book = book_services.create_book(data)
    return jsonify(book_schema.dump(book)), 201