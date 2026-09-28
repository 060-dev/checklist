import 'package:flutter/foundation.dart';

@immutable
class PurchaseUser {
  final int id;
  final String name;
  final String? role;

  const PurchaseUser({required this.id, required this.name, this.role});

  factory PurchaseUser.fromJson(Map<String, dynamic> json) => PurchaseUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        role: json['role'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (role != null) 'role': role,
      };
}

@immutable
class PurchaseSector {
  final int id;
  final String name;

  const PurchaseSector({required this.id, required this.name});

  factory PurchaseSector.fromJson(Map<String, dynamic> json) => PurchaseSector(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

@immutable
class PurchaseFarm {
  final int id;
  final String name;
  final List<PurchaseSector> sectors;

  const PurchaseFarm({
    required this.id,
    required this.name,
    required this.sectors,
  });

  factory PurchaseFarm.fromJson(Map<String, dynamic> json) {
    final secsRaw = json['sectors'];
    final secs = <PurchaseSector>[];
    if (secsRaw is List) {
      for (final s in secsRaw) {
        if (s is Map<String, dynamic>) {
          secs.add(PurchaseSector.fromJson(s));
        } else if (s is Map) {
          secs.add(PurchaseSector.fromJson(s.cast<String, dynamic>()));
        }
      }
    }
    return PurchaseFarm(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      sectors: secs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sectors': sectors.map((e) => e.toJson()).toList(),
      };
}

@immutable
class PurchaseCapabilities {
  final bool createRequests;
  final bool editOwnRequests;
  final bool manage;
  final bool viewAll;
  final bool configureApprovals;

  const PurchaseCapabilities({
    required this.createRequests,
    required this.editOwnRequests,
    required this.manage,
    required this.viewAll,
    required this.configureApprovals,
  });

  factory PurchaseCapabilities.fromJson(Map<String, dynamic> json) =>
      PurchaseCapabilities(
        createRequests: (json['create_requests'] as bool?) ?? false,
        editOwnRequests: (json['edit_own_requests'] as bool?) ?? false,
        manage: (json['manage'] as bool?) ?? false,
        viewAll: (json['view_all'] as bool?) ?? false,
        configureApprovals: (json['configure_approvals'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'create_requests': createRequests,
        'edit_own_requests': editOwnRequests,
        'manage': manage,
        'view_all': viewAll,
        'configure_approvals': configureApprovals,
      };
}

@immutable
class PurchaseContext {
  final PurchaseUser? currentUser;
  final List<PurchaseUser> users;
  final List<PurchaseFarm> farms;
  final PurchaseCapabilities capabilities;

  const PurchaseContext({
    this.currentUser,
    this.users = const [],
    this.farms = const [],
    required this.capabilities,
  });

  factory PurchaseContext.fromJson(Map<String, dynamic> json) {
    PurchaseUser? cu;
    final cuRaw = json['current_user'];
    if (cuRaw is Map<String, dynamic>) {
      cu = PurchaseUser.fromJson(cuRaw);
    } else if (cuRaw is Map) {
      cu = PurchaseUser.fromJson(cuRaw.cast<String, dynamic>());
    }

    final usersRaw = json['users'];
    final users = <PurchaseUser>[];
    if (usersRaw is List) {
      for (final u in usersRaw) {
        if (u is Map<String, dynamic>) {
          users.add(PurchaseUser.fromJson(u));
        } else if (u is Map) {
          users.add(PurchaseUser.fromJson(u.cast<String, dynamic>()));
        }
      }
    }

    final farmsRaw = json['farms'];
    final farms = <PurchaseFarm>[];
    if (farmsRaw is List) {
      for (final f in farmsRaw) {
        if (f is Map<String, dynamic>) {
          farms.add(PurchaseFarm.fromJson(f));
        } else if (f is Map) {
          farms.add(PurchaseFarm.fromJson(f.cast<String, dynamic>()));
        }
      }
    }

    PurchaseCapabilities cap = const PurchaseCapabilities(
      createRequests: false,
      editOwnRequests: false,
      manage: false,
      viewAll: false,
      configureApprovals: false,
    );
    final capRaw = json['capabilities'];
    if (capRaw is Map<String, dynamic>) {
      cap = PurchaseCapabilities.fromJson(capRaw);
    } else if (capRaw is Map) {
      cap = PurchaseCapabilities.fromJson(capRaw.cast<String, dynamic>());
    }

    return PurchaseContext(
      currentUser: cu,
      users: users,
      farms: farms,
      capabilities: cap,
    );
  }

  Map<String, dynamic> toJson() => {
        if (currentUser != null) 'current_user': currentUser!.toJson(),
        'users': users.map((e) => e.toJson()).toList(),
        'farms': farms.map((e) => e.toJson()).toList(),
        'capabilities': capabilities.toJson(),
      };
}

@immutable
class PurchaseProduct {
  final int id;
  final String name;
  final String? sku;

  const PurchaseProduct({
    required this.id,
    required this.name,
    this.sku,
  });

  factory PurchaseProduct.fromJson(Map<String, dynamic> json) =>
      PurchaseProduct(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        sku: json['sku'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (sku != null) 'sku': sku,
      };
}

@immutable
class PurchaseRequestSummary {
  final Map<String, dynamic> raw;
  const PurchaseRequestSummary(this.raw);

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get number => (raw['number'] as String?) ?? '';
  String? get name => raw['name'] as String?;
  String get status => (raw['status'] as String?) ?? '';
  String get priority => (raw['priority'] as String?) ?? 'normal';
  String get farmName => (raw['farm_name'] as String?) ?? '';
  String get sectorName => (raw['sector_name'] as String?) ?? '';
  int get itemCount => (raw['item_count'] as num?)?.toInt() ?? 0;

  DateTime? get createdAt {
    final s = raw['created_at'] as String?;
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Map<String, dynamic> toJson() => raw;
}

@immutable
class PurchaseRequestDetail {
  final Map<String, dynamic> raw;
  const PurchaseRequestDetail(this.raw);

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get number => (raw['number'] as String?) ?? '';
  String? get name => raw['name'] as String?;
  String get status => (raw['status'] as String?) ?? '';
  String get priority => (raw['priority'] as String?) ?? 'normal';
  int get farmId => (raw['farm_id'] as num?)?.toInt() ?? 0;
  String get farmName => (raw['farm_name'] as String?) ?? '';
  int get sectorId => (raw['territory_area_id'] as num?)?.toInt() ?? 0;
  String get sectorName => (raw['sector_name'] as String?) ?? '';
  String? get notes => raw['notes'] as String?;
  
  List<PurchaseItem> get items {
    final itRaw = raw['items'];
    if (itRaw is List) {
      return itRaw
          .whereType<Map>()
          .map((e) => PurchaseItem(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  List<PurchaseAttachmentRef> get attachments {
    final attRaw = raw['attachments'];
    if (attRaw is List) {
      return attRaw
          .whereType<Map>()
          .map((e) => PurchaseAttachmentRef(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => raw;
}

@immutable
class PurchaseItem {
  final Map<String, dynamic> raw;
  const PurchaseItem(this.raw);

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get productName => (raw['product_name'] as String?) ?? '';
  String? get description => raw['description'] as String?;
  String get quantity => (raw['quantity'] as String?) ?? '0';
  String get unit => (raw['unit'] as String?) ?? '';
  String get status => (raw['status'] as String?) ?? '';

  Map<String, dynamic> toJson() => raw;
}

@immutable
class PurchaseAttachmentRef {
  final Map<String, dynamic> raw;
  const PurchaseAttachmentRef(this.raw);

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get originalName => (raw['original_name'] as String?) ?? '';
  String get contentType => (raw['content_type'] as String?) ?? '';
  int get sizeBytes => (raw['size_bytes'] as num?)?.toInt() ?? 0;
  String get url => (raw['url'] as String?) ?? '';

  Map<String, dynamic> toJson() => raw;
}
