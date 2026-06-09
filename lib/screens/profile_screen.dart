import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import '../widgets/app_toast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isUploading = false;
  bool _useFingerprint = true; // Status toggle fingerprint
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Mengambil data user dari database Supabase
  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      setState(() {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _imageUrl = data['photo_url'];
        // Jika fingerprint_data 'enabled', maka true
        _useFingerprint = (data['fingerprint_data'] == 'enabled');
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Gagal memuat data profil', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // Fungsi Upload Foto Profil
  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Kompresi gambar agar tidak terlalu besar
      maxWidth: 800,
      maxHeight: 800,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName =
          '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Upload ke Supabase Storage (bucket: avatars)
      await _supabase.storage.from('avatars').upload(fileName, file);

      // 2. Dapatkan Public URL dari foto tersebut
      final imageUrlResponse = _supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // 3. Update database profiles dengan URL baru
      await _supabase
          .from('profiles')
          .update({'photo_url': imageUrlResponse})
          .eq('id', userId);

      setState(() {
        _imageUrl = imageUrlResponse;
      });

      _showSnackBar('Foto profil berhasil diperbarui!');
    } catch (e) {
      _showSnackBar('Gagal mengupload foto profil', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Fungsi Simpan Perubahan (Nama & Setting Fingerprint)
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('profiles')
          .update({
            'name': _nameController.text.trim(),
            'fingerprint_data': _useFingerprint ? 'enabled' : 'disabled',
          })
          .eq('id', userId);

      _showSnackBar('Profil berhasil disimpan!');
    } catch (e) {
      _showSnackBar('Gagal menyimpan profil', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fungsi Logout
  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // Hapus semua rute sebelumnya dan kembali ke Login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    AppToast.show(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Foto Profil & Tombol Edit
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                    image: _imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (_isUploading)
                  const Positioned.fill(
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploading ? null : _uploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Form Nama Lengkap
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Form Email (Read Only karena email tidak bisa diganti sembarangan)
            TextField(
              controller: _emailController,
              readOnly: true,
              style: const TextStyle(color: Colors.grey),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Pengaturan Fingerprint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Login dengan Fingerprint',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Gunakan biometrik untuk login cepat'),
                activeColor: const Color(0xFF4F46E5),
                value: _useFingerprint,
                onChanged: (bool value) {
                  setState(() {
                    _useFingerprint = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Simpan Perubahan
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateProfile,
                child: const Text('Simpan Perubahan'),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
