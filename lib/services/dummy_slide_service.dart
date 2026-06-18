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
