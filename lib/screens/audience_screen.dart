import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_presentation_server.dart';
import '../widgets/app_toast.dart';

class AudienceScreen extends StatefulWidget {
  final String presentationId;
  final String title;
  final bool useLocalServer;

  const AudienceScreen({
    super.key,
    required this.presentationId,
    required this.title,
    this.useLocalServer = false,
  });

  @override
  State<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends State<AudienceScreen> {
  final _supabase = Supabase.instance.client;
  final PageController _pageController = PageController();

  bool _isLoading = true;
  List<dynamic> _slides = [];
  int _currentSlideIndex = 0;

  // Menyimpan data input audiens secara lokal sebelum dikirim
  final Map<String, String> _selectedOptions = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, double> _likertValues = {};
  final Map<String, List<dynamic>> _rankingOptions = {};

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

  Future<void> _fetchSlidesAndOptions() async {
    setState(() => _isLoading = true);

    try {
      final response = widget.useLocalServer
          ? await LocalPresentationServer.instance.fetchSlides(
              widget.presentationId,
            )
          : await _supabase
                .from('slides')
                .select('*, options(*)')
                .eq('presentation_id', widget.presentationId)
                .order('order_num', ascending: true);

      for (var slide in response) {
        if (slide['type'] == 'word_cloud' || slide['type'] == 'qna') {
          _textControllers[slide['id']] = TextEditingController();
        }

        if (slide['type'] == 'likert') {
          _likertValues[slide['id']] = 3;
        }

        if (slide['type'] == 'ranking') {
          _rankingOptions[slide['id']] = List<dynamic>.from(
            slide['options'] ?? [],
          );
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

  Future<void> _submitResponse(String slideId, String type) async {
    final Map<String, dynamic> responseData = {
      'slide_id': slideId,
      'user_id':
          _supabase.auth.currentUser?.id ??
          'anon-${DateTime.now().millisecondsSinceEpoch}',
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
    } else if (type == 'word_cloud' || type == 'qna') {
      final text = _textControllers[slideId]?.text.trim();

      if (text == null || text.isEmpty) {
        _showSnackBar('Input tidak boleh kosong.', isError: true);
        return;
      }

      responseData['text_response'] = text;

      if (type == 'qna') {
        responseData['user_id'] =
            'anonymous-${DateTime.now().millisecondsSinceEpoch}';
      }
    } else if (type == 'likert') {
      final options =
          (_slides.firstWhere((s) => s['id'] == slideId)['options']
              as List<dynamic>? ??
          []);

      if (options.isEmpty) {
        _showSnackBar('Opsi skala belum tersedia.', isError: true);
        return;
      }

      final index = ((_likertValues[slideId] ?? 3).round() - 1).clamp(
        0,
        options.length - 1,
      );

      responseData['option_id'] = options[index]['id'];
    } else if (type == 'ranking') {
      final ranked = _rankingOptions[slideId] ?? [];

      if (ranked.isEmpty) {
        _showSnackBar('Opsi ranking belum tersedia.', isError: true);
        return;
      }

      responseData['text_response'] = ranked
          .map((option) => option['id'].toString())
          .join(',');
    }

    try {
      if (widget.useLocalServer) {
        await LocalPresentationServer.instance.submitResponse(responseData);
      } else {
        await _supabase.from('responses').insert(responseData);
      }

      setState(() {
        _submittedSlideIds.add(slideId);
      });

      _showSnackBar('Jawaban berhasil dikirim!');
    } catch (e) {
      _showSnackBar('Gagal mengirim jawaban.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    AppToast.show(context, message, isError: isError);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'polling':
        return '📊 Polling';
      case 'quiz':
        return '🧠 Kuis';
      case 'word_cloud':
        return '☁️ Word Cloud';
      case 'likert':
        return '📏 Likert';
      case 'ranking':
        return '🏆 Ranking';
      case 'qna':
        return '💬 Q&A';
      default:
        return type;
    }
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
      body: Column(
        children: [
          if (!_isLoading && _slides.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final progress = (_currentSlideIndex + 1) / _slides.length;
                return Stack(
                  children: [
                    Container(height: 3, color: const Color(0xFFEAEAF0)),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      width: constraints.maxWidth * progress,
                      color: const Color(0xFF4F46E5),
                    ),
                  ],
                );
              },
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slides.isEmpty
                ? const Center(
                    child: Text('Belum ada slide di presentasi ini.'),
                  )
                : PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentSlideIndex = index);
                    },
                    itemBuilder: (context, index) => _buildSlideCard(
                      _slides[index],
                      index + 1,
                      _slides.length,
                    ),
                  ),
          ),
        ],
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
          // Indikator Halaman + Badge Tipe Pertanyaan
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.layers_rounded,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Slide $currentNum / $totalSlides',
                      style: const TextStyle(
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _typeLabel(type),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
            _buildTextInput(slideId, isSubmitted, 'Ketik satu kata di sini...')
          else if (type == 'likert')
            _buildLikertInput(slideId, slide['options'] ?? [], isSubmitted)
          else if (type == 'ranking')
            _buildRankingInput(slideId, isSubmitted)
          else if (type == 'qna')
            _buildTextInput(
              slideId,
              isSubmitted,
              'Tulis pertanyaan anonim...',
              maxLines: 4,
            ),

          const SizedBox(height: 32),

          // Tombol Submit
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: isSubmitted
                  ? null
                  : () => _submitResponse(slideId, type),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isSubmitted
                    ? Colors.green.shade600
                    : const Color(0xFF4F46E5),
                disabledBackgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: isSubmitted ? 0 : 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSubmitted
                        ? Icons.check_circle_rounded
                        : Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSubmitted ? 'Jawaban Terkirim ✓' : 'Kirim Jawaban',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Navigasi Next / Finish
          if (currentNum < totalSlides)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Pertanyaan Berikutnya'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  foregroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const _FinishScreen()),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Selesai & Lihat Hasil'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
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

  Widget _buildTextInput(
    String slideId,
    bool isSubmitted,
    String hintText, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: _textControllers[slideId],
      enabled: !isSubmitted,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hintText,
        fillColor: isSubmitted ? Colors.grey.shade100 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 24,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildLikertInput(
    String slideId,
    List<dynamic> options,
    bool isSubmitted,
  ) {
    final value = _likertValues[slideId] ?? 3;

    if (options.isEmpty) {
      return const Center(
        child: Text(
          'Opsi skala belum tersedia.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final selectedIndex = (value.round() - 1).clamp(0, options.length - 1);
    final selectedText = options[selectedIndex]['text'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            value.round().toString(),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4F46E5),
            ),
          ),
          Text(
            selectedText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: selectedText,
            onChanged: isSubmitted
                ? null
                : (newValue) => setState(() {
                    _likertValues[slideId] = newValue;
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingInput(String slideId, bool isSubmitted) {
    final ranking = _rankingOptions[slideId] ?? [];

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ranking.length,
      onReorder: isSubmitted
          ? (_, _) {}
          : (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = ranking.removeAt(oldIndex);
                ranking.insert(newIndex, item);
              });
            },
      itemBuilder: (context, index) {
        final option = ranking[index];

        return Container(
          key: ValueKey(option['id']),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option['text'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.drag_handle_rounded, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }
}

class _FinishScreen extends StatelessWidget {
  const _FinishScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Semua Selesai! 🎉',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Terima kasih sudah berpartisipasi.\nJawaban kamu sudah berhasil dikirim.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Kembali ke Beranda'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
