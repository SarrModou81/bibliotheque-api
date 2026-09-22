from marshmallow import Schema, fields, validate

class BookSchema(Schema):
    id = fields.Int(dump_only=True)
    title = fields.Str(required=True, validate=validate.Length(max=200))
    author = fields.Str(required=True, validate=validate.Length(max=100))
    year = fields.Int(required=True, validate=validate.Range(min=0))
    available = fields.Boolean(load_default=True)

book_schema = BookSchema()
books_schema = BookSchema(many=True)
