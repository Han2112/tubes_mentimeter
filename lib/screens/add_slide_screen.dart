import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_toast.dart';

class AddSlideScreen extends StatefulWidget {
  final String presentationId;
  final Map<String, dynamic>? slide;

  const AddSlideScreen({super.key, required this.presentationId, this.slide});

  @override
  State<AddSlideScreen> createState() => _AddSlideScreenState();
}

class _OptionInput {
  final String? id;
  final TextEditingController controller;
  bool isCorrect;

  _OptionInput({this.id, required this.controller, this.isCorrect = false});
}

class _AddSlideScreenState extends State<AddSlideScreen> {
  final _supabase = Supabase.instance.client;
  final _questionController = TextEditingController();
  final _timerController = TextEditingController(text: '30');

  String _selectedType = 'polling';
  bool _isLoading = false;
  XFile? _imageFile;
  String? _existingImageUrl;
  final Set<String> _originalOptionIds = {};

  final List<_OptionInput> _options = [];

  int _correctOptionIndex = 0;
  bool get _isEditing => widget.slide != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadSlideForEditing();
    } else {
      _resetOptionsForType(_selectedType);
    }
  }

  Future<void> _loadSlideForEditing() async {
    final slide = widget.slide!;
    _questionController.text = (slide['question'] ?? '').toString();
    _timerController.text = (slide['timer_seconds'] ?? 30).toString();
    _selectedType = (slide['type'] ?? 'polling').toString();
    _existingImageUrl = slide['image_url']?.toString();

    List<dynamic> slideOptions;
    if (slide['options'] is List) {
      slideOptions = slide['options'] as List<dynamic>;
    } else {
      setState(() => _isLoading = true);
      try {
        slideOptions = await _supabase
            .from('options')
            .select()
            .eq('slide_id', slide['id'])
            .order('created_at', ascending: true);
      } catch (_) {
        slideOptions = [];
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    for (final option in slideOptions) {
      final id = option['id']?.toString();
      if (id != null) _originalOptionIds.add(id);
      _options.add(
        _OptionInput(
          id: id,
          controller: TextEditingController(text: option['text'] ?? ''),
          isCorrect: option['is_correct'] == true,
        ),
      );
    }

    if (_needsOptions && _options.isEmpty) {
      _resetOptionsForType(_selectedType);
    }

    final correctIndex = _options.indexWhere((option) => option.isCorrect);
    _correctOptionIndex = correctIndex == -1 ? 0 : correctIndex;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _questionController.dispose();
    _timerController.dispose();
    for (var option in _options) {
      option.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      _showSnackBar('Gagal membuka galeri: $e', isError: true);
    }
  }

  void _addOption() {
    if (_options.length >= 6) {
      _showSnackBar('Maksimal 6 opsi jawaban.');
      return;
    }
    setState(() {
      _options.add(_OptionInput(controller: TextEditingController()));
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      _showSnackBar('Minimal harus ada 2 opsi jawaban.');
      return;
    }
    setState(() {
      _options[index].controller.dispose();
      _options.removeAt(index);
      if (_correctOptionIndex >= _options.length) {
        _correctOptionIndex = 0;
      }
    });
  }

  Future<void> _saveSlide() async {
    if (_questionController.text.trim().isEmpty) {
      _showSnackBar('Pertanyaan tidak boleh kosong.', isError: true);
      return;
    }

    if (_needsOptions) {
      for (var option in _options) {
        if (option.controller.text.trim().isEmpty) {
          _showSnackBar(
            'Opsi jawaban tidak boleh ada yang kosong.',
            isError: true,
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Logika Upload Gambar (Kompatibel untuk Web & Mobile)
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileExt = _imageFile!.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage
            .from('slide_images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$fileExt',
                upsert: true,
              ),
            );

        imageUrl = _supabase.storage
            .from('slide_images')
            .getPublicUrl(fileName);
      }

      int orderNum = widget.slide?['order_num'] ?? 1;
      if (!_isEditing) {
        final countResponse = await _supabase
            .from('slides')
            .select('id')
            .eq('presentation_id', widget.presentationId);
        orderNum = (countResponse as List).length + 1;
      }

      final slideData = {
        'presentation_id': widget.presentationId,
        'question': _questionController.text.trim(),
        'type': _selectedType,
        'image_url': imageUrl,
        'order_num': orderNum,
        'timer_seconds': int.tryParse(_timerController.text.trim()) ?? 30,
      };

      Map<String, dynamic> slideResponse;
      try {
        if (_isEditing) {
          slideResponse = await _supabase
              .from('slides')
              .update(slideData)
              .eq('id', widget.slide!['id'])
              .select()
              .single();
        } else {
          slideResponse = await _supabase
              .from('slides')
              .insert(slideData)
              .select()
              .single();
        }
      } catch (_) {
        slideData.remove('timer_seconds');
        if (_isEditing) {
          slideResponse = await _supabase
              .from('slides')
              .update(slideData)
              .eq('id', widget.slide!['id'])
              .select()
              .single();
        } else {
          slideResponse = await _supabase
              .from('slides')
              .insert(slideData)
              .select()
              .single();
        }
      }

      final slideId = slideResponse['id'];

      // Simpan Opsi
      if (_needsOptions) {
        final keptIds = <String>{};
        final List<Map<String, dynamic>> newOptions = [];

        for (int i = 0; i < _options.length; i++) {
          final optionData = {
            'slide_id': slideId,
            'text': _options[i].controller.text.trim(),
            'is_correct': _selectedType == 'quiz'
                ? (i == _correctOptionIndex)
                : false,
          };

          if (_options[i].id == null) {
            newOptions.add(optionData);
          } else {
            keptIds.add(_options[i].id!);
            await _supabase
                .from('options')
                .update(optionData)
                .eq('id', _options[i].id!);
          }
        }

        if (newOptions.isNotEmpty) {
          await _supabase.from('options').insert(newOptions);
        }

        for (final removedId in _originalOptionIds.difference(keptIds)) {
          await _supabase.from('options').delete().eq('id', removedId);
        }
      } else if (_isEditing && _originalOptionIds.isNotEmpty) {
        for (final optionId in _originalOptionIds) {
          await _supabase.from('options').delete().eq('id', optionId);
        }
      }

      if (mounted) {
        _showSnackBar(
          _isEditing
              ? 'Slide berhasil diperbarui!'
              : 'Slide berhasil ditambahkan!',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Gagal menyimpan: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _needsOptions =>
      _selectedType != 'word_cloud' && _selectedType != 'qna';

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.3,
      ),
    ),
  );

  void _resetOptionsForType(String type) {
    for (final option in _options) {
      option.controller.dispose();
    }
    _options.clear();

    if (type == 'likert') {
      _options.addAll([
        _OptionInput(
          controller: TextEditingController(text: 'Sangat Tidak Setuju'),
        ),
        _OptionInput(controller: TextEditingController(text: 'Tidak Setuju')),
        _OptionInput(controller: TextEditingController(text: 'Netral')),
        _OptionInput(controller: TextEditingController(text: 'Setuju')),
        _OptionInput(controller: TextEditingController(text: 'Sangat Setuju')),
      ]);
    } else if (type == 'word_cloud' || type == 'qna') {
      return;
    } else {
      _options.addAll([
        _OptionInput(controller: TextEditingController()),
        _OptionInput(controller: TextEditingController()),
      ]);
    }
    _correctOptionIndex = 0;
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
          _isEditing ? 'Edit Slide' : 'Tambah Slide',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('TIPE PERTANYAAN'),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Tipe Pertanyaan',
                      prefixIcon: const Icon(
                        Icons.category_rounded,
                        color: Color(0xFF4F46E5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 2,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'polling',
                        child: Text('Polling (Voting)'),
                      ),
                      DropdownMenuItem(
                        value: 'quiz',
                        child: Text('Kuis (Ada Jawaban Benar)'),
                      ),
                      DropdownMenuItem(
                        value: 'word_cloud',
                        child: Text('Awan Kata (Word Cloud)'),
                      ),
                      DropdownMenuItem(
                        value: 'likert',
                        child: Text('Skala Likert (1-5)'),
                      ),
                      DropdownMenuItem(
                        value: 'ranking',
                        child: Text('Ranking (Urutan)'),
                      ),
                      DropdownMenuItem(value: 'qna', child: Text('Q&A Anonim')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                          _resetOptionsForType(value);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('TIMER'),
                  TextField(
                    controller: _timerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Timer per pertanyaan',
                      hintText: '30',
                      suffixText: 'detik',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel('PERTANYAAN'),
                  TextField(
                    controller: _questionController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Pertanyaan',
                      hintText: 'Tulis pertanyaanmu di sini...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel('GAMBAR/LOGO (OPSIONAL)'),
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: kIsWeb
                                  ? Image.network(
                                      _imageFile!.path,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Image.file(
                                      File(_imageFile!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            )
                          : _existingImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                _existingImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap untuk memilih gambar',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_imageFile != null || _existingImageUrl != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _imageFile = null;
                          _existingImageUrl = null;
                        }),
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        label: const Text(
                          'Hapus Gambar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  if (_needsOptions) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    _sectionLabel('OPSI JAWABAN'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Opsi Jawaban',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        // Tombol tambah opsi dinonaktifkan untuk Likert agar standar 5 skala
                        if (_selectedType != 'likert')
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tambah'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _options.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            if (_selectedType == 'quiz')
                              Radio<int>(
                                value: index,
                                groupValue: _correctOptionIndex,
                                activeColor: Colors.green,
                                onChanged: (value) {
                                  setState(() {
                                    _correctOptionIndex = value!;
                                  });
                                },
                              )
                            else if (_selectedType == 'ranking')
                              const Padding(
                                padding: EdgeInsets.only(right: 12.0),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Colors.grey,
                                ),
                              )
                            else
                              const SizedBox(width: 12),

                            Expanded(
                              child: TextField(
                                controller: _options[index].controller,
                                decoration: InputDecoration(
                                  hintText: 'Opsi ${index + 1}',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedType != 'likert')
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removeOption(index),
                              ),
                          ],
                        );
                      },
                    ),
                    if (_selectedType == 'quiz')
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          '* Pilih bulatan hijau untuk menandai jawaban yang benar.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (_selectedType == 'likert')
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          '* Opsi otomatis dibuat menjadi 5 Skala. Kamu bisa mengedit teksnya jika perlu.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],

                  const SizedBox(height: 24),
                  SafeArea(
                    top: false,
                    child: ElevatedButton(
                      onPressed: _saveSlide,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                      ),
                      child: const Text('Simpan Slide'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
