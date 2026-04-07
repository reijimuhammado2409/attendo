import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/absen_model.dart';
import '../../services/api_service.dart';
import '../../utils/shared_pref.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();

  int _currentIndex = 0;

  UserModel? _user;
  List<AbsenModel> _recentAbsen = [];

  bool _isLoadingUser = true;
  bool _isLoadingAbsen = true;
  String? _errorUser;
  String? _errorAbsen;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ─── Data Fetching ────────────────────────────────────────────────────────

  Future<void> _loadDashboardData() async {
    await Future.wait([_fetchUser(), _fetchRecentAbsen()]);
  }

  Future<void> _fetchUser() async {
    setState(() {
      _isLoadingUser = true;
      _errorUser = null;
    });

    try {
      // Coba ambil dari cache dulu (lebih cepat)
      final cachedUser = await SharedPref.getUser();
      if (cachedUser != null && mounted) {
        setState(() => _user = cachedUser);
      }

      // Tetap fetch dari API untuk data terbaru
      final token = await SharedPref.getToken();
      if (token == null) {
        _redirectToLogin();
        return;
      }

      final response = await _apiService.getProfile(token: token);
      if (response['status'] == true) {
        final data = response['data'];
        if (data != null && mounted) {
          try {
            // Handle kalau data['user'] nested atau langsung flat
            final userJson = (data is Map<String, dynamic> && data.containsKey('user'))
                ? data['user'] as Map<String, dynamic>
                : data as Map<String, dynamic>;
            final user = UserModel.fromJson(userJson);
            await SharedPref.saveUser(user);
            setState(() => _user = user);
          } catch (_) {
            // Gagal parse profile dari API, pakai cache yang sudah ada
            // _user sudah diset dari cachedUser di atas, jadi tidak masalah
          }         
        }
      }
    } on ApiException catch (e) {
      // Jika 401 → paksa logout
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      if (mounted) setState(() => _errorUser = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorUser = 'Gagal memuat profil.');
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _fetchRecentAbsen() async {
    setState(() {
      _isLoadingAbsen = true;
      _errorAbsen = null;
    });

    try {
      final token = await SharedPref.getToken();
      if (token == null) return;

      final response = await _apiService.getAbsenHistory(token: token);
      if (response['status'] == true) {
        final rawList = response['data'];
        if (rawList is List && mounted) {
          // Ambil 5 data terbaru saja untuk dashboard
          final absenList = rawList
              .take(5)
              .map((e) => AbsenModel.fromJson(e as Map<String, dynamic>))
              .toList();
          setState(() => _recentAbsen = absenList);
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorAbsen = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorAbsen = 'Gagal memuat data absen.');
    } finally {
      if (mounted) setState(() => _isLoadingAbsen = false);
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah kamu yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SharedPref.clearAll();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _redirectToLogin() {
    SharedPref.clearAll().then((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Halaman yang ditampilkan sesuai tab
    final pages = [
      _buildHomePage(),
      const HistoryScreen(),
      ProfileScreen(user: _user),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: Colors.indigo.shade100,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.indigo),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Colors.indigo),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.indigo),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // ─── Home Page ────────────────────────────────────────────────────────────

  Widget _buildHomePage() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.indigo,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(child: _buildHeader()),

            // Stat Cards
            SliverToBoxAdapter(child: _buildStatCards()),

            // Recent Absen
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Absensi Terkini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 1),
                      child: const Text(
                        'Lihat Semua',
                        style: TextStyle(color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List Absen
            SliverToBoxAdapter(child: _buildRecentAbsen()),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final greeting = _getGreeting();
    final name = _user?.name ?? '...';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _isLoadingUser
                      ? const _ShimmerBox(width: 140, height: 22)
                      : Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tanggal hari ini
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Cards ───────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    // Hitung dari data lokal
    final hadir = _recentAbsen
        .where((a) => a.status == 'hadir')
        .length;
    final terlambat = _recentAbsen
        .where((a) => a.status == 'terlambat')
        .length;
    final izin = _recentAbsen
        .where((a) => a.status == 'izin')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Hadir',
              value: _isLoadingAbsen ? '-' : '$hadir',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Terlambat',
              value: _isLoadingAbsen ? '-' : '$terlambat',
              icon: Icons.access_time,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Izin',
              value: _isLoadingAbsen ? '-' : '$izin',
              icon: Icons.event_busy_outlined,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recent Absen List ────────────────────────────────────────────────────

  Widget _buildRecentAbsen() {
    if (_isLoadingAbsen) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: Colors.indigo),
        ),
      );
    }

    if (_errorAbsen != null) {
      return _ErrorTile(message: _errorAbsen!, onRetry: _fetchRecentAbsen);
    }

    if (_recentAbsen.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Belum ada data absensi',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _recentAbsen.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final absen = _recentAbsen[index];
        return _AbsenTile(absen: absen);
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi 👋';
    if (hour < 15) return 'Selamat Siang 👋';
    if (hour < 18) return 'Selamat Sore 👋';
    return 'Selamat Malam 👋';
  }

  String _formatDate(DateTime date) {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _AbsenTile extends StatelessWidget {
  final AbsenModel absen;

  const _AbsenTile({required this.absen});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(absen.status);
    final statusLabel = _statusLabel(absen.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  absen.date ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masuk: ${absen.checkIn ?? '-'}  •  Pulang: ${absen.checkOut ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Badge status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'hadir':
        return Colors.green;
      case 'terlambat':
        return Colors.orange;
      case 'izin':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat':
        return 'Terlambat';
      case 'izin':
        return 'Izin';
      default:
        return 'Tidak Diketahui';
    }
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorTile({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// Shimmer placeholder sederhana
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}