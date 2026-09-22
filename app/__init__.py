from flask import Flask 
from app import config
from app.extensions import db, migrate, jwt


def create_app(config_name):
    app = Flask(__name__)
    app.config.from_object(config.config_by_name[config_name])
    jwt.init_app(app)
    db.init_app(app)
    migrate.init_app(app, db)

    # Register blueprints
    from app.routes.health import health_bp
    from app.routes.books import books_bp
    from app.routes.auth import auth_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(books_bp)
    app.register_blueprint(auth_bp)

    return app