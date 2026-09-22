from app.extensions import db

class Book(db.Model):
    __tablename__ = 'books'

    id = db.Column(db.Integer, primary_key=True)
    titre = db.Column(db.String(255), nullable=False)
    auteur = db.Column(db.String(255), nullable=False)
    annee = db.Column(db.Integer, nullable=False)
    disponible = db.Column(db.Boolean, default=True)

    def __repr__(self):
        return f'<Book {self.titre}>'