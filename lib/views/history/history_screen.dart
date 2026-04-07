import 'package:flutter/material.dart';
import '../../models/absen_model.dart';
import '../../services/api_service.dart';
import '../../utils/shared_pref.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _apiService = ApiService();

  List<AbsenModel> _allAbsen = [];
  List<AbsenModel> _filteredAbsen = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Filter aktif: 'semua' | 'hadir' | 'terlambat' | 'izin'
  String _activeFilter = 'semua';

  // Search
  final _searchController = TextEditingController();

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SharedPref.getToken();
      if (token == null) return;

      final response = await _apiService.getAbsenHistory(token: token);

      if (response['status'] == true) {
        final rawList = response['data'];
        if (rawList is List) {
          final list = rawList
              .map((e) => AbsenModel.fromJson(e as Map<String, dynamic>))
              .toList();

          if (mounted) {
            setState(() {
              _allAbsen = list;
              _applyFilter();
            });
          }
        }
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Gagal memuat riwayat.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Terjadi kesalahan.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Filter & Search ──────────────────────────────────────────────────────

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredAbsen = _allAbsen.where((absen) {
        // Filter status
        final matchStatus = _activeFilter == 'semua' ||
            absen.status?.toLowerCase() == _activeFilter;

        // Filter search (berdasarkan tanggal atau lokasi)
        final matchSearch = query.isEmpty ||
            (absen.date?.toLowerCase().contains(query) ?? false) ||
            (absen.location?.toLowerCase().contains(query) ?? false);

        return matchStatus && matchSearch;
      }).toList();
    });
  }

  void _setFilter(String filter) {
    setState(() => _activeFilter = filter);
    _applyFilter();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),

          // Search Bar
          _buildSearchBar(),

          // Filter Chips
          _buildFilterChips(),

          // Summary Row
          if (!_isLoading && _errorMessage == null) _buildSummaryRow(),

          // List
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riwayat Absensi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Semua rekap kehadiran kamu',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          IconButton(
            onPressed: _fetchHistory,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari berdasarkan tanggal atau lokasi...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo),
          ),
        ),
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final filters = ['semua', 'hadir', 'terlambat', 'izin'];
    final labels = {
      'semua': 'Semua',
      'hadir': 'Hadir',
      'terlambat': 'Terlambat',
      'izin': 'Izin',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: filters.map((filter) {
          final isActive = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[filter]!),
              selected: isActive,
              onSelected: (_) => _setFilter(filter),
              selectedColor: Colors.indigo,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isActive ? Colors.indigo : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Summary Row ──────────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final total = _allAbsen.length;
    final hadir = _allAbsen.where((a) => a.status == 'hadir').length;
    final terlambat = _allAbsen.where((a) => a.status == 'terlambat').length;
    final izin = _allAbsen.where((a) => a.status == 'izin').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(label: 'Total', value: '$total', color: Colors.indigo),
            _divider(),
            _SummaryItem(label: 'Hadir', value: '$hadir', color: Colors.green),
            _divider(),
            _SummaryItem(label: 'Terlambat', value: '$terlambat', color: Colors.orange),
            _divider(),
            _SummaryItem(label: 'Izin', value: '$izin', color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 28,
        width: 1,
        color: Colors.indigo.shade100,
      );

  // ─── Content ──────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.indigo),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchHistory,
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

    if (_filteredAbsen.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _activeFilter == 'semua'
                  ? 'Belum ada data absensi'
                  : 'Tidak ada data dengan filter ini',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: Colors.indigo,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filteredAbsen.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final absen = _filteredAbsen[index];
          return _HistoryCard(absen: absen);
        },
      ),
    );
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final AbsenModel absen;

  const _HistoryCard({required this.absen});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(absen.status);
    final statusLabel = _statusLabel(absen.status);
    final statusIcon = _statusIcon(absen.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: tanggal + badge status
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      absen.date ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Row: jam masuk, jam pulang, lokasi
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.login,
                    label: 'Masuk',
                    value: absen.checkIn ?? '-',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.logout,
                    label: 'Pulang',
                    value: absen.checkOut ?? '-',
                    color: Colors.red,
                  ),
                ),
                if (absen.location != null)
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.location_on_outlined,
                      label: 'Lokasi',
                      value: absen.location!,
                      color: Colors.indigo,
                    ),
                  ),
              ],
            ),
          ),

          // Catatan (jika ada)
          if (absen.note != null && absen.note!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      absen.note!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
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

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle;
      case 'terlambat':
        return Icons.access_time;
      case 'izin':
        return Icons.event_busy;
      default:
        return Icons.help_outline;
    }
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}