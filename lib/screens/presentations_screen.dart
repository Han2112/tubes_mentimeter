import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_toast.dart';

// Tambahan Import untuk navigasi ke halaman detail
import 'presentation_detail_screen.dart';

class PresentationsScreen extends StatefulWidget {
  const PresentationsScreen({super.key});

  @override
  State<PresentationsScreen> createState() => _PresentationsScreenState();
}

class _PresentationsScreenState extends State<PresentationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _presentations = [];

  @override
  void initState() {
    super.initState();
    _fetchPresentations();
  }

  // Mengambil data presentasi dari database
  Future<void> _fetchPresentations() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('presentations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _presentations = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showSnackBar('Gagal memuat presentasi.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Membuat Presentasi Baru
  Future<void> _createPresentation(String title) async {
    if (title.trim().isEmpty) return;

    // Generate 6 digit angka random untuk Join Code
    final String joinCode = (Random().nextInt(900000) + 100000).toString();
    final userId = _supabase.auth.currentUser!.id;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('presentations').insert({
        'user_id': userId,
        'title': title.trim(),
        'join_code': joinCode,
      });

      _showSnackBar('Presentasi berhasil dibuat!');
      _fetchPresentations(); // Refresh list
    } catch (e) {
      _showSnackBar('Gagal membuat presentasi.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // Menghapus Presentasi
  Future<void> _deletePresentation(String id) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('presentations').delete().eq('id', id);
      _showSnackBar('Presentasi berhasil dihapus.');
      _fetchPresentations(); // Refresh list
    } catch (e) {
      _showSnackBar('Gagal menghapus presentasi.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // Menampilkan Dialog untuk Input Judul Presentasi
  void _showCreateDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Presentasi Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Masukkan judul presentasi...',
            prefixIcon: Icon(Icons.title_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createPresentation(titleController.text);
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  // Konfirmasi sebelum menghapus
  void _confirmDelete(String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Presentasi?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$title"? Semua slide dan data polling di dalamnya akan hilang permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _deletePresentation(id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
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
          'Presentasi Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Buat Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _presentations.isEmpty
          ? _buildEmptyState()
          : _buildPresentationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.slideshow_rounded,
                size: 64,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Presentasi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat presentasi pertamamu sekarang dan mulai berinteraksi dengan audiens.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresentationsList() {
    return RefreshIndicator(
      onRefresh: _fetchPresentations,
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 100,
          top: 10,
        ),
        itemCount: _presentations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final p = _presentations[index];
          final dateString = p['created_at'].toString().split('T')[0];
          // Warna aksen bergantian biar tidak monoton
          final colors = [
            const Color(0xFF4F46E5),
            const Color(0xFF0EA5E9),
            const Color(0xFF10B981),
            const Color(0xFFF59E0B),
          ];
          final accent = colors[index % colors.length];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PresentationDetailScreen(
                    presentationId: p['id'],
                    title: p['title'],
                    joinCode: p['join_code'],
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p['join_code'],
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dateString,
                                style: const TextStyle(
                                  color: Color(0xFFD1D5DB),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE5E7EB),
                        size: 20,
                      ),
                      onPressed: () => _confirmDelete(p['id'], p['title']),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
