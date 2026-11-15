from django.contrib import admin
from django.shortcuts import render
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from .architecture_views import ArchitectureStatusView


def portal_view(request, initial_view='property'):
    return render(request, 'portal.html', {'initial_view': initial_view})


def api_docs_view(request):
    return render(request, 'api_docs.html')


urlpatterns = [
    # GIAO DIỆN TỔNG HỢP GỌI TẤT CẢ SERVICES TRÊN PORT 8000 (KÈM ĐƯỜNG DẪN RIÊNG CHO TỪNG SERVICE)
    path('', portal_view, {'initial_view': 'property'}, name='portal_home'),
    path('property/', portal_view, {'initial_view': 'property'}, name='portal_property'),
    path('rooms/', portal_view, {'initial_view': 'rooms'}, name='portal_rooms'),
    path('room-status/', portal_view, {'initial_view': 'room-status'}, name='portal_room_status'),
    path('maintenance/', portal_view, {'initial_view': 'maintenance'}, name='portal_maintenance'),
    path('identity/', portal_view, {'initial_view': 'identity'}, name='portal_identity'),
    path('tenant/', portal_view, {'initial_view': 'tenant'}, name='portal_tenant'),
    path('contract/', portal_view, {'initial_view': 'contract'}, name='portal_contract'),
    path('billing/', portal_view, {'initial_view': 'billing'}, name='portal_billing'),

    # TRANG API DOC & KIỂM TRA CÁC SERVICE CÓ ĐANG HOẠT ĐỘNG HAY KHÔNG
    path('api-docs/', api_docs_view, name='api_docs_dashboard'),
    path('health/', ArchitectureStatusView.as_view(), name='gateway_health'),

    # Django Admin & OpenAPI Swagger Docs
    path('admin/', admin.site.urls),
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

    # ARCHITECTURE & SERVICE INTEGRATION CHECK API
    path('api/v1/architecture/status/', ArchitectureStatusView.as_view(), name='architecture_status'),

    # SERVICE 1: IDENTITY & AUTHENTICATION
    path('api/v1/', include('services.identity_service.urls')),

    # SERVICE 2: PROPERTY & MAINTENANCE SERVICE
    path('api/v1/', include('services.property_service.urls')),

    # SERVICE 3: TENANT SERVICE
    path('api/v1/tenants/', include('services.tenant_service.urls')),

    # SERVICE 4: CONTRACT SERVICE
    path('api/v1/contracts/', include('services.contract_service.urls')),

    # SERVICE 5: BILLING & NOTIFICATION SERVICE
    path('api/v1/billing/', include('services.billing_notification_service.urls')),
]
