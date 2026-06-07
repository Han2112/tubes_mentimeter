import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AudienceScreen extends StatefulWidget {
  final String presentationId;
  final String title;

  const AudienceScreen({
    super.key,
    required this.presentationId,
    required this.title,
  });

  @override
  State<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends State<AudienceScreen> {
  final _supabase = Supabase.instance.client;
  final PageController _pageController =
      PageController(); // Tambahan controller navigasi

  bool _isLoading = true;
  List<dynamic> _slides = [];

  // Menyimpan data input audiens secara lokal sebelum dikirim
  final Map<String, String> _selectedOptions =
      {}; // Untuk Polling/Kuis: { slideId : optionId }
  final Map<String, TextEditingController> _textControllers =
      {}; // Untuk Word Cloud: { slideId : controller }

  // Menyimpan ID slide yang sudah dijawab agar tidak bisa spam
  final Set<String> _submittedSlideIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSlidesAndOptions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Mengambil data slide berserta opsi jawabannya dalam satu tarikan query
  Future<void> _fetchSlidesAndOptions() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('slides')
          .select('*, options(*)')
          .eq('presentation_id', widget.presentationId)
          .order('order_num', ascending: true);

      // Inisialisasi text controller untuk word cloud
      for (var slide in response) {
        if (slide['type'] == 'word_cloud') {
          _textControllers[slide['id']] = TextEditingController();
        }
      }

      setState(() {
        _slides = response;
      });
    } catch (e) {
      _showSnackBar('Gagal memuat slide presentasi.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Mengirim jawaban ke database
  Future<void> _submitResponse(String slideId, String type) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    Map<String, dynamic> responseData = {
      'slide_id': slideId,
      'user_id': userId,
    };

    if (type == 'polling' || type == 'quiz') {
      final optionId = _selectedOptions[slideId];
      if (optionId == null) {
        _showSnackBar(
          'Silakan pilih salah satu opsi terlebih dahulu.',
          isError: true,
        );
        return;
      }
      responseData['option_id'] = optionId;
    } else if (type == 'word_cloud') {
      final text = _textControllers[slideId]?.text.trim();
      if (text == null || text.isEmpty) {
        _showSnackBar('Jawaban tidak boleh kosong.', isError: true);
        return;
      }
      responseData['text_response'] = text;
    }

    try {
      await _supabase.from('responses').insert(responseData);

      setState(() {
        _submittedSlideIds.add(slideId); // Tandai slide sudah dijawab
      });
      _showSnackBar('Jawaban berhasil dikirim!');
    } catch (e) {
      _showSnackBar('Gagal mengirim jawaban.', isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _slides.isEmpty
          ? const Center(child: Text('Belum ada slide di presentasi ini.'))
          : PageView.builder(
              controller:
                  _pageController, // Menghubungkan controller ke PageView
              physics: const BouncingScrollPhysics(),
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return _buildSlideCard(
                  _slides[index],
                  index + 1,
                  _slides.length,
                );
              },
            ),
    );
  }

  Widget _buildSlideCard(
    Map<String, dynamic> slide,
    int currentNum,
    int totalSlides,
  ) {
    final slideId = slide['id'];
    final type = slide['type'];
    final isSubmitted = _submittedSlideIds.contains(slideId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Indikator Halaman
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Slide $currentNum dari $totalSlides',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Card Pertanyaan Utama
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (slide['image_url'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      slide['image_url'],
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  slide['question'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Area Jawaban berdasarkan Tipe Slide
          if (type == 'polling' || type == 'quiz')
            _buildOptionsList(slide['options'] ?? [], slideId, isSubmitted)
          else if (type == 'word_cloud')
            _buildWordCloudInput(slideId, isSubmitted),

          const SizedBox(height: 32),

          // Tombol Submit
          ElevatedButton(
            onPressed: isSubmitted
                ? null
                : () => _submitResponse(slideId, type),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: isSubmitted
                  ? Colors.green.shade600
                  : const Color(0xFF4F46E5),
            ),
            child: Text(
              isSubmitted ? 'Terkirim \u2713' : 'Kirim Jawaban',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Navigasi Next & Prev
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: currentNum > 1
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Sebelumnya'),
              ),
              TextButton(
                onPressed: currentNum < totalSlides
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                    : null,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Selanjutnya'),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(
    List<dynamic> options,
    String slideId,
    bool isSubmitted,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = _selectedOptions[slideId] == option['id'];

        return InkWell(
          onTap: isSubmitted
              ? null
              : () {
                  setState(() {
                    _selectedOptions[slideId] = option['id'];
                  });
                },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4F46E5).withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFE5E7EB),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option['text'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordCloudInput(String slideId, bool isSubmitted) {
    return TextField(
      controller: _textControllers[slideId],
      enabled: !isSubmitted,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: 'Ketik satu kata di sini...',
        fillColor: isSubmitted ? Colors.grey.shade100 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 24,
          horizontal: 16,
        ),
      ),
    );
  }
}
