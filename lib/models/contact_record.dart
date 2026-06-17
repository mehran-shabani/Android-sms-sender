enum ContactStatus {
  pending,
  sent,
  failed,
  invalid,
  duplicate,
  skipped;

  static ContactStatus fromValue(String? value) {
    return ContactStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ContactStatus.pending,
    );
  }
}

class ContactRecord {
  const ContactRecord({
    this.id,
    required this.sourceRow,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.token,
    required this.phone,
    required this.rawPhone,
    required this.message,
    required this.isValidPhone,
    required this.isDuplicate,
    required this.status,
    this.error,
    this.sentAt,
    this.deliveredAt,
    required this.smsPartCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int sourceRow;
  final String firstName;
  final String lastName;
  final String fullName;
  final String token;
  final String phone;
  final String rawPhone;
  final String message;
  final bool isValidPhone;
  final bool isDuplicate;
  final ContactStatus status;
  final String? error;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final int smsPartCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ContactRecord.fromMap(Map<String, Object?> map) {
    return ContactRecord(
      id: map['id'] as int?,
      sourceRow: map['source_row'] as int? ?? 0,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      token: map['token'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      rawPhone: map['raw_phone'] as String? ?? '',
      message: map['message'] as String? ?? '',
      isValidPhone: (map['is_valid_phone'] as int? ?? 0) == 1,
      isDuplicate: (map['is_duplicate'] as int? ?? 0) == 1,
      status: ContactStatus.fromValue(map['status'] as String?),
      error: map['error'] as String?,
      sentAt: _dateFromMillis(map['sent_at'] as int?),
      deliveredAt: _dateFromMillis(map['delivered_at'] as int?),
      smsPartCount: map['sms_part_count'] as int? ?? 0,
      createdAt: _dateFromMillis(map['created_at'] as int?) ?? DateTime.now(),
      updatedAt: _dateFromMillis(map['updated_at'] as int?) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'source_row': sourceRow,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'token': token,
      'phone': phone,
      'raw_phone': rawPhone,
      'message': message,
      'is_valid_phone': isValidPhone ? 1 : 0,
      'is_duplicate': isDuplicate ? 1 : 0,
      'status': status.name,
      'error': error,
      'sent_at': sentAt?.millisecondsSinceEpoch,
      'delivered_at': deliveredAt?.millisecondsSinceEpoch,
      'sms_part_count': smsPartCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  ContactRecord copyWith({
    int? id,
    int? sourceRow,
    String? firstName,
    String? lastName,
    String? fullName,
    String? token,
    String? phone,
    String? rawPhone,
    String? message,
    bool? isValidPhone,
    bool? isDuplicate,
    ContactStatus? status,
    String? error,
    DateTime? sentAt,
    DateTime? deliveredAt,
    int? smsPartCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactRecord(
      id: id ?? this.id,
      sourceRow: sourceRow ?? this.sourceRow,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      token: token ?? this.token,
      phone: phone ?? this.phone,
      rawPhone: rawPhone ?? this.rawPhone,
      message: message ?? this.message,
      isValidPhone: isValidPhone ?? this.isValidPhone,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      status: status ?? this.status,
      error: error ?? this.error,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      smsPartCount: smsPartCount ?? this.smsPartCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => fullName.trim().isNotEmpty
      ? fullName.trim()
      : '$firstName $lastName'.trim();

  String get displayNameOrPhone {
    final name = displayName;
    if (name.isNotEmpty) return name;
    if (phone.isNotEmpty) return phone;
    return rawPhone;
  }

  bool get canBePreparedForSending =>
      status == ContactStatus.pending || status == ContactStatus.failed;

  static DateTime? _dateFromMillis(int? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
}
