import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/listing_draft.dart';
import '../repositories/listing_draft_repository.dart';
import 'my_drafts_page.dart';
import '../services/gemini_vision_service.dart';

class SellItemPage extends StatefulWidget {
  final ListingDraftRepository draftRepository;
  const SellItemPage({super.key, required this.draftRepository});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  // Prompt ที่ใช้วิเคราะห์ภาพ (เดียวกับที่ทดลองใน AI Studio ส่วนที่ 1)
  static const _prompt = '''
คุณคือผู้ช่วยเขียนประกาศขายของมือสองในตลาดนัดออนไลน์สำหรับนักศึกษามหาวิทยาลัย
จากรูปภาพสินค้าที่แนบมา ให้วิเคราะห์แล้วตอบกลับเป็น JSON ตามโครงสร้างที่กำหนด
title: ชื่อประกาศสั้นกระชับ ไม่เกิน 40 ตัวอักษร
category: หมวดหมู่ที่เหมาะสมที่สุด เลือกจาก: หนังสือเรียน, อุปกรณ์อิเล็กทรอนิกส์, ของแต่งหอพัก, เสื้อผ้า, อื่นๆ
description: คำบรรยายสินค้า 2-3 ประโยค ที่ดึงดูดผู้ซื้อและบอกสภาพของสินค้าตามที่เห็นในภาพ
''';

  File? _selectedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _errorMessage;
  ListingDraft? _draft;

  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _draft = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyzeImage() async {
    final image = _selectedImage;
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปภาพสินค้าก่อน')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _draft = null;
    });

    _showAnalyzingDialog();

    try {
      final draft = await GeminiVisionService().analyzeProductImage(
        image,
        _prompt,
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        // นำค่าที่ AI แนะนำไปใส่ในช่องกรอก เพื่อให้ผู้ใช้แก้ไขได้ก่อนยืนยัน
        _titleController.text = draft.title;
        _categoryController.text = draft.category;
        _descriptionController.text = draft.description;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // ปิด popup
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showAnalyzingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
                SizedBox(height: 28),
                Text(
                  'AI กำลังวิเคราะห์ภาพสินค้า...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('กรุณารอสักครู่'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      );
    }
    if (_draft == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ตรวจทานและแก้ไขข้อมูลที่ AI แนะนำก่อนยืนยัน',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'ชื่อประกาศ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: 'หมวดหมู่',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'คำบรรยาย',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isSaving ? 'กำลังบันทึก...' : 'ยืนยันร่างประกาศ'),
          onPressed: _isSaving ? null : _confirmDraft,
        ),
      ],
    );
  }

  Future<void> _confirmDraft() async {
    final image = _selectedImage;
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    if (image == null ||
        title.isEmpty ||
        category.isEmpty ||
        description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      // บันทึกลงฐานข้อมูล Drift ถาวร (ไม่หายเมื่อปิดแอป)
      await widget.draftRepository.saveDraft(
        ListingDraft(
          title: title,
          category: category,
          description: description,
        ),
        image.path,
      );
      if (!mounted) return;
      setState(() {
        // ล้างฟอร์มกลับสู่สถานะว่างเปล่า พร้อมลงประกาศใหม่
        _selectedImage = null;
        _draft = null;
        _errorMessage = null;
        _titleController.clear();
        _categoryController.clear();
        _descriptionController.clear();
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('บันทึกร่างประกาศเรียบร้อยแล้ว')),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('บันทึกร่างไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงประกาศขายสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ร่างประกาศของฉัน',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MyDraftsPage(repository: widget.draftRepository),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 300, fit: BoxFit.cover)
            else
              Container(
                height: 300,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 80),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('เลือกรูปภาพ'),
                    onPressed: _pickImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('ให้ AI ช่วยแนะนำ'),
                    onPressed: _isAnalyzing ? null : _analyzeImage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
