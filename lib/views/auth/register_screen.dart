import 'package:flutter/material.dart';
import '../../models/batch_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();

  // ── Batch ──
  List<BatchModel> _batches = [];
  BatchModel? _selectedBatch;
  bool _isLoadingBatch = true;
  String? _batchError;

  // ── Jurusan ──
  TrainingModel? _selectedTraining;

  // ── Jenis Kelamin ──
  String? _selectedGender;

  // ── Form State ──
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── Fetch Batches ────────────────────────────────────────────────────────

  Future<void> _fetchBatches() async {
    setState(() {
      _isLoadingBatch = true;
      _batchError = null;
    });

    try {
      final List<dynamic> data = await _apiService.getBatches();

      if (data.isEmpty) {
        setState(() => _batchError = 'Belum ada batch tersedia.');
        return;
      }

      final parsed = data
          .map((e) => BatchModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() => _batches = parsed);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _batchError = e.message);
    } catch (e) {
      if (mounted) setState(() => _batchError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingBatch = false);
    }
  }

  // ─── Register Logic ───────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      setState(() => _errorMessage = 'Silakan pilih jenis kelamin.');
      return;
    }

    if (_selectedBatch == null) {
      setState(() => _errorMessage = 'Silakan pilih batch terlebih dahulu.');
      return;
    }

    if (_selectedTraining == null) {
      setState(() => _errorMessage = 'Silakan pilih jurusan terlebih dahulu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        batchId: _selectedBatch!.id!,
        trainingId: _selectedTraining!.id!,
        gender: _selectedGender!,
      );

      // ✅ API tidak pakai 'status', cek message-nya
      final message = response['message']?.toString() ?? '';
      final bool berhasil = message.toLowerCase().contains('berhasil') ||
          response['data'] != null;
      if (!berhasil) {
        setState(() => _errorMessage = message.isNotEmpty ? message : 'Registrasi gagal.');
        return;
      }

      if (!mounted) return;

        // setState(() {
        //   _errorMessage = '';
        // });
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registrasi berhasil! Silakan login.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));

      Navigator.pushReplacementNamed(context, '/login');
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Terjadi kesalahan tidak terduga.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.indigo),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 60,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Buat Akun Baru',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Text(
                    'Daftar untuk mulai absensi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // ── Error Banner ──
                  if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                    _buildErrorBanner(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // ── Nama Lengkap ──
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      label: 'Nama Lengkap',
                      icon: Icons.person_outline,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      if (value.trim().length < 3) {
                        return 'Nama minimal 3 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Email ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value.trim())) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Password ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Password',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Konfirmasi Password ──
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleRegister(),
                    decoration: _inputDecoration(
                      label: 'Konfirmasi Password',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Konfirmasi password tidak boleh kosong';
                      }
                      if (value != _passwordController.text) {
                        return 'Password tidak cocok';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Jenis Kelamin ──
                  _buildGenderPicker(),
                  const SizedBox(height: 14),

                  // ── Dropdown Batch ──
                  _buildBatchDropdown(),
                  const SizedBox(height: 14),

                  // ── Dropdown Jurusan ──
                  _buildTrainingDropdown(),
                  const SizedBox(height: 28),

                  // ── Tombol Daftar ──
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Link ke Login ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sudah punya akun? ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          '/login',
                        ),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Gender Picker ───────────────────────────────────────────────────────────────
  Widget _buildGenderPicker() {
    return FormField<String>(
      initialValue: _selectedGender,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Jenis kelamin wajib dipilih';
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Jenis Kelamin',
                style: TextStyle(
                  fontSize: 13,
                  color: field.hasError ? Colors.red.shade400 : Colors.grey.shade700,
                ),
              ),
            ),

            // Pilihan L / P
            Row(
              children: [
                // Laki-laki
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedGender = 'L');
                      field.didChange('L');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedGender == 'L'
                            ? Colors.indigo
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: field.hasError
                              ? Colors.red.shade400
                              : _selectedGender == 'L'
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                          width: _selectedGender == 'L' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.male,
                            color: _selectedGender == 'L'
                                ? Colors.white
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Laki-laki',
                            style: TextStyle(
                              color: _selectedGender == 'L'
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: _selectedGender == 'L'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Perempuan
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedGender = 'P');
                      field.didChange('P');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedGender == 'P'
                            ? Colors.pink.shade400
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: field.hasError
                              ? Colors.red.shade400
                              : _selectedGender == 'P'
                                  ? Colors.pink.shade400
                                  : Colors.grey.shade300,
                          width: _selectedGender == 'P' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.female,
                            color: _selectedGender == 'P'
                                ? Colors.white
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Perempuan',
                            style: TextStyle(
                              color: _selectedGender == 'P'
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: _selectedGender == 'P'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Error text
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── Batch Dropdown ───────────────────────────────────────────────────────

  Widget _buildBatchDropdown() {
    if (_isLoadingBatch) {
      return _loadingField('Memuat daftar batch...');
    }

    if (_batchError != null) {
      return _errorField(_batchError!, onRetry: _fetchBatches);
    }

    return DropdownButtonFormField<BatchModel>(
      value: _selectedBatch,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.indigo),
      decoration: _inputDecoration(
        label: 'Pilih Batch',
        icon: Icons.groups_outlined,
      ),
      hint: const Text(
        'Pilih batch kamu',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      items: _batches.map((batch) {
        return DropdownMenuItem<BatchModel>(
          value: batch,
          child: Text(
            batch.displayName,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() {
        _selectedBatch = value;
        _selectedTraining = null; // reset jurusan saat ganti batch
      }),
      validator: (value) {
        if (value == null) return 'Batch wajib dipilih';
        return null;
      },
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(10),
    );
  }

  // ─── Training Dropdown ────────────────────────────────────────────────────

  Widget _buildTrainingDropdown() {
    // Belum pilih batch
    if (_selectedBatch == null) {
      return _disabledField(
        'Pilih batch terlebih dahulu',
        Icons.school_outlined,
      );
    }

    // Batch dipilih tapi tidak ada jurusan
    if (_selectedBatch!.trainings.isEmpty) {
      return _disabledField(
        'Tidak ada jurusan di batch ini',
        Icons.info_outline,
      );
    }

    return DropdownButtonFormField<TrainingModel>(
      value: _selectedTraining,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.indigo),
      decoration: _inputDecoration(
        label: 'Pilih Jurusan',
        icon: Icons.school_outlined,
      ),
      hint: const Text(
        'Pilih jurusan kamu',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      items: _selectedBatch!.trainings.map((training) {
        return DropdownMenuItem<TrainingModel>(
          value: training,
          child: Text(
            training.displayName,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedTraining = value),
      validator: (value) {
        if (value == null) return 'Jurusan wajib dipilih';
        return null;
      },
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(10),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  // Field loading state
  Widget _loadingField(String text) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  // Field disabled state
  Widget _disabledField(String text, IconData icon) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Field error state dengan retry
  Widget _errorField(String message, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Coba lagi',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo),
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