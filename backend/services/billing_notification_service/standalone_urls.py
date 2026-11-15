from django.urls import path, include
from config.architecture_views import make_service_root_view

RootView = make_service_root_view('billing')

urlpatterns = [
    path('', RootView.as_view(), name='service_root'),
    path('health/', RootView.as_view(), name='health'),
    path('api/v1/billing/', include('services.billing_notification_service.urls')),
]
