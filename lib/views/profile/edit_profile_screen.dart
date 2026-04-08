import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/shared_pref.dart';
import 'package:image_picker/image_picker.dart';


class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  late final TextEditingController _nameController;

  bool _isLoading = false;
  bool _hasChanges = false;
  String? _errorMessage;
  File? _pickedPhoto;        // file foto yang dipilih user
  bool _isUploadingPhoto = false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
      print("AVATAR URL: ${widget.user.avatar}");

    _nameController = TextEditingController(text: widget.user.name ?? '');
    _nameController.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkChanges);
    _nameController.dispose();
    super.dispose();
  }

  // ─── Change Detection ─────────────────────────────────────────────────────

  void _checkChanges() {
    final nameChanged = _nameController.text.trim() != (widget.user.name ?? '');
    // final photoChanged = _pickedPhoto != null;
    // final hasChanges = nameChanged || photoChanged;

    if (nameChanged != _hasChanges) {
      setState(() => _hasChanges = nameChanged);
    }
  }

  // ─── Save Logic ───────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges) return;

    setState(() => _isLoading = true);

    try {
      final token = await SharedPref.getToken();
      if (token == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Panggil API PUT /edit-profile — hanya kirim name
      final response = await _apiService.updateProfile(
        token: token,
        name: _nameController.text.trim(),
      );

      final isSuccess = response['status'] == true ||
          response['message']
                  ?.toString()
                  .toLowerCase()
                  .contains('berhasil') ==
              true;

      if (!isSuccess) {
        setState(() => _errorMessage =
            response['message']?.toString() ?? 'Gagal menyimpan perubahan.');
        return;
      }

      // Pakai data dari response jika ada, fallback update lokal
      final updatedData = response['data'];
      final UserModel updatedUser;

      // SESUDAH (merge dengan data lama biar batch/training/gender gak ilang):
      if (updatedData is Map<String, dynamic>) {
        updatedUser = widget.user.copyWith(
          name: updatedData['name'] as String? ?? _nameController.text.trim(),
          // update avatar kalau API return yang baru
          avatar: updatedData['profile_photo_url'] as String? ?? widget.user.avatar,
        );
      } else {
        updatedUser = widget.user.copyWith(
          name: _nameController.text.trim(),
        );
      }

      await SharedPref.saveUser(updatedUser);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, updatedUser);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Gagal menyimpan perubahan.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // foto upload logic
    Future<void> _handlePhotoUpload() async {
    // Pilih sumber foto
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Foto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.indigo),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.indigo),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _pickedPhoto = file;
      _isUploadingPhoto = true;
    });
    _checkChanges();

    try {
      final token = await SharedPref.getToken();
      if (token == null) return;

      final response = await _apiService.updateProfilePhoto(
        token: token,
        photo: file,
      );

      // Response: { "data": { "profile_photo": "https://..." } }
      final photoUrl = response['data']?['profile_photo'] as String?;

      if (photoUrl != null) {
        final updatedUser = widget.user.copyWith(avatar: photoUrl);
        await SharedPref.saveUser(updatedUser);

        if (!mounted) return;
        setState(() {
          _pickedPhoto = null;
          _isUploadingPhoto = false;
          _hasChanges = false; // penting
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
          Navigator.pop(context, updatedUser); // langsung balik
        //  setState(() {
        //     _pickedPhoto = null;
        //     _isUploadingPhoto = false;
        //     _hasChanges = false;
        //   });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _pickedPhoto = null); // rollback preview
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pickedPhoto = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengupload foto.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ─── Konfirmasi Discard ───────────────────────────────────────────────────

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Buang Perubahan?'),
        content: const Text(
            'Perubahan yang kamu buat belum disimpan. Yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap Edit',
                style: TextStyle(color: Colors.indigo)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Buang', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAvatarSection(),
                  const SizedBox(height: 28),

                  if (_errorMessage != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 16),
                  ],

                  _buildEditableSection(),
                  const SizedBox(height: 16),

                  _buildReadOnlySection(),
                  const SizedBox(height: 32),

                  _buildSaveButton(),
                  const SizedBox(height: 12),
                  _buildCancelButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('Edit Profil',
          style: TextStyle(fontWeight: FontWeight.w600)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () async {
          final shouldPop = await _confirmDiscard();
          if (shouldPop && context.mounted) Navigator.pop(context);
        },
      ),
      actions: [
        if (_hasChanges && !_isLoading)
          TextButton(
            onPressed: _handleSave,
            child: const Text('Simpan',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  // ─── Avatar ───────────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.indigo, width: 3),
              color: Colors.indigo.shade100,
            ),
            child: ClipOval(
              child: _isUploadingPhoto
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.indigo, strokeWidth: 2))
                : _pickedPhoto != null
                    ? Image.file(_pickedPhoto!, fit: BoxFit.cover)
                    : widget.user.avatar != null
                        ? Image.network(
                            widget.user.avatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          )
                        : _defaultAvatar(),
            ),
          ),
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _handlePhotoUpload,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isUploadingPhoto ? Colors.grey : Colors.indigo,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error Banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
          ),
        ],
      ),
    );
  }

  // ─── Editable Section ─────────────────────────────────────────────────────

  Widget _buildEditableSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data yang bisa diubah',
            style: TextStyle(
                fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // Nama — satu-satunya field yang bisa diedit
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (_) => _handleSave(),
            decoration: _inputDecoration(
              label: 'Nama Lengkap',
              icon: Icons.person_outline,
              hint: 'Masukkan nama lengkap',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama tidak boleh kosong';
              }
              if (value.trim().length < 3) return 'Nama minimal 3 karakter';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─── Read-Only Section ────────────────────────────────────────────────────

  Widget _buildReadOnlySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Data tidak bisa diubah',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 16),

          _ReadOnlyField(
            icon: Icons.email_outlined,
            label: 'Email',
            value: widget.user.email ?? '-',
          ),
          const SizedBox(height: 12),

          _ReadOnlyField(
            icon: Icons.wc_outlined,
            label: 'Jenis Kelamin',
            value: widget.user.genderLabel,
          ),
          const SizedBox(height: 12),

          _ReadOnlyField(
            icon: Icons.groups_outlined,
            label: 'Batch',
            value: widget.user.batchLabel,
          ),
          const SizedBox(height: 12),

          _ReadOnlyField(
            icon: Icons.school_outlined,
            label: 'Jurusan / Training',
            value: widget.user.trainingTitle ?? '-',
          ),
          const SizedBox(height: 12),

          _ReadOnlyField(
            icon: Icons.badge_outlined,
            label: 'ID Pengguna',
            value: widget.user.id?.toString() ?? '-',
          ),
        ],
      ),
    );
  }

  // ─── Save Button ──────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: (_isLoading || !_hasChanges) ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.indigo.shade200,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                _hasChanges ? 'Simpan Perubahan' : 'Tidak Ada Perubahan',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ─── Cancel Button ────────────────────────────────────────────────────────

  Widget _buildCancelButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading
            ? null
            : () async {
                final shouldPop = await _confirmDiscard();
                if (shouldPop && context.mounted) Navigator.pop(context);
              },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Batal',
            style: TextStyle(fontSize: 15, color: Colors.grey)),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _defaultAvatar() {
    return Container(
      color: Colors.indigo.shade100,
      child: const Icon(Icons.person, size: 52, color: Colors.indigo),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.indigo, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }
}

// ─── Sub-Widget ───────────────────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}