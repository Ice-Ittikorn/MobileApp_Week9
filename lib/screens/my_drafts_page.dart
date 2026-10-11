import 'dart:io';

import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../repositories/listing_draft_repository.dart';

class MyDraftsPage extends StatefulWidget {
  final ListingDraftRepository repository;
  const MyDraftsPage({super.key, required this.repository});

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  late Future<List<ListingDraftRow>> _draftsFuture;

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
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _delete(draft),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
