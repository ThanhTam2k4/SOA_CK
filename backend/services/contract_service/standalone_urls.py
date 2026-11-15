from django.urls import path, include
from config.architecture_views import make_service_root_view

RootView = make_service_root_view('contract')

urlpatterns = [
    path('', RootView.as_view(), name='service_root'),
    path('health/', RootView.as_view(), name='health'),
    path('api/v1/contracts/', include('services.contract_service.urls')),
]
