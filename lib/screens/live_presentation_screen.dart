import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LivePresentationScreen extends StatefulWidget {
  final String presentationId;
  final String title;
  final String joinCode;

  const LivePresentationScreen({
    super.key,
    required this.presentationId,
    required this.title,
    required this.joinCode,
  });

  @override
  State<LivePresentationScreen> createState() => _LivePresentationScreenState();
}

class _LivePresentationScreenState extends State<LivePresentationScreen> {
  final _supabase = Supabase.instance.client;
  final PageController _pageController = PageController();
  RealtimeChannel? _realtimeChannel;

  bool _isLoading = true;
  List<dynamic> _slides = [];
  List<dynamic> _responses = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _realtimeChannel
        ?.unsubscribe(); // Matikan listener saat keluar dari halaman
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _fetchSlides();
    await _fetchResponses();
    _setupRealtime();
    setState(() => _isLoading = false);
  }

  // Mengambil daftar slide beserta opsinya
  Future<void> _fetchSlides() async {
    try {
      final response = await _supabase
          .from('slides')
          .select('*, options(*)')
          .eq('presentation_id', widget.presentationId)
          .order('order_num', ascending: true);
      _slides = response;
    } catch (e) {
      _showSnackBar('Gagal memuat slide.', isError: true);
    }
  }

  // Mengambil seluruh jawaban audiens untuk presentasi ini
  Future<void> _fetchResponses() async {
    if (_slides.isEmpty) return;

    try {
      final slideIds = _slides.map((s) => s['id']).toList();
      final response = await _supabase
          .from('responses')
          .select()
          .filter('slide_id', 'in', slideIds);

      setState(() {
        _responses = response;
      });
    } catch (e) {
      debugPrint('Gagal memuat response: $e');
    }
  }

  // Mengaktifkan listener WebSocket untuk update secara real-time
  void _setupRealtime() {
    _realtimeChannel = _supabase
        .channel('public:responses')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'responses',
          callback: (payload) {
            // Jika ada audiens yang menjawab, langsung fetch ulang datanya
            _fetchResponses();
          },
        )
        .subscribe();
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Indikator Real-time Menyala
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.green.shade400),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.green),
                SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Join Code untuk Audiens
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Join Code: ',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                Text(
                  widget.joinCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),

          // Area Tampilan Slide
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slides.isEmpty
                ? const Center(
                    child: Text('Belum ada slide di presentasi ini.'),
                  )
                : PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _buildSlideView(
                        _slides[index],
                        index + 1,
                        _slides.length,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideView(
    Map<String, dynamic> slide,
    int currentNum,
    int totalSlides,
  ) {
    final String slideId = slide['id'];
    final String type = slide['type'];

    // Filter jawaban khusus untuk slide ini
    final slideResponses = _responses
        .where((r) => r['slide_id'] == slideId)
        .toList();
    final int totalVotes = slideResponses.length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pertanyaan
          Text(
            slide['question'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalVotes partisipan',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),

          // Visualisasi Data berdasarkan tipe
          Expanded(
            child: Container(
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
              child: type == 'word_cloud'
                  ? _buildWordCloud(slideResponses)
                  : _buildBarChart(
                      slide['options'] ?? [],
                      slideResponses,
                      totalVotes,
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Navigasi Presenter
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
                label: const Text('Prev'),
              ),
              Text(
                '$currentNum / $totalSlides',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
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
                  children: [Text('Next'), Icon(Icons.chevron_right_rounded)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Membuat Bar Chart Horizontal Kustom yang Fluid
  Widget _buildBarChart(
    List<dynamic> options,
    List<dynamic> responses,
    int totalVotes,
  ) {
    if (options.isEmpty) return const Center(child: Text('Tidak ada opsi.'));

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.separated(
          itemCount: options.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final option = options[index];
            final int optionVotes = responses
                .where((r) => r['option_id'] == option['id'])
                .length;
            final double percentage = totalVotes == 0
                ? 0
                : (optionVotes / totalVotes);

            // Bar akan menyesuaikan lebar layar
            final double maxWidth = constraints.maxWidth;
            final double barWidth = maxWidth * percentage;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        option['text'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '$optionVotes vote(s)',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    // Background Bar (Abu-abu)
                    Container(
                      height: 24,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    // Foreground Bar (Warna warni beranimasi)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: 24,
                      width: barWidth > 0 ? barWidth : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Membuat Word Cloud Sederhana
  Widget _buildWordCloud(List<dynamic> responses) {
    if (responses.isEmpty)
      return const Center(child: Text('Menunggu jawaban audiens...'));

    // Menghitung frekuensi kemunculan setiap kata
    final Map<String, int> wordCounts = {};
    for (var r in responses) {
      final text = r['text_response']?.toString().trim().toUpperCase() ?? '';
      if (text.isNotEmpty) {
        wordCounts[text] = (wordCounts[text] ?? 0) + 1;
      }
    }

    final List<Widget> wordWidgets = wordCounts.entries.map((entry) {
      final word = entry.key;
      final count = entry.value;

      // Ukuran font membesar jika kata tersebut sering diketik
      final double fontSize = 16.0 + (count * 6.0).clamp(0, 48);
      // Opacity berubah berdasarkan frekuensi
      final double opacity = (0.5 + (count * 0.1)).clamp(0.5, 1.0);

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          word,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4F46E5).withOpacity(opacity),
          ),
        ),
      );
    }).toList();

    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: wordWidgets,
        ),
      ),
    );
  }
}
