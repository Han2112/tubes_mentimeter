import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class AddSlideScreen extends StatefulWidget {
  final String presentationId;

  const AddSlideScreen({super.key, required this.presentationId});

  @override
  State<AddSlideScreen> createState() => _AddSlideScreenState();
}

class _AddSlideScreenState extends State<AddSlideScreen> {
  final _supabase = Supabase.instance.client;
  final _questionController = TextEditingController();

  String _selectedType = 'polling';
  bool _isLoading = false;
  File? _imageFile;

  // List controller untuk opsi jawaban dinamis
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Menyimpan index jawaban yang benar (jika tipe slide adalah 'quiz')
  int _correctOptionIndex = 0;

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _addOption() {
    if (_optionControllers.length >= 6) {
      _showSnackBar('Maksimal 6 opsi jawaban.');
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      _showSnackBar('Minimal harus ada 2 opsi jawaban.');
      return;
    }
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      // Reset correct option jika yang dihapus adalah jawaban benar saat ini
      if (_correctOptionIndex >= _optionControllers.length) {
        _correctOptionIndex = 0;
      }
    });
  }

  Future<void> _saveSlide() async {
    if (_questionController.text.trim().isEmpty) {
      _showSnackBar('Pertanyaan tidak boleh kosong.', isError: true);
      return;
    }

    // Validasi opsi jika tipe polling atau quiz
    if (_selectedType != 'word_cloud') {
      for (var controller in _optionControllers) {
        if (controller.text.trim().isEmpty) {
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
      String? imageUrl;

      // 1. Upload Gambar (Jika ada)
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage
            .from('slide_images')
            .upload(fileName, _imageFile!);
        imageUrl = _supabase.storage
            .from('slide_images')
            .getPublicUrl(fileName);
      }

      // 2. Dapatkan nomor urut slide terakhir untuk presentasi ini
      final countResponse = await _supabase
          .from('slides')
          .select('id')
          .eq('presentation_id', widget.presentationId);
      final int orderNum = (countResponse as List).length + 1;

      // 3. Simpan Slide ke Database dan ambil ID-nya
      final slideResponse = await _supabase
          .from('slides')
          .insert({
            'presentation_id': widget.presentationId,
            'question': _questionController.text.trim(),
            'type': _selectedType,
            'image_url': imageUrl,
            'order_num': orderNum,
          })
          .select()
          .single();

      final slideId = slideResponse['id'];

      // 4. Simpan Opsi Jawaban (Khusus Polling & Kuis)
      if (_selectedType != 'word_cloud') {
        final List<Map<String, dynamic>> optionsData = [];

        for (int i = 0; i < _optionControllers.length; i++) {
          optionsData.add({
            'slide_id': slideId,
            'text': _optionControllers[i].text.trim(),
            'is_correct': _selectedType == 'quiz'
                ? (i == _correctOptionIndex)
                : false,
          });
        }

        await _supabase.from('options').insert(optionsData);
      }

      if (mounted) {
        _showSnackBar('Slide berhasil ditambahkan!');
        Navigator.pop(context); // Kembali ke halaman detail presentasi
      }
    } catch (e) {
      _showSnackBar('Gagal menyimpan slide.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text(
          'Tambah Slide',
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
                  // Pilihan Tipe Slide
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipe Pertanyaan',
                      prefixIcon: Icon(Icons.category_rounded),
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
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Input Pertanyaan
                  TextField(
                    controller: _questionController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Pertanyaan',
                      hintText: 'Tulis pertanyaanmu di sini...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload Gambar Opsional
                  const Text(
                    'Gambar/Logo (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                _imageFile!,
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
                  if (_imageFile != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _imageFile = null),
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

                  // Area Opsi Jawaban (Sembunyikan jika Word Cloud)
                  if (_selectedType != 'word_cloud') ...[
                    const Divider(),
                    const SizedBox(height: 16),
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
                        TextButton.icon(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // List Dinamis Opsi Jawaban
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _optionControllers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            // Radio Button untuk Kuis (Menentukan jawaban benar)
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
                            else
                              const SizedBox(width: 12), // Spacer untuk polling

                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  hintText: 'Opsi ${index + 1}',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
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
                    const SizedBox(height: 32),
                  ],

                  // Tombol Simpan
                  ElevatedButton(
                    onPressed: _saveSlide,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Simpan Slide'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
