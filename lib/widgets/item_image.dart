import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// แสดงรูปสินค้าจาก imageUrl ได้ทั้ง 2 แบบ
/// - URL ปกติ (http/https) เช่น สินค้าจาก Fake Store API
/// - Data URI (data:image/jpeg;base64,...) เช่น รูปที่นักศึกษาโพสต์ขาย
///   (เก็บในเอกสาร Firestore โดยตรง เพราะไม่ได้ใช้ Firebase Storage)
class ItemImage extends StatefulWidget {
  final String imageUrl;
  final double size;
  const ItemImage({super.key, required this.imageUrl, this.size = 48});

  @override
  State<ItemImage> createState() => _ItemImageState();
}

class _ItemImageState extends State<ItemImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant ItemImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _decode();
  }

  // ถอดรหัส base64 ครั้งเดียวต่อรูป ไม่ถอดซ้ำทุกครั้งที่ rebuild
  void _decode() {
    final url = widget.imageUrl;
    if (url.startsWith('data:image')) {
      try {
        _bytes = base64Decode(url.substring(url.indexOf(',') + 1));
      } catch (_) {
        _bytes = null;
      }
    } else {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final broken = Icon(Icons.broken_image, size: widget.size * 0.6);
    final isDataUri = widget.imageUrl.startsWith('data:image');

    Widget child;
    if (isDataUri) {
      child = _bytes == null
          ? broken
          : Image.memory(
              _bytes!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => broken,
            );
    } else if (widget.imageUrl.isEmpty) {
      child = broken;
    } else {
      child = Image.network(
        widget.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => broken,
      );
    }
    return SizedBox(width: widget.size, height: widget.size, child: child);
  }
}
