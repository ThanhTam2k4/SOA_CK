"""Helper cho test của các service stateless: tạo JWT giống Identity Service phát hành."""
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken


def make_access_token(user_id, role, username=None, is_superuser=False):
    token = AccessToken()
    token['user_id'] = user_id
    token['username'] = username or f'user{user_id}'
    token['role'] = role
    token['is_superuser'] = is_superuser
    return str(token)


def jwt_client(user_id, role, **kwargs):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {make_access_token(user_id, role, **kwargs)}')
    return client
