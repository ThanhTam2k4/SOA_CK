class PropertyItem {
  final int id;
  final String code;
  final String name;
  final String address;
  final String district;
  final String ward;
  final int totalRooms;
  final int occupiedRooms;
  final int availableRooms;
  final int maintenanceRooms;
  final String status; // ACTIVE, INACTIVE
  final String description;

  const PropertyItem({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.district,
    this.ward = '',
    required this.totalRooms,
    required this.occupiedRooms,
    required this.availableRooms,
    this.maintenanceRooms = 0,
    required this.status,
    this.description = '',
  });

  PropertyItem copyWith({
    String? code,
    String? name,
    String? address,
    String? district,
    String? ward,
    int? totalRooms,
    int? occupiedRooms,
    int? availableRooms,
    int? maintenanceRooms,
    String? status,
    String? description,
  }) {
    return PropertyItem(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      address: address ?? this.address,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      totalRooms: totalRooms ?? this.totalRooms,
      occupiedRooms: occupiedRooms ?? this.occupiedRooms,
      availableRooms: availableRooms ?? this.availableRooms,
      maintenanceRooms: maintenanceRooms ?? this.maintenanceRooms,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }
}

class RoomItem {
  final int id;
  final String code;
  final String name;
  final int propertyId;
  final String propertyName;
  final int floor;
  final double rentPrice;
  final double area;
  final int currentOccupants;
  final int maxOccupants;
  final String status; // AVAILABLE, OCCUPIED, RESERVED, MAINTENANCE
  final String description;

  const RoomItem({
    required this.id,
    required this.code,
    required this.name,
    required this.propertyId,
    required this.propertyName,
    this.floor = 1,
    required this.rentPrice,
    required this.area,
    required this.currentOccupants,
    required this.maxOccupants,
    required this.status,
    this.description = '',
  });

  RoomItem copyWith({
    String? code,
    String? name,
    int? propertyId,
    String? propertyName,
    int? floor,
    double? rentPrice,
    double? area,
    int? currentOccupants,
    int? maxOccupants,
    String? status,
    String? description,
  }) {
    return RoomItem(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      propertyId: propertyId ?? this.propertyId,
      propertyName: propertyName ?? this.propertyName,
      floor: floor ?? this.floor,
      rentPrice: rentPrice ?? this.rentPrice,
      area: area ?? this.area,
      currentOccupants: currentOccupants ?? this.currentOccupants,
      maxOccupants: maxOccupants ?? this.maxOccupants,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }
}

class TenantItem {
  final int id;
  final String fullName;
  final String phone;
  final String email;
  final String idCard;
  final String currentRoom;
  final String propertyName;
  final String startDate;
  final String status; // ACTIVE, TEMPORARY_ABSENT, MOVED_OUT

  const TenantItem({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    this.idCard = '',
    required this.currentRoom,
    required this.propertyName,
    required this.startDate,
    required this.status,
  });

  TenantItem copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? idCard,
    String? currentRoom,
    String? propertyName,
    String? startDate,
    String? status,
  }) {
    return TenantItem(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      idCard: idCard ?? this.idCard,
      currentRoom: currentRoom ?? this.currentRoom,
      propertyName: propertyName ?? this.propertyName,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
    );
  }
}

class ContractItem {
  final int id;
  final String code;
  final String tenantName;
  final String roomName;
  final String propertyName;
  final String startDate;
  final String endDate;
  final double rentPrice;
  final double depositAmount;
  final String status; // ACTIVE, EXPIRING, EXPIRED, CANCELLED

  const ContractItem({
    required this.id,
    required this.code,
    required this.tenantName,
    required this.roomName,
    required this.propertyName,
    required this.startDate,
    required this.endDate,
    required this.rentPrice,
    required this.depositAmount,
    required this.status,
  });

  ContractItem copyWith({
    String? code,
    String? tenantName,
    String? roomName,
    String? propertyName,
    String? startDate,
    String? endDate,
    double? rentPrice,
    double? depositAmount,
    String? status,
  }) {
    return ContractItem(
      id: id,
      code: code ?? this.code,
      tenantName: tenantName ?? this.tenantName,
      roomName: roomName ?? this.roomName,
      propertyName: propertyName ?? this.propertyName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rentPrice: rentPrice ?? this.rentPrice,
      depositAmount: depositAmount ?? this.depositAmount,
      status: status ?? this.status,
    );
  }
}

class InvoiceItem {
  final int id;
  final String code;
  final String tenantName;
  final String roomName;
  final String propertyName;
  final String billingMonth;
  final double totalAmount;
  final String dueDate;
  final String status; // PAID, UNPAID, OVERDUE

  const InvoiceItem({
    required this.id,
    required this.code,
    required this.tenantName,
    required this.roomName,
    required this.propertyName,
    required this.billingMonth,
    required this.totalAmount,
    required this.dueDate,
    required this.status,
  });

  InvoiceItem copyWith({
    String? code,
    String? tenantName,
    String? roomName,
    String? propertyName,
    String? billingMonth,
    double? totalAmount,
    String? dueDate,
    String? status,
  }) {
    return InvoiceItem(
      id: id,
      code: code ?? this.code,
      tenantName: tenantName ?? this.tenantName,
      roomName: roomName ?? this.roomName,
      propertyName: propertyName ?? this.propertyName,
      billingMonth: billingMonth ?? this.billingMonth,
      totalAmount: totalAmount ?? this.totalAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }
}

class MaintenanceItem {
  final int id;
  final String code;
  final int roomId;
  final String roomName;
  final String propertyName;
  final String title;
  final String description;
  final String createdAt;
  final String priority; // LOW, MEDIUM, HIGH
  final String status; // PENDING, IN_PROGRESS, COMPLETED, CANCELLED
  final double estimatedCost;
  final double actualCost;

  const MaintenanceItem({
    required this.id,
    required this.code,
    required this.roomId,
    required this.roomName,
    required this.propertyName,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.priority,
    required this.status,
    this.estimatedCost = 0,
    this.actualCost = 0,
  });

  MaintenanceItem copyWith({
    String? code,
    int? roomId,
    String? roomName,
    String? propertyName,
    String? title,
    String? description,
    String? createdAt,
    String? priority,
    String? status,
    double? estimatedCost,
    double? actualCost,
  }) {
    return MaintenanceItem(
      id: id,
      code: code ?? this.code,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      propertyName: propertyName ?? this.propertyName,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
    );
  }
}

class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String createdAt;
  final String category; // BILLING, CONTRACT, MAINTENANCE, SYSTEM
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.category,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      category: category,
      isRead: isRead ?? this.isRead,
    );
  }
}

class MonthlyRevenuePoint {
  final String monthLabel;
  final double amountInMillions;

  const MonthlyRevenuePoint({
    required this.monthLabel,
    required this.amountInMillions,
  });
}

