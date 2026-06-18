import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'add_slide_screen.dart';
import 'live_presentation_screen.dart';
import '../services/dummy_slide_service.dart';
import '../services/report_export_service.dart';
import '../widgets/app_toast.dart';

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
  late final DummySlideService _dummySlideService;
  late final ReportExportService _reportExportService;

  @override
  void initState() {
    super.initState();
    _dummySlideService = DummySlideService(_supabase);
    _reportExportService = ReportExportService(_supabase);
    _fetchSlides();
  }

  Future<void> _fetchSlides() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('slides')
          .select('*, options(*)')
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
    AppToast.show(context, message, isError: isError);
  }

  void _navigateToAddSlide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddSlideScreen(presentationId: widget.presentationId),
      ),
    ).then((_) => _fetchSlides());
  }

  void _navigateToEditSlide(Map<String, dynamic> slide) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddSlideScreen(presentationId: widget.presentationId, slide: slide),
      ),
    ).then((_) => _fetchSlides());
  }

  Future<void> _downloadReport(String type) async {
    try {
      if (type == 'pdf') {
        await _reportExportService.exportPdf(
          presentationId: widget.presentationId,
          title: widget.title,
          joinCode: widget.joinCode,
        );
      } else {
        await _reportExportService.exportExcel(
          presentationId: widget.presentationId,
          title: widget.title,
        );
      }
    } catch (e) {
      _showSnackBar('Gagal mengunduh laporan: $e', isError: true);
    }
  }

  Future<void> _createDummyQuestions() async {
    setState(() => _isLoading = true);
    try {
      await _dummySlideService.createForPresentation(widget.presentationId);
      _showSnackBar('Dummy pertanyaan berhasil ditambahkan.');
      await _fetchSlides();
    } catch (e) {
      debugPrint('Gagal menambahkan dummy pertanyaan: $e');
      _showSnackBar('Gagal menambahkan dummy pertanyaan.', isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF4F46E5)),
            onSelected: _downloadReport,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
              PopupMenuItem(value: 'excel', child: Text('Download Excel')),
            ],
          ),
          const SizedBox(width: 8),
        ],
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
                            // Perbaikan: QrImageView dibungkus SizedBox agar Web tidak bingung merendernya
                            content: SizedBox(
                              width: 200,
                              height: 200,
                              child: QrImageView(
                                data: widget.joinCode,
                                version: QrVersions.auto,
                                size: 200.0,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Tutup'),
                              ),
                            ],
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
                  onPressed: _navigateToAddSlide,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'Belum ada pertanyaan.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan slide manual atau isi dummy untuk demo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _createDummyQuestions,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Isi Dummy Pertanyaan'),
            ),
          ],
        ),
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
        const typeIcons = {
          'polling': Icons.poll_outlined,
          'quiz': Icons.quiz_outlined,
          'word_cloud': Icons.cloud_outlined,
          'likert': Icons.linear_scale_rounded,
          'ranking': Icons.format_list_numbered_rounded,
          'qna': Icons.forum_outlined,
        };
        final icon = typeIcons[slide['type']] ?? Icons.help_outline;

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEDFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
            ),
            title: Text(
              slide['question'] ?? 'Tanpa Pertanyaan',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF111827),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _typeLabel(slide['type'].toString()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: Color(0xFFD1D5DB),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${slide['timer_seconds'] ?? 30}s',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD1D5DB),
                    ),
                  ),
                ],
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF9CA3AF),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditSlide(slide);
                } else if (value == 'delete') {
                  _confirmDelete(slide['id']);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 8),
                      Text('Hapus'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'polling':
        return 'Polling';
      case 'quiz':
        return 'Kuis';
      case 'word_cloud':
        return 'Word Cloud';
      case 'likert':
        return 'Likert';
      case 'ranking':
        return 'Ranking';
      case 'qna':
        return 'Q&A Anonim';
      default:
        return type.toUpperCase();
    }
  }
}
