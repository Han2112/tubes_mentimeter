import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audience_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/app_toast.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinPresentation() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || code.length < 6) {
      _showSnackBar('Masukkan 6 digit kode dengan benar.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Cari presentasi berdasarkan join_code
      // Gunakan maybeSingle() agar tidak error 406 jika data tidak ditemukan
      final presentation = await _supabase
          .from('presentations')
          .select()
          .eq('join_code', code)
          .maybeSingle();

      if (presentation == null) {
        _showSnackBar(
          'Kelas tidak ditemukan. Periksa kembali kode Anda.',
          isError: true,
        );
      } else {
        if (mounted) {
          // Beralih ke halaman Audiens
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudienceScreen(
                presentationId: presentation['id'],
                title: presentation['title'],
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan saat mencari kelas.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    AppToast.show(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Join Kelas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ilustrasi Ikon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 80,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 32),

                // Teks Panduan
                Text(
                  'Masukkan Kode',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ketik 6 digit kode yang diberikan oleh presenter untuk bergabung ke sesi interaktif.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 48),

                // Input Kode Join
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEAEAF0),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10,
                      color: Color(0xFF111827),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '. . . . . .',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade300,
                        letterSpacing: 8,
                        fontSize: 20,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(vertical: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Tombol Join
                ElevatedButton(
                  onPressed: _isLoading ? null : _joinPresentation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Gabung Sekarang',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
                const SizedBox(height: 24),

                // Pembatas
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'ATAU',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                // Tombol Scan QR (Fiturnya akan kita buat nanti)
                OutlinedButton.icon(
                  onPressed: () async {
                    // Buka scanner dan tunggu hasil kodenya
                    final scannedCode = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRScannerScreen(),
                      ),
                    );

                    // Jika mendapatkan kode, masukkan ke controller
                    if (scannedCode != null) {
                      setState(() {
                        _codeController.text = scannedCode;
                      });
                      // Langsung eksekusi join
                      _joinPresentation();
                    }
                  },
                  icon: const Icon(Icons.qr_code_rounded, size: 24),
                  label: const Text('Scan QR Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: const Color(0xFF1F2937),
                    side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
