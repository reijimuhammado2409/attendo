class AbsenModel {
  final int? id;
  final int? userId;
  final String? type;       // 'masuk' | 'pulang'
  final String? status;     // 'hadir' | 'terlambat' | 'izin'
  final String? checkIn;
  final String? checkOut;
  final String? date;
  final String? note;
  final String? location;

  AbsenModel({
    this.id,
    this.userId,
    this.type,
    this.status,
    this.checkIn,
    this.checkOut,
    this.date,
    this.note,
    this.location,
  });

  factory AbsenModel.fromJson(Map<String, dynamic> json) {
    return AbsenModel(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      type: json['type'] as String?,
      status: json['status'] as String?,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      date: json['date'] as String?,
      note: json['note'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'status': status,
      'check_in': checkIn,
      'check_out': checkOut,
      'date': date,
      'note': note,
      'location': location,
    };
  }
}