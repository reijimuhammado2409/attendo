class UserModel {
  final int? id;
  final String? name;
  final String? email;
  // final String? phone;
  final String? avatar;
  final String? createdAt;

  // ─── Field baru dari API /profile ─────────────────────────────────────────
  final String? jenisKelamin;      // "L" atau "P"
  final String? batchKe;           // "2"
  final String? trainingTitle;     // judul jurusan/training
  final String? profilePhotoUrl;   // full URL foto profil

  // Nested object (opsional, untuk info lengkap batch)
  final Map<String, dynamic>? batch;
  final Map<String, dynamic>? training;

  UserModel({
    this.id,
    this.name,
    this.email,
    // this.phone,
    this.avatar,
    this.createdAt,
    this.jenisKelamin,
    this.batchKe,
    this.trainingTitle,
    this.profilePhotoUrl,
    this.batch,
    this.training,
  });

  /// Dari JSON response API → UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      // phone: json['phone'] as String?,
      // Dukung dua kemungkinan field: "avatar" (lama) atau "profile_photo_url" (baru)
      avatar: json['profile_photo_url'] as String? ?? json['avatar'] as String?,
      createdAt: json['created_at'] as String?,

      // Field baru
      jenisKelamin: json['jenis_kelamin'] as String?,
      batchKe: json['batch_ke']?.toString(),
      trainingTitle: json['training_title'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,

      // Nested objects
      batch: json['batch'] is Map<String, dynamic>
          ? json['batch'] as Map<String, dynamic>
          : null,
      training: json['training'] is Map<String, dynamic>
          ? json['training'] as Map<String, dynamic>
          : null,
    );
  }

  /// UserModel → JSON (untuk disimpan ke SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      // 'phone': phone,
      'avatar': avatar,
      'created_at': createdAt,
      'jenis_kelamin': jenisKelamin,
      'batch_ke': batchKe,
      'training_title': trainingTitle,
      'profile_photo_url': profilePhotoUrl,
      'batch': batch,
      'training': training,
    };
  }

  /// Buat copy dengan sebagian field diubah
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    // String? phone,
    String? avatar,
    String? createdAt,
    String? jenisKelamin,
    String? batchKe,
    String? trainingTitle,
    String? profilePhotoUrl,
    Map<String, dynamic>? batch,
    Map<String, dynamic>? training,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      // phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      batchKe: batchKe ?? this.batchKe,
      trainingTitle: trainingTitle ?? this.trainingTitle,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      batch: batch ?? this.batch,
      training: training ?? this.training,
    );
  }

  /// Helper: label gender yang readable
  String get genderLabel {
    switch (jenisKelamin) {
      case 'L':
        return 'Laki-laki';
      case 'P':
        return 'Perempuan';
      default:
        return jenisKelamin ?? '-';
    }
  }

  /// Helper: label batch yang readable
  String get batchLabel {
    if (batchKe != null) return 'Batch $batchKe';
    return '-';
  }
}
