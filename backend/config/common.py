"""
Cấu hình DÙNG CHUNG cho mọi service trong hệ thống SOA.

File này chỉ chứa hạ tầng (security, DRF, JWT, i18n, cách dựng cấu hình DB).
Nó KHÔNG khai báo app nghiệp vụ nào — mỗi service tự chọn app/DB/URL của mình
trong `config/service_settings/<service>.py`.
"""
import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / '.env')

SECRET_KEY = os.getenv('SECRET_KEY', 'insecure-secret-key-for-nhatro-management')
DEBUG = os.getenv('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = ['*']

# Khóa ký JWT dùng chung: Identity Service ký token, các service khác chỉ xác minh
# chữ ký (stateless) mà không cần truy cập database của Identity Service.
JWT_SIGNING_KEY = os.getenv('JWT_SIGNING_KEY', SECRET_KEY)

# ==============================================================================
# DATABASE PER SERVICE
# ==============================================================================
DB_ENGINE = os.getenv('DB_ENGINE', 'mssql').lower()

# service key -> (biến môi trường tên DB SQL Server, tên DB mặc định, file SQLite)
SERVICE_DATABASES = {
    'identity': ('DB_NAME_IDENTITY', 'nhatro_identity_db', 'db_identity.sqlite3'),
    'property': ('DB_NAME_PROPERTY', 'nhatro_property_db', 'db_property.sqlite3'),
    'tenant': ('DB_NAME_TENANT', 'nhatro_tenant_db', 'db_tenant.sqlite3'),
    'contract': ('DB_NAME_CONTRACT', 'nhatro_contract_db', 'db_contract.sqlite3'),
    'billing': ('DB_NAME_BILLING', 'nhatro_billing_db', 'db_billing.sqlite3'),
}


def service_database(service_key):
    """Trả về cấu hình database (SQL Server hoặc SQLite) của một service."""
    env_name, default_name, sqlite_file = SERVICE_DATABASES[service_key]
    if DB_ENGINE == 'mssql':
        db_trusted = os.getenv('DB_TRUSTED_CONNECTION', 'yes').lower() == 'yes'
        extra_params = 'TrustServerCertificate=yes;'
        if db_trusted:
            extra_params += 'Trusted_Connection=yes;'
        return {
            'ENGINE': 'mssql',
            'NAME': os.getenv(env_name, default_name),
            'HOST': os.getenv('DB_SERVER', r'.\SQLEXPRESS'),
            'PORT': os.getenv('DB_PORT', ''),
            'USER': os.getenv('DB_USER', ''),
            'PASSWORD': os.getenv('DB_PASSWORD', ''),
            'OPTIONS': {
                'driver': os.getenv('DB_DRIVER', 'ODBC Driver 17 for SQL Server'),
                'extra_params': extra_params,
            },
        }
    # SQLITE_DIR cho phép đặt file SQLite ở thư mục khác (vd. môi trường test/CI).
    sqlite_dir = Path(os.getenv('SQLITE_DIR', str(BASE_DIR)))
    return {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': sqlite_dir / sqlite_file,
    }


# ==============================================================================
# DJANGO CORE
# ==============================================================================
BASE_INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'drf_spectacular',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
]

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
            ],
        },
    },
]

LANGUAGE_CODE = 'vi-vn'
TIME_ZONE = 'Asia/Ho_Chi_Minh'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ==============================================================================
# REST FRAMEWORK & JWT
# ==============================================================================
# Mặc định: xác thực STATELESS — chỉ kiểm tra chữ ký JWT và đọc claims
# (user_id, username, role, is_superuser). Không truy vấn bảng User.
# Riêng Identity Service ghi đè bằng JWTAuthentication (có tra DB).
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTStatelessUserAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': False,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
    'SIGNING_KEY': JWT_SIGNING_KEY,
}


def spectacular_settings(title, description):
    return {
        'TITLE': title,
        'DESCRIPTION': description,
        'VERSION': '2.0.0',
        'SERVE_INCLUDE_SCHEMA': False,
    }
