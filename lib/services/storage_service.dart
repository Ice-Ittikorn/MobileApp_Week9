import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// อัปโหลดรูปประกาศขึ้น Firebase Storage แล้วคืนค่าเป็น Download URL
  Future<String> uploadListingImage(File imageFile, String sellerId) async {
    try {
      // ตั้งชื่อไฟล์ไม่ซ้ำกัน: sellerId + เวลาปัจจุบัน (ไม่ใช้ชื่อไฟล์เดิมจากเครื่อง)
      final fileName = '${sellerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('listings/$sellerId/$fileName');

      // ต้อง await ให้อัปโหลดเสร็จสมบูรณ์ก่อน แล้วค่อยขอ Download URL
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(_translateErrorCode(e.code));
    }
  }

  String _translateErrorCode(String code) {
    switch (code) {
      case 'unauthorized':
        return 'ไม่มีสิทธิ์อัปโหลดรูปภาพ กรุณาเข้าสู่ระบบหรือตรวจสอบ Storage Rules';
      case 'canceled':
        return 'ยกเลิกการอัปโหลดรูปภาพ';
      case 'retry-limit-exceeded':
      case 'network-request-failed':
        return 'อัปโหลดรูปภาพไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
      case 'object-not-found':
      case 'bucket-not-found':
      case 'project-not-found':
        return 'ยังไม่ได้เปิดใช้งาน Firebase Storage ในโปรเจกต์';
      default:
        return 'อัปโหลดรูปภาพไม่สำเร็จ ($code)';
    }
  }
}
