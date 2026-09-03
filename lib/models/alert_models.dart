import 'package:flutter/foundation.dart';

/// Lightweight employee reference embedded inside [MobileAlert].
@immutable
class AlertEmployee {
  final int id;
  final String name;
  final String role;
  final String? phone;

  const AlertEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
  });

  factory AlertEmployee.fromJson(Map<String, dynamic> json) => AlertEmployee(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] as String?) ?? '',
    role: (json['role'] as String?) ?? '',
    phone: json['phone'] as String?,
  );
}

/// A single event in the alert's status history.
@immutable
class AlertEvent {
  final String status;
  final AlertEmployee? actor;
  final DateTime createdAt;

  const AlertEvent({
    required this.status,
    required this.actor,
    required this.createdAt,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    final actorRaw = json['actor'];
    AlertEmployee? actor;
    if (actorRaw is Map<String, dynamic>) {
      actor = AlertEmployee.fromJson(actorRaw);
    } else if (actorRaw is Map) {
      actor = AlertEmployee.fromJson(actorRaw.cast<String, dynamic>());
    }
    return AlertEvent(
      status: (json['status'] as String?) ?? '',
      actor: actor,
      createdAt: (json['created_at'] is String)
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Full alert model from `GET /employees/{id}/alerts`.
///
/// Status lifecycle: pending -> sent -> viewed -> handled.
@immutable
class MobileAlert {
  final int id;
  final int occurrenceId;
  final AlertEmployee recipient;
  final AlertEmployee sender;
  final String message;

  /// One of: `pending`, `sent`, `viewed`, `handled`.
  final String status;
  final int deliveryPriority;
  final DateTime? sentAt;
  final DateTime? viewedAt;
  final DateTime? handledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AlertEvent> history;

  const MobileAlert({
    required this.id,
    required this.occurrenceId,
    required this.recipient,
    required this.sender,
    required this.message,
    required this.status,
    required this.deliveryPriority,
    required this.sentAt,
    required this.viewedAt,
    required this.handledAt,
    required this.createdAt,
    required this.updatedAt,
    required this.history,
  });

  factory MobileAlert.fromJson(Map<String, dynamic> json) {
    AlertEmployee parseEmployee(dynamic raw) {
      if (raw is Map<String, dynamic>) return AlertEmployee.fromJson(raw);
      if (raw is Map) return AlertEmployee.fromJson(raw.cast<String, dynamic>());
      return const AlertEmployee(id: 0, name: '', role: '', phone: null);
    }

    DateTime? parseDate(dynamic raw) =>
        (raw is String) ? DateTime.tryParse(raw) : null;

    final historyRaw = json['history'];
    final history = <AlertEvent>[];
    if (historyRaw is List) {
      for (final e in historyRaw) {
        try {
          if (e is Map<String, dynamic>) {
            history.add(AlertEvent.fromJson(e));
          } else if (e is Map) {
            history.add(AlertEvent.fromJson(e.cast<String, dynamic>()));
          }
        } catch (ex) {
          debugPrint('Skipping invalid alert event: \$ex');
        }
      }
    }

    return MobileAlert(
      id: (json['id'] as num?)?.toInt() ?? 0,
      occurrenceId: (json['occurrence_id'] as num?)?.toInt() ?? 0,
      recipient: parseEmployee(json['recipient']),
      sender: parseEmployee(json['sender']),
      message: (json['message'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      deliveryPriority: (json['delivery_priority'] as num?)?.toInt() ?? 0,
      sentAt: parseDate(json['sent_at']),
      viewedAt: parseDate(json['viewed_at']),
      handledAt: parseDate(json['handled_at']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
      history: history,
    );
  }

  /// Whether the alert still needs user attention.
  bool get isActionable =>
      status == 'pending' || status == 'sent' || status == 'viewed';

  /// Whether the alert is fully resolved from the user's perspective.
  bool get isHandled => status == 'handled';

  /// Creates a copy with a different status (for optimistic UI updates).
  MobileAlert copyWithStatus(String newStatus) => MobileAlert(
    id: id,
    occurrenceId: occurrenceId,
    recipient: recipient,
    sender: sender,
    message: message,
    status: newStatus,
    deliveryPriority: deliveryPriority,
    sentAt: sentAt,
    viewedAt: newStatus == 'viewed' ? DateTime.now() : viewedAt,
    handledAt: newStatus == 'handled' ? DateTime.now() : handledAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    history: history,
  );
}
