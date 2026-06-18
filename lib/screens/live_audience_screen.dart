import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_toast.dart';

class LiveAudienceScreen extends StatefulWidget {
  final String joinCode;

  const LiveAudienceScreen({super.key, required this.joinCode});

  @override
  State<LiveAudienceScreen> createState() => _LiveAudienceScreenState();
}

class _LiveAudienceScreenState extends State<LiveAudienceScreen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  bool _isLoading = true;
  String? _presentationId;
  String? _title;

  // Data Slide Aktif
  Map<String, dynamic>? _currentSlide;
  List<dynamic> _currentOptions = [];

  // State Input Jawaban
  bool _hasAnswered = false;
  final TextEditingController _textController =
      TextEditingController(); // Untuk Word Cloud
  double _likertValue = 3.0; // Default Netral (1-5)
  List<dynamic> _rankingList = []; // Untuk fitur ReorderableList

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _fetchPresentationDetails();
    if (_presentationId != null) {
      await _fetchActiveSlide();
      _setupRealtime();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchPresentationDetails() async {
    try {
      final response = await _supabase
          .from('presentations')
          .select()
          .eq('join_code', widget.joinCode)
          .single();

      _presentationId = response['id'];
      _title = response['title'];
    } catch (e) {
      _showSnackBar('Kelas tidak ditemukan.', isError: true);
      Navigator.pop(context);
    }
  }

  Future<void> _fetchActiveSlide() async {
    try {
      // Ambil slide pertama (atau slide yang sedang aktif jika ada flag 'is_active' di DB)
      // Untuk demo ini, kita asumsikan audiens selalu melihat slide urutan pertama atau slide yang baru diupdate
      final slideResponse = await _supabase
          .from('slides')
          .select('*, options(*)')
          .eq('presentation_id', _presentationId as Object)
          .order('order_num', ascending: true)
          .limit(1)
          .single();

      setState(() {
        _currentSlide = slideResponse;
        _currentOptions = slideResponse['options'] ?? [];
        _hasAnswered = false; // Reset status jawaban saat slide berganti

        // Inisialisasi list untuk fitur ranking
        if (_currentSlide!['type'] == 'ranking') {
          _rankingList = List.from(_currentOptions);
        }
      });
    } catch (e) {
      // Jika belum ada slide
      setState(() {
        _currentSlide = null;
        _currentOptions = [];
      });
    }
  }

  void _setupRealtime() {
    // Dengarkan perubahan pada tabel slide (misal presenter mengganti slide)
    _realtimeChannel = _supabase
        .channel('public:slides')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'slides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'presentation_id',
            value: _presentationId!,
          ),
          callback: (payload) {
            _fetchActiveSlide();
          },
        )
        .subscribe();
  }

  // --- LOGIKA KIRIM JAWABAN ---
  Future<void> _submitAnswer({String? optionId, String? textResponse}) async {
    if (_hasAnswered) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('responses').insert({
        'slide_id': _currentSlide!['id'],
        // Gunakan ID unik sementara dari waktu jika auth belum jalan 100%
        'user_id': _currentSlide!['type'] == 'qna'
            ? 'anonymous-${DateTime.now().millisecondsSinceEpoch}'
            : _supabase.auth.currentUser?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
        'option_id': optionId,
        'text_response': textResponse,
      });

      setState(() {
        _hasAnswered = true;
      });
      _showSnackBar('Jawaban berhasil dikirim!');
    } catch (e) {
      _showSnackBar('Gagal mengirim jawaban: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
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
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          _title ?? 'Live Class',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _currentSlide == null
          ? _buildWaitingState()
          : _hasAnswered
          ? _buildThankYouState()
          : _buildInteractionArea(),
    );
  }

  Widget _buildWaitingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4F46E5)),
          SizedBox(height: 24),
          Text(
            'Menunggu Presenter...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text('Pertanyaan akan muncul di layar ini secara otomatis.'),
        ],
      ),
    );
  }

  Widget _buildThankYouState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Jawaban Tersimpan!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Lihat layar utama presentasi.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionArea() {
    final type = _currentSlide!['type'];
    final question = _currentSlide!['question'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pertanyaan
          Container(
            padding: const EdgeInsets.all(24),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_currentSlide!['image_url'] != null &&
                    _currentSlide!['image_url'].toString().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _currentSlide!['image_url'],
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Tipe Input Interaksi
          if (type == 'polling' || type == 'quiz') _buildPollingInput(),
          if (type == 'word_cloud') _buildWordCloudInput(),
          if (type == 'likert') _buildLikertInput(),
          if (type == 'ranking') _buildRankingInput(),
          if (type == 'qna') _buildQnaInput(),
        ],
      ),
    );
  }

  // --- WIDGET 1: POLLING & QUIZ ---
  Widget _buildPollingInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _currentOptions.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            onPressed: () => _submitAnswer(optionId: option['id']),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              option['text'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- WIDGET 2: WORD CLOUD ---
  Widget _buildWordCloudInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'Ketik satu kata...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.trim().isNotEmpty) {
              _submitAnswer(textResponse: _textController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Kirim Kata',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildQnaInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Tulis pertanyaan anonim...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.trim().isNotEmpty) {
              _submitAnswer(textResponse: _textController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Kirim Anonim',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // --- WIDGET 3: SKALA LIKERT ---
  Widget _buildLikertInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Sangat Tidak Setuju',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
              Text(
                'Sangat Setuju',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ),
          Slider(
            value: _likertValue,
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: const Color(0xFF4F46E5),
            label: _likertValue.round().toString(),
            onChanged: (value) {
              setState(() {
                _likertValue = value;
              });
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Cari ID opsi yang sesuai dengan nilai slider (asumsi index 0-4 sesuai urutan 1-5)
              int index = _likertValue.round() - 1;
              if (index >= 0 && index < _currentOptions.length) {
                _submitAnswer(optionId: _currentOptions[index]['id']);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Kirim Penilaian',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 4: RANKING (DRAG & DROP) ---
  Widget _buildRankingInput() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Tahan dan geser (drag & drop) untuk mengurutkan.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rankingList.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = _rankingList.removeAt(oldIndex);
              _rankingList.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final option = _rankingList[index];
            return Card(
              key: ValueKey(option['id']),
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  option['text'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Gabungkan urutan ID menjadi string pisah koma sebagai jawaban text
            List<String> orderedIds = _rankingList
                .map((e) => e['id'].toString())
                .toList();
            _submitAnswer(textResponse: orderedIds.join(','));
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Kirim Urutan',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
