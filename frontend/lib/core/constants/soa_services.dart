import 'package:flutter/material.dart';

import 'api_constants.dart';

/// Định nghĩa 5 Microservices trong kiến trúc SOA (mỗi service chạy trên 1 port riêng).
/// Port/database chỉ để HIỂN THỊ kiến trúc; Frontend luôn gọi qua API Gateway
/// ([ApiConstants.baseUrl]) — không bao giờ gọi trực tiếp port 8001–8005.
class SoaServiceConfig {
  final String id;
  final String name;
  final String shortName;
  final int port;
  final String database;
  final String route;
  final String gatewayPrefix;
  final IconData icon;

  const SoaServiceConfig({
    required this.id,
    required this.name,
    required this.shortName,
    required this.port,
    required this.database,
    required this.route,
    required this.gatewayPrefix,
    required this.icon,
  });

  /// Đường dẫn REST qua Gateway, ví dụ http://127.0.0.1:8000/api/properties/
  String get gatewayEndpoint => '${ApiConstants.baseUrl}/$gatewayPrefix/';
}

class SoaServices {
  SoaServices._();

  static const identity = SoaServiceConfig(
    id: 'identity',
    name: 'Identity & Auth Service',
    shortName: 'Identity',
    port: 8001,
    database: 'nhatro_identity_db',
    route: '/settings',
    gatewayPrefix: 'auth',
    icon: Icons.verified_user_outlined,
  );

  static const property = SoaServiceConfig(
    id: 'property',
    name: 'Property & Maintenance Service',
    shortName: 'Property',
    port: 8002,
    database: 'nhatro_property_db',
    route: '/property',
    gatewayPrefix: 'properties',
    icon: Icons.apartment_outlined,
  );

  static const tenant = SoaServiceConfig(
    id: 'tenant',
    name: 'Tenant Management Service',
    shortName: 'Tenant',
    port: 8003,
    database: 'nhatro_tenant_db',
    route: '/tenant',
    gatewayPrefix: 'tenants',
    icon: Icons.people_outline_rounded,
  );

  static const contract = SoaServiceConfig(
    id: 'contract',
    name: 'Contract Management Service',
    shortName: 'Contract',
    port: 8004,
    database: 'nhatro_contract_db',
    route: '/contract',
    gatewayPrefix: 'contracts',
    icon: Icons.description_outlined,
  );

  static const billing = SoaServiceConfig(
    id: 'billing',
    name: 'Billing & Notification Service',
    shortName: 'Billing',
    port: 8005,
    database: 'nhatro_billing_db',
    route: '/billing',
    gatewayPrefix: 'billing/invoices',
    icon: Icons.receipt_long_outlined,
  );

  static const List<SoaServiceConfig> all = [
    identity,
    property,
    tenant,
    contract,
    billing,
  ];

  static SoaServiceConfig forRoute(String location) {
    if (location.startsWith('/property') ||
        location.startsWith('/rooms') ||
        location.startsWith('/maintenance')) {
      return property;
    }
    if (location.startsWith('/tenant')) return tenant;
    if (location.startsWith('/contract')) return contract;
    if (location.startsWith('/billing') || location.startsWith('/notifications')) {
      return billing;
    }
    return identity;
  }
}

