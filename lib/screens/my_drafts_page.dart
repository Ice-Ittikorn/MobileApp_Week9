import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/item.dart';
import '../repositories/item_repository_firestore.dart';
import '../repositories/listing_draft_repository.dart';
import '../services/storage_service.dart';

class MyDraftsPage extends StatefulWidget {
  final ListingDraftRepository repository;
  const MyDraftsPage({super.key, required this.repository});

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  late Future<List<ListingDraftRow>> _draftsFuture;
  final _storageService = StorageService();
  final _itemRepository = ItemRepositoryFirestore();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _draftsFuture = widget.repository.getAllDrafts();
  }

  void _reload() {
    setState(() {
      _draftsFuture = widget.repository.getAllDrafts();
    });
  }

  Future<void> _delete(ListingDraftRow draft) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.deleteDraft(draft.id);
      if (!mounted) return;
      _reload();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('ลบร่าง "${draft.title}" แล้ว')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
    }
  }

  // ถามราคาจากผู้ใช้ เพราะร่างประกาศไม่มี field ราคาเก็บไว้
  Future<double?> _askPrice(String title) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ตั้งราคาสินค้า'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'ราคา (บาท) ของ "$title"',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final price = double.tryParse((value ?? '').trim());
              if (price == null) return 'กรุณากรอกราคาเป็นตัวเลข';
              if (price <= 0) return 'ราคาต้องมากกว่า 0';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  double.parse(controller.text.trim()),
                );
              }
            },
            child: const Text('โพสต์ขาย'),
          ),
        ],
      ),
    );
  }

  Future<void> _postForSale(ListingDraftRow draft) async {
    if (_isPosting) return;
    final messenger = ScaffoldMessenger.of(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนโพสต์ขาย')),
      );
      return;
    }

    final price = await _askPrice(draft.title);
    if (price == null || !mounted) return;

    final imageFile = File(draft.imagePath);
    if (!await imageFile.exists()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ไม่พบไฟล์รูปภาพของร่างนี้ในเครื่อง')),
      );
      return;
    }
    if (!mounted) return;

    setState(() => _isPosting = true);
    // Progress Indicator ระหว่างอัปโหลด
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('กำลังอัปโหลดรูปและโพสต์ขาย...')),
            ],
          ),
        ),
      ),
    );

    var success = false;
    try {
      // 1) อัปโหลดรูปก่อน แล้วรอรับ Download URL
      final imageUrl = await _storageService.uploadListingImage(
        imageFile,
        user.uid,
      );

      // 2) สร้าง Item จากร่าง + ราคา + sellerId แล้วเขียนลง Firestore พร้อม URL
      final item = Item(
        id: 0,
        title: draft.title,
        price: price,
        description: draft.description,
        category: draft.category,
        imageUrl: imageUrl,
        sellerId: user.uid,
      );
      await _itemRepository.postItem(item);

      // 3) โพสต์สำเร็จแล้วค่อยลบร่าง กันกดโพสต์ซ้ำ
      await widget.repository.deleteDraft(draft.id);
      success = true;
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'โพสต์ขายไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // ปิด Progress Dialog
        setState(() => _isPosting = false);
      }
    }

    if (success && mounted) {
      _reload();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('โพสต์ขาย "${draft.title}" เรียบร้อยแล้ว')),
        );
    }
  }

  // รูปแบบ dd/MM/yyyy HH:mm (ไม่ใช้ intl เพราะยังไม่ได้เพิ่ม dependency)
  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildThumbnail(String imagePath) {
    // ไฟล์รูปอาจถูกลบออกจากเครื่อง จึงต้องมี placeholder รองรับ
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(imagePath),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.broken_image),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ร่างประกาศของฉัน')),
      body: FutureBuilder<List<ListingDraftRow>>(
        future: _draftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final drafts = snapshot.data ?? [];
          if (drafts.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีร่างประกาศ ลองสร้างที่แท็บ "ลงประกาศขาย" ดูสิ',
              ),
            );
          }
          return ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return ListTile(
                leading: _buildThumbnail(draft.imagePath),
                title: Text(draft.title),
                subtitle: Text(
                  '${draft.category}\nแก้ไขล่าสุด ${_formatDateTime(draft.updatedAt)}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.cloud_upload),
                      tooltip: 'โพสต์ขายจริง',
                      onPressed: _isPosting ? null : () => _postForSale(draft),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _isPosting ? null : () => _delete(draft),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
