import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  final String _baseUrl = Constants.baseUrl;

  // ─── Header Helpers ──────────────────────────────────────────────────────

  Map<String, String> _headers({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ─── Response Parser ─────────────────────────────────────────────────────

  Map<String, dynamic> _parseResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      } else {
        throw ApiException(message: 'Response bukan JSON object');
      }
    }

    final message = body is Map
        ? (body['message'] ?? 'Terjadi kesalahan')
        : 'Terjadi kesalahan';
    throw ApiException(
        message: message.toString(), statusCode: response.statusCode);
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl${Constants.loginEndpoint}'),
            headers: _headers(),
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  /// Register user
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required int batchId,
    required int trainingId,
    required String gender,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl${Constants.registerEndpoint}'),
            headers: _headers(),
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'password_confirmation': passwordConfirmation,
              'batch_id': batchId,
              'training_id': trainingId,
              'jenis_kelamin': gender,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  // ─── PROFILE ──────────────────────────────────────────────────────────────

  /// Get profile user
  Future<Map<String, dynamic>> getProfile({required String token}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl${Constants.profileEndpoint}'),
            headers: _headers(token: token),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  /// Update profile user — PUT /edit-profile
  /// Field yang bisa diubah: name (dan phone jika API support)
  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String name,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;

      final response = await http
          .put(
            Uri.parse('$_baseUrl${Constants.editProfileEndpoint}'),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  /// Update foto profil — PUT /profile/photo (multipart)
  Future<Map<String, dynamic>> updateProfilePhoto({
    required String token,
    required File photo,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http
        .put(
          Uri.parse('$_baseUrl${Constants.editProfilePhotoEndpoint}'),
          headers: _headers(token: token),
          body: jsonEncode({
            'profile_photo': base64Image,
          }),
        )
        .timeout(const Duration(seconds: 30));
      // final request = http.MultipartRequest(
      //   'POST', // beberapa Laravel API pakai POST + _method spoofing
      //   Uri.parse('$_baseUrl${Constants.editProfilePhotoEndpoint}'),
      // );

      // request.headers.addAll({
      //   'Authorization': 'Bearer $token',
      //   'Accept': 'application/json',
      // });

      // // Spoofing PUT karena multipart di Laravel sering pakai POST + _method
      // request.fields['_method'] = 'PUT';

      // print("PHOTO PATH: ${photo.path}");
      // print("EXISTS: ${photo.existsSync()}");

      // request.files.add(await http.MultipartFile.fromPath(
      //   'profile_photo', // ← nama field sesuai API
      //   photo.path,
      // ));

      // final streamed = await request.send().timeout(const Duration(seconds: 30));
      // final response = await http.Response.fromStream(streamed);

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  // ─── ABSEN ───────────────────────────────────────────────────────────────

  /// Get riwayat absen
  Future<Map<String, dynamic>> getAbsenHistory({required String token}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl${Constants.absenEndpoint}'),
            headers: _headers(token: token),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  /// Check in absen
  Future<Map<String, dynamic>> checkIn({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/absen-check-in'),
            headers: _headers(token: token),
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  /// Check out absen
  Future<Map<String, dynamic>> checkOut({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/absen-check-out'),
            headers: _headers(token: token),
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _parseResponse(response);
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }

  /// Get list batch (untuk dropdown register)
  Future<List<dynamic>> getBatches() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl${Constants.batchEndpoint}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is List) return data;
        return [];
      }

      throw ApiException(
        message: 'Gagal memuat batch',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw ApiException(message: 'Tidak ada koneksi internet.');
    } on HttpException {
      throw ApiException(message: 'Gagal terhubung ke server.');
    } on FormatException {
      throw ApiException(message: 'Format response tidak valid.');
    }
  }
}

// ─── Custom Exception ─────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
