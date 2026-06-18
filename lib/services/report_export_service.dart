import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportExportService {
  ReportExportService(this._supabase);

  final SupabaseClient _supabase;

  Future<void> exportPdf({
    required String presentationId,
    required String title,
    required String joinCode,
  }) async {
    final data = await _loadReportData(presentationId);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Laporan Mentimeter - $title')),
          pw.Text('Join Code: $joinCode'),
          pw.SizedBox(height: 16),
          ...data.slides.map((slide) => _buildPdfSlideSummary(slide, data)),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'laporan-${_safeFileName(title)}.pdf',
    );
  }

  Future<void> exportExcel({
    required String presentationId,
    required String title,
  }) async {
    final data = await _loadReportData(presentationId);
    final excel = Excel.createExcel();
    final sheet = excel['Hasil'];

    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Pertanyaan'),
      TextCellValue('Tipe'),
      TextCellValue('Jawaban/Item'),
      TextCellValue('Jumlah/Poin'),
    ]);

    for (var i = 0; i < data.slides.length; i++) {
      final slide = data.slides[i];
      final rows = _reportRowsFor(slide, data);

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

    final bytes = excel.save();
    if (bytes != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: 'laporan-${_safeFileName(title)}.xlsx',
            ),
          ],
        ),
      );
    }
  }

  Future<_ReportData> _loadReportData(String presentationId) async {
    final slides = await _supabase
        .from('slides')
        .select('*, options(*)')
        .eq('presentation_id', presentationId)
        .order('order_num', ascending: true);

    final slideIds = slides.map((slide) => slide['id']).toList();
    final responses = slideIds.isEmpty
        ? <dynamic>[]
        : await _supabase
              .from('responses')
              .select()
              .filter('slide_id', 'in', slideIds);

    return _ReportData(
      slides: List<Map<String, dynamic>>.from(slides),
      responses: List<Map<String, dynamic>>.from(responses),
    );
  }

  pw.Widget _buildPdfSlideSummary(
    Map<String, dynamic> slide,
    _ReportData data,
  ) {
    final rows = _reportRowsFor(slide, data);

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

  List<_ReportRow> _reportRowsFor(
    Map<String, dynamic> slide,
    _ReportData data,
  ) {
    final type = slide['type'];
    final responses = data.responses
        .where((response) => response['slide_id'] == slide['id'])
        .toList();
    final options = slide['options'] ?? [];

    if (type == 'word_cloud' || type == 'qna') {
      return responses
          .map((response) {
            return _ReportRow((response['text_response'] ?? '').toString(), 1);
          })
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

  List<Map<String, dynamic>> _rankingScores(List options, List responses) {
    final scores = {for (var option in options) option['id'].toString(): 0};
    final maxPoints = options.length;

    for (final response in responses) {
      final textResponse = response['text_response'] ?? '';
      if (textResponse.isNotEmpty) {
        final rankedIds = textResponse.split(',');
        for (int i = 0; i < rankedIds.length; i++) {
          final id = rankedIds[i];
          if (scores.containsKey(id)) {
            scores[id] = scores[id]! + (maxPoints - i);
          }
        }
      }
    }

    final rankedOptions = options.map<Map<String, dynamic>>((option) {
      return {
        'text': option['text'],
        'score': scores[option['id'].toString()] ?? 0,
      };
    }).toList();

    rankedOptions.sort((a, b) => b['score'].compareTo(a['score']));
    return rankedOptions;
  }

  int _timerSecondsFor(Map<String, dynamic> slide) {
    final value = slide['timer_seconds'];
    if (value is int && value > 0) return value;
    if (value is String) return int.tryParse(value) ?? 30;
    return 30;
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

  String _safeFileName(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned.isEmpty ? 'presentasi' : cleaned;
  }
}

class _ReportData {
  final List<Map<String, dynamic>> slides;
  final List<Map<String, dynamic>> responses;

  const _ReportData({required this.slides, required this.responses});
}

class _ReportRow {
  final String label;
  final int value;

  const _ReportRow(this.label, this.value);
}
