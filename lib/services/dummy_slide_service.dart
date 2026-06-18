import 'package:supabase_flutter/supabase_flutter.dart';

class DummySlideService {
  DummySlideService(this._supabase);

  final SupabaseClient _supabase;

  Future<void> createForPresentation(String presentationId) async {
    final samples = [
      _DummySlide(
        question: 'Platform belajar online mana yang paling sering kamu pakai?',
        type: 'polling',
        options: ['Google Classroom', 'Moodle', 'Zoom/Meet', 'YouTube'],
      ),
      _DummySlide(
        question: 'Flutter menggunakan bahasa pemrograman apa?',
        type: 'quiz',
        options: ['Dart', 'Kotlin', 'Swift', 'JavaScript'],
        correctIndex: 0,
      ),
      _DummySlide(
        question: 'Sebutkan satu kata yang menggambarkan kelas hari ini.',
        type: 'word_cloud',
        options: const [],
      ),
      _DummySlide(
        question: 'Materi hari ini mudah dipahami.',
        type: 'likert',
        options: [
          'Sangat Tidak Setuju',
          'Tidak Setuju',
          'Netral',
          'Setuju',
          'Sangat Setuju',
        ],
      ),
      _DummySlide(
        question: 'Urutkan fitur yang paling membantu saat presentasi.',
        type: 'ranking',
        options: [
          'Polling cepat',
          'Kuis interaktif',
          'Word cloud',
          'Q&A anonim',
        ],
      ),
      _DummySlide(
        question: 'Pertanyaan apa yang ingin kamu bahas lebih lanjut?',
        type: 'qna',
        options: const [],
      ),
      _DummySlide(
        question: 'Bagian mana dari materi yang paling menarik?',
        type: 'polling',
        options: [
          'Konsep utama',
          'Demo aplikasi',
          'Diskusi kasus',
          'Latihan praktik',
        ],
      ),
      _DummySlide(
        question:
            'Widget Flutter untuk membuat daftar yang bisa discroll adalah?',
        type: 'quiz',
        options: ['ListView', 'Container', 'TextField', 'SnackBar'],
        correctIndex: 0,
      ),
      _DummySlide(
        question: 'Tulis satu kata untuk menggambarkan tempo pembelajaran.',
        type: 'word_cloud',
        options: const [],
      ),
      _DummySlide(
        question: 'Saya merasa siap mengerjakan tugas setelah sesi ini.',
        type: 'likert',
        options: [
          'Sangat Tidak Siap',
          'Tidak Siap',
          'Cukup Siap',
          'Siap',
          'Sangat Siap',
        ],
      ),
      _DummySlide(
        question: 'Urutkan topik yang ingin diperdalam minggu depan.',
        type: 'ranking',
        options: [
          'State management',
          'Integrasi database',
          'UI responsive',
          'Deploy aplikasi',
        ],
      ),
      _DummySlide(
        question: 'Masukan apa yang ingin kamu sampaikan untuk sesi ini?',
        type: 'qna',
        options: const [],
      ),
    ];

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final slideData = {
        'presentation_id': presentationId,
        'question': sample.question,
        'type': sample.type,
        'order_num': i + 1,
      };

      final slide = await _supabase
          .from('slides')
          .insert(slideData)
          .select()
          .single();

      if (sample.options.isEmpty) continue;

      await _supabase.from('options').insert([
        for (
          var optionIndex = 0;
          optionIndex < sample.options.length;
          optionIndex++
        )
          {
            'slide_id': slide['id'],
            'text': sample.options[optionIndex],
            'is_correct': sample.type == 'quiz'
                ? optionIndex == sample.correctIndex
                : false,
          },
      ]);
    }
  }
}

class _DummySlide {
  final String question;
  final String type;
  final List<String> options;
  final int? correctIndex;

  const _DummySlide({
    required this.question,
    required this.type,
    required this.options,
    this.correctIndex,
  });
}
