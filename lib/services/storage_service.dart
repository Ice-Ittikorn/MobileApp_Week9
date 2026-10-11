import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// เก็บรูปประกาศขาย
///
/// โปรเจกต์ Firebase แผน Spark ใช้ Cloud Storage ไม่ได้ (ต้องอัปเกรดเป็น Blaze)
/// จึงย่อรูปแล้วแปลงเป็น Data URI (base64) เพื่อเก็บในช่อง imageUrl ของเอกสาร
/// Firestore แทน เมธอดและค่าที่คืนยังเป็น "String ที่ใช้เป็น imageUrl" เหมือนเดิม
/// ถ้าอัปเกรดเป็น Blaze ภายหลัง ให้เปลี่ยนไปใช้ firebase_storage ได้โดยไม่ต้องแก้ผู้เรียก
class StorageService {
  // เอกสาร Firestore ใหญ่สุด 1 MiB และ base64 ใหญ่กว่าไบต์จริงราว 33%
  // จึงจำกัดไบต์ของรูปไว้ที่ ~600 KB
  static const _maxBytes = 600 * 1024;

  /// ย่อรูปและคืนค่าเป็น Data URI สำหรับเก็บเป็น imageUrl
  Future<String> uploadListingImage(File imageFile, String sellerId) async {
    try {
      final original = await imageFile.readAsBytes();
      // ย่อ/บีบอัดใน isolate แยก ไม่ให้หน้าจอค้าง
      final jpg = await compute(_compressToJpeg, original);
      if (jpg == null) {
        throw Exception('ไม่สามารถอ่านไฟล์รูปภาพนี้ได้');
      }
      if (jpg.length > _maxBytes) {
        throw Exception('รูปภาพใหญ่เกินไป กรุณาเลือกรูปอื่น');
      }
      return 'data:image/jpeg;base64,${base64Encode(jpg)}';
    } on FileSystemException {
      throw Exception('ไม่สามารถอ่านไฟล์รูปภาพได้ กรุณาเลือกรูปใหม่');
    }
  }
}

// ลองลดขนาดและคุณภาพลงทีละขั้น จนไฟล์ไม่เกิน _maxBytes
Uint8List? _compressToJpeg(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;

  const steps = [(800, 75), (640, 65), (480, 55), (360, 45)];
  Uint8List? last;
  for (final (maxSide, quality) in steps) {
    final resized = decoded.width >= decoded.height
        ? (decoded.width > maxSide ? img.copyResize(decoded, width: maxSide) : decoded)
        : (decoded.height > maxSide ? img.copyResize(decoded, height: maxSide) : decoded);
    last = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    if (last.length <= StorageService._maxBytes) return last;
  }
  return last;
}
