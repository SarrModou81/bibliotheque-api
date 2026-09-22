from app.extensions import db
from app.models.user import User

def register(username,password):
    """Enregistre un nouvel utilisateur avec le nom d'utilisateur et le mot de passe fournis."""

    # Vérifier si l'utilisateur existe déjà
    existing_user = User.query.filter_by(username=username).first()
    if existing_user:
        raise ValueError("Nom d'utilisateur déjà pris.")

    # Créer un nouvel utilisateur
    new_user = User(username=username)
    new_user.set_password(password)

    # Ajouter l'utilisateur à la base de données
    db.session.add(new_user)
    db.session.commit()

    return new_user

def authenticate(username, password):
    """Authentifie un utilisateur avec le nom d'utilisateur et le mot de passe fournis."""

    # Rechercher l'utilisateur par nom d'utilisateur
    user = User.query.filter_by(username=username).first()
    if user and user.check_password(password):
        return user  # Authentification réussie
    else:
        return None  # Authentification échouée