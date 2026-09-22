import os   

class Config: 
    """Base configuration class."""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'default_secret key')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', 'sqlite:///books.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'default_jwt_secret_key')  # Change this in production
    
class DevConfig(Config):
    """Development configuration class."""
    DEBUG = True

class ProdConfig(Config):
    """Production configuration class."""
    DEBUG = False

class TestConfig(Config):
    """Testing configuration class."""
    TESTING = True

config_by_name = {
    'dev': DevConfig,
    'prod': ProdConfig,
    'test': TestConfig
}