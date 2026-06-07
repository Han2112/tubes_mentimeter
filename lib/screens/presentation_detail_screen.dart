import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'add_slide_screen.dart';
import 'live_presentation_screen.dart';

class PresentationDetailScreen extends StatefulWidget {
  final String presentationId;
  final String title;
  final String joinCode;

  const PresentationDetailScreen({
    super.key,
    required this.presentationId,
    required this.title,
    required this.joinCode,
  });

  @override
  State<PresentationDetailScreen> createState() =>
      _PresentationDetailScreenState();
}

class _PresentationDetailScreenState extends State<PresentationDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _slides = [];

  @override
  void initState() {
    super.initState();
    _fetchSlides();
  }

  Future<void> _fetchSlides() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('slides')
          .select()
          .eq('presentation_id', widget.presentationId)
          .order('order_num', ascending: true);

      setState(() {
        _slides = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showSnackBar('Gagal memuat daftar slide.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSlide(String slideId) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('slides').delete().eq('id', slideId);
      _showSnackBar('Slide berhasil dihapus.');
      _fetchSlides();
    } catch (e) {
      _showSnackBar('Gagal menghapus slide.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(String slideId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Slide?'),
        content: const Text(
          'Slide ini beserta opsi jawabannya akan dihapus secara permanen.',
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
              _deleteSlide(slideId);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // INI BAGIAN PENTING: Navigasi yang benar ke AddSlideScreen
  void _navigateToAddSlide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddSlideScreen(presentationId: widget.presentationId),
      ),
    ).then((_) => _fetchSlides());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Detail Presentasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Join Code: ${widget.joinCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LivePresentationScreen(
                                presentationId: widget.presentationId,
                                title: widget.title,
                                joinCode: widget.joinCode,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF4F46E5),
                        ),
                        label: const Text(
                          'Mulai',
                          style: TextStyle(color: Color(0xFF4F46E5)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              'QR Code',
                              textAlign: TextAlign.center,
                            ),
                            content: QrImageView(
                              data: widget.joinCode,
                              size: 200,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        elevation: 0,
                      ),
                      child: const Icon(
                        Icons.qr_code_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Slide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed:
                      _navigateToAddSlide, // Memanggil fungsi navigasi yang benar
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah Slide'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slides.isEmpty
                ? _buildEmptyState()
                : _buildSlideList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Belum ada slide. Tekan "Tambah Slide".',
        style: TextStyle(color: Colors.grey.shade500),
      ),
    );
  }

  Widget _buildSlideList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _slides.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final slide = _slides[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
              child: Text('${index + 1}'),
            ),
            title: Text(
              slide['question'] ?? 'Tanpa Pertanyaan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Tipe: ${slide['type'].toString().toUpperCase()}'),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: () => _confirmDelete(slide['id']),
            ),
          ),
        );
      },
    );
  }
}
