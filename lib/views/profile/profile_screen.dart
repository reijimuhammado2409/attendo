import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/shared_pref.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;

  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user == null) _fetchProfile();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user && widget.user != null) {
      setState(() => _user = widget.user);
    }
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SharedPref.getToken();
      if (token == null) {
        _redirectToLogin();
        return;
      }

      final response = await _apiService.getProfile(token: token);

      // API ini pakai key "data" bukan "status"
      final data = response['data'];
      if (data != null && mounted) {
        final user = UserModel.fromJson(data as Map<String, dynamic>);
        await SharedPref.saveUser(user);
        setState(() => _user = user);
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Gagal memuat profil.';
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _redirectToLogin();
        return;
      }
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Terjadi kesalahan.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Keluar', style: TextStyle(color: Colors.white)),
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

  Future<void> _goToEditProfile() async {
    if (_user == null) return;

    final updatedUser = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
    );

    if (updatedUser != null && mounted) {
      setState(() => _user = updatedUser);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchProfile,
        color: Colors.indigo,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildBody()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: Colors.indigo.shade300,
                ),
                child: ClipOval(
                  child: _user?.avatar != null
                      ? Image.network(
                          _user!.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
              GestureDetector(
                onTap: _goToEditProfile,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.indigo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Nama
          _isLoading
              ? _shimmer(width: 140, height: 20)
              : Text(
                  _user?.name ?? '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),

          // Email
          _isLoading
              ? _shimmer(width: 180, height: 14)
              : Text(
                  _user?.email ?? '-',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
          const SizedBox(height: 8),

          // Badge batch + jurusan
          if (!_isLoading && _user != null) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_user!.batchKe != null)
                  _buildBadge(
                    icon: Icons.groups_outlined,
                    label: _user!.batchLabel,
                  ),
                if (_user!.jenisKelamin != null)
                  _buildBadge(
                    icon: _user!.jenisKelamin == 'L'
                        ? Icons.male_outlined
                        : Icons.female_outlined,
                    label: _user!.genderLabel,
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          const SizedBox(height: 12),

          // Tombol Edit Profil
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _goToEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
            label: const Text('Edit Profil',
                style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading && _user == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: Colors.indigo)),
      );
    }

    if (_errorMessage != null && _user == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchProfile,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Informasi Akun ──
          _sectionTitle('Informasi Akun'),
          const SizedBox(height: 12),
          _InfoCard(
            items: [
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Nama Lengkap',
                value: _user?.name ?? '-',
              ),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _user?.email ?? '-',
              ),
              _InfoRow(
                icon: Icons.wc_outlined,
                label: 'Jenis Kelamin',
                value: _user?.genderLabel ?? '-',
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Informasi Pelatihan ──
          _sectionTitle('Informasi Pelatihan'),
          const SizedBox(height: 12),
          _InfoCard(
            items: [
              _InfoRow(
                icon: Icons.school_outlined,
                label: 'Jurusan / Training',
                value: _user?.trainingTitle ?? '-',
              ),
              _InfoRow(
                icon: Icons.groups_outlined,
                label: 'Batch',
                value: _user != null ? _buildBatchValue(_user!) : '-',
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Informasi Akun ──
          _sectionTitle('Informasi Lainnya'),
          const SizedBox(height: 12),
          _InfoCard(
            items: [
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'ID Pengguna',
                value: _user?.id?.toString() ?? '-',
              ),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Bergabung Sejak',
                value: _formatDate(_user?.createdAt),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Pengaturan ──
          _sectionTitle('Pengaturan'),
          const SizedBox(height: 12),
          _SettingCard(
            items: [
              _SettingRow(
                icon: Icons.lock_outline,
                label: 'Ubah Password',
                color: Colors.indigo,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur segera hadir'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _SettingRow(
                icon: Icons.notifications_outlined,
                label: 'Notifikasi',
                color: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur segera hadir'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _SettingRow(
                icon: Icons.logout,
                label: 'Keluar',
                color: Colors.red,
                isLast: true,
                onTap: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Bangun string lengkap untuk value batch
  String _buildBatchValue(UserModel user) {
    final ke = user.batchLabel; // "Batch 2"
    final batch = user.batch;
    if (batch == null) return ke;

    final start = batch['start_date'] as String?;
    final end = batch['end_date'] as String?;
    if (start != null && end != null) {
      return '$ke  •  ${_formatDateShort(start)} – ${_formatDateShort(end)}';
    }
    return ke;
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.indigo.shade300,
      child: const Icon(Icons.person, size: 48, color: Colors.white),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _shimmer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final date = DateTime.parse(raw);
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDateShort(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: Colors.indigo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<_SettingRow> items;
  const _SettingCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(14))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color == Colors.red
                          ? Colors.red
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}
