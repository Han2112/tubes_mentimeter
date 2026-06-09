import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_toast.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';

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

  Timer? _countdownTimer;
  int _timeLeft = 30;
  bool _isTimeUp = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _countdownTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _fetchSlides();
    await _fetchResponses();
    _setupRealtime();
    setState(() => _isLoading = false);
    if (_slides.isNotEmpty) {
      _startTimer(_slides.first);
    }
  }

  int _timerSecondsFor(Map<String, dynamic> slide) {
    final value = slide['timer_seconds'];
    if (value is int && value > 0) return value;
    if (value is String) return int.tryParse(value) ?? 30;
    return 30;
  }

  void _startTimer(Map<String, dynamic> slide) {
    _countdownTimer?.cancel();
    setState(() {
      _timeLeft = _timerSecondsFor(slide);
      _isTimeUp = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _isTimeUp = true;
        });
      }
    });
  }

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

  void _setupRealtime() {
    _realtimeChannel = _supabase
        .channel('public:responses')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'responses',
          callback: (payload) {
            _fetchResponses();
          },
        )
        .subscribe();
  }

  void _showLeaderboard() {
    Map<String, int> scores = {};

    for (var response in _responses) {
      final slideId = response['slide_id'];

      final matchedSlides = _slides.where((s) => s['id'] == slideId).toList();
      if (matchedSlides.isEmpty) continue;
      final slide = matchedSlides.first;

      if (slide['type'] == 'quiz') {
        final options = slide['options'] as List;

        final matchedOptions = options
            .where((o) => o['id'] == response['option_id'])
            .toList();
        if (matchedOptions.isEmpty) continue;
        final option = matchedOptions.first;

        if (option['is_correct'] == true) {
          final userId = response['user_id'].toString();
          scores[userId] = (scores[userId] ?? 0) + 100;
        }
      }
    }

    List<Map<String, dynamic>> leaderboard = [];
    for (var userId in scores.keys) {
      leaderboard.add({
        'name': 'Peserta ${userId.substring(0, 5).toUpperCase()}',
        'score': scores[userId],
      });
    }
    leaderboard.sort((a, b) => b['score'].compareTo(a['score']));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 36),
                SizedBox(width: 12),
                Text(
                  'LEADERBOARD',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: leaderboard.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada poin kuis.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: leaderboard.length,
                      itemBuilder: (context, index) {
                        final player = leaderboard[index];
                        Color medalColor = index == 0
                            ? Colors.amber
                            : (index == 1
                                  ? Colors.blueGrey.shade200
                                  : (index == 2
                                        ? Colors.brown.shade300
                                        : Colors.grey.shade100));
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: index < 3
                                ? medalColor.withOpacity(0.2)
                                : Colors.white,
                            border: Border.all(color: medalColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: medalColor,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  player['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${player['score']} pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Laporan Mentimeter - ${widget.title}'),
          ),
          pw.Text('Join Code: ${widget.joinCode}'),
          pw.SizedBox(height: 16),
          ..._slides.map((slide) => _buildPdfSlideSummary(slide)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'laporan.pdf');
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Hasil'];
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Pertanyaan'),
      TextCellValue('Tipe'),
      TextCellValue('Jawaban/Item'),
      TextCellValue('Jumlah/Poin'),
    ]);
    for (var i = 0; i < _slides.length; i++) {
      final slide = _slides[i];
      final rows = _reportRowsFor(slide);
      if (rows.isEmpty) {
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(slide['question'] ?? ''),
          TextCellValue(_typeLabel(slide['type'] ?? '')),
          TextCellValue('-'),
          IntCellValue(0),
        ]);
      } else {
        for (final row in rows) {
          sheet.appendRow([
            IntCellValue(i + 1),
            TextCellValue(slide['question'] ?? ''),
            TextCellValue(_typeLabel(slide['type'] ?? '')),
            TextCellValue(row.label),
            IntCellValue(row.value),
          ]);
        }
      }
    }
    var bytes = excel.save();
    if (bytes != null) {
      await Share.shareXFiles([
        XFile.fromData(Uint8List.fromList(bytes), name: 'laporan.xlsx'),
      ]);
    }
  }

  pw.Widget _buildPdfSlideSummary(Map<String, dynamic> slide) {
    final rows = _reportRowsFor(slide);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${slide['order_num'] ?? '-'} . ${slide['question'] ?? ''}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Tipe: ${_typeLabel(slide['type'] ?? '')}'),
          pw.Text('Timer: ${_timerSecondsFor(slide)} detik'),
          pw.SizedBox(height: 6),
          if (rows.isEmpty)
            pw.Text('Belum ada respons.')
          else
            ...rows.map((row) => pw.Text('- ${row.label}: ${row.value}')),
        ],
      ),
    );
  }

  List<_ReportRow> _reportRowsFor(Map<String, dynamic> slide) {
    final type = slide['type'];
    final responses = _responses
        .where((r) => r['slide_id'] == slide['id'])
        .toList();
    final options = slide['options'] ?? [];

    if (type == 'word_cloud' || type == 'qna') {
      return responses
          .map((r) => _ReportRow((r['text_response'] ?? '').toString(), 1))
          .where((row) => row.label.isNotEmpty)
          .toList();
    }

    if (type == 'ranking') {
      return _rankingScores(
        options,
        responses,
      ).map((row) => _ReportRow(row['text'], row['score'])).toList();
    }

    return options.map<_ReportRow>((option) {
      final count = responses
          .where((response) => response['option_id'] == option['id'])
          .length;
      return _ReportRow(option['text'] ?? '-', count);
    }).toList();
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
        return 'Skala Likert';
      case 'ranking':
        return 'Ranking';
      case 'qna':
        return 'Q&A Anonim';
      default:
        return type.toUpperCase();
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
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.rss_feed_rounded, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  'LIVE FEED',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 28,
            ),
            onPressed: _showLeaderboard,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF4F46E5)),
            onSelected: (v) => v == 'pdf' ? _exportToPdf() : _exportToExcel(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
              const PopupMenuItem(
                value: 'excel',
                child: Text('Download Excel'),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF4F46E5),
            padding: const EdgeInsets.all(16),
            child: Text(
              'Join Code: ${widget.joinCode}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      _startTimer(_slides[index]);
                    },
                    itemBuilder: (context, index) => _buildSlideView(
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

  Widget _buildSlideView(Map<String, dynamic> slide, int curr, int total) {
    final res = _responses.where((r) => r['slide_id'] == slide['id']).toList();
    Color timerColor = _timeLeft <= 10
        ? Colors.redAccent
        : const Color(0xFF4F46E5);
    final String type = slide['type'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alarm_rounded, color: timerColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _isTimeUp ? 'WAKTU HABIS!' : 'Sisa Waktu: $_timeLeft detik',
                style: TextStyle(
                  color: timerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            slide['question'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${res.length} partisipan menjawab',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              // Logika Tampilan Berdasarkan Tipe Slide
              child: type == 'word_cloud'
                  ? _buildWordCloud(res)
                  : type == 'likert'
                  ? _buildLikertResult(slide['options'] ?? [], res)
                  : type == 'ranking'
                  ? _buildRankingResult(slide['options'] ?? [], res)
                  : type == 'qna'
                  ? _buildQnaResult(res)
                  : _buildBarChart(slide['options'] ?? [], res, res.length),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: curr > 1
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      )
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Sebelumnya'),
              ),
              Text(
                '$curr / $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: curr < total
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      )
                    : null,
                child: const Row(
                  children: [Text('Berikutnya'), Icon(Icons.arrow_forward)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List opts, List res, int total) {
    return ListView.builder(
      itemCount: opts.length,
      itemBuilder: (context, i) {
        final count = res.where((r) => r['option_id'] == opts[i]['id']).length;
        final per = total == 0 ? 0.0 : count / total;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              opts[i]['text'],
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: per,
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF4F46E5),
              backgroundColor: Colors.grey.shade100,
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildWordCloud(List res) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: res
          .map(
            (r) => Chip(
              label: Text(r['text_response'] ?? ''),
              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
              side: BorderSide.none,
            ),
          )
          .toList(),
    );
  }

  Widget _buildQnaResult(List res) {
    final questions = res
        .map((r) => (r['text_response'] ?? '').toString().trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (questions.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada pertanyaan anonim.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: questions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.forum_outlined, color: Color(0xFF4F46E5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                questions[index],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAMPILAN HASIL SKALA LIKERT ---
  Widget _buildLikertResult(List options, List res) {
    if (res.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada penilaian.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    double totalScore = 0;
    for (var r in res) {
      int index = options.indexWhere((o) => o['id'] == r['option_id']);
      if (index != -1) {
        totalScore += (index + 1); // Indeks 0 nilainya 1, indeks 4 nilainya 5
      }
    }
    double average = totalScore / res.length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          average.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4F46E5),
          ),
        ),
        const Text(
          'Rata-rata Penilaian',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        LinearProgressIndicator(
          value: average / 5.0,
          minHeight: 24,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: Colors.grey.shade200,
          color: const Color(0xFF4F46E5),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 (Sangat Tidak Setuju)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              '5 (Sangat Setuju)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // --- TAMPILAN HASIL RANKING ---
  Widget _buildRankingResult(List options, List res) {
    if (res.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada urutan yang masuk.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final rankedOptions = _rankingScores(options, res);

    return ListView.builder(
      itemCount: rankedOptions.length,
      itemBuilder: (context, i) {
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4F46E5),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              rankedOptions[i]['text'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: Text(
              '${rankedOptions[i]['score']} pts',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _rankingScores(List options, List res) {
    Map<String, int> scores = {for (var o in options) o['id'].toString(): 0};
    int maxPoints = options.length;

    // Hitung poin: Peringkat 1 dapat poin terbesar (maxPoints), dst.
    for (var r in res) {
      String textRes = r['text_response'] ?? '';
      if (textRes.isNotEmpty) {
        List<String> rankedIds = textRes.split(',');
        for (int i = 0; i < rankedIds.length; i++) {
          String id = rankedIds[i];
          if (scores.containsKey(id)) {
            scores[id] = scores[id]! + (maxPoints - i);
          }
        }
      }
    }

    List<Map<String, dynamic>> rankedOptions = options.map((o) {
      return {'text': o['text'], 'score': scores[o['id'].toString()] ?? 0};
    }).toList();

    rankedOptions.sort((a, b) => b['score'].compareTo(a['score']));
    return rankedOptions;
  }
}

class _ReportRow {
  final String label;
  final int value;

  const _ReportRow(this.label, this.value);
}
