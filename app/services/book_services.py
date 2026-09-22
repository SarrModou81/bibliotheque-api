from app.models.book import Book
from app.extensions import db


def list_books():
    """Retourne la liste de tous les livres."""
    return Book.query.all()

def get_book(book_id):
    """Retourne un livre correspondant à l'ID donné."""
    return Book.query.get(book_id)

def create_book(data):
    """Crée un nouveau livre avec les données fournies."""
    book = Book(
        titre=data["titre"],
        auteur=data["auteur"],
        annee=data["annee"],
        disponible=data.get("disponible", True)
    )
    db.session.add(book)
    db.session.commit()
    return book

def delete_book(book_id):
    """Supprime un livre correspondant à l'ID donné."""
    book = Book.query.get(book_id)
    if book:
        db.session.delete(book)
        db.session.commit()
        return book
    return None