class Constants {
  static const String baseUrl = 'https://appabsensi.mobileprojp.com/api';

  // Endpoints
  static const String loginEndpoint = '/login';
  static const String registerEndpoint = '/register';
  static const String profileEndpoint = '/profile';
  static const String editProfileEndpoint = '/profile'; // ← TAMBAH INI
  static const String editProfilePhotoEndpoint = '/profile/photo'; // ← TAMBAH INI
  static const String absenEndpoint = '/absen';
  static const String batchEndpoint = '/batches';

  // SharedPreferences Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
