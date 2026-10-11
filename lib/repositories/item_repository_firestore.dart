import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import 'item_repository.dart';

class ItemRepositoryFirestore implements ItemRepository {
  final CollectionReference<Map<String, dynamic>> _items;

  ItemRepositoryFirestore({FirebaseFirestore? firestore})
    : _items = (firestore ?? FirebaseFirestore.instance).collection('items');

  // อ่านทุกเอกสารใน Collection items ครั้งเดียว
  @override
  Future<List<Item>> getItems() async {
    try {
      final snapshot = await _items.get();
      return snapshot.docs.map(Item.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw Exception(_translate(e));
    }
  }

  // เขียนเอกสารใหม่ลง Collection items
  Future<void> postItem(Item item) async {
    try {
      await _items.add(item.toFirestore());
    } on FirebaseException catch (e) {
      throw Exception(_translate(e));
    }
  }

  // ฟังเฉพาะประกาศของผู้ขายคนนี้แบบ Real-time
  Stream<List<Item>> watchMyListings(String sellerId) {
    return _items
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Item.fromFirestore).toList());
  }

  String _translate(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์เข้าถึงข้อมูล กรุณาเข้าสู่ระบบหรือตรวจสอบ Security Rules';
      case 'unavailable':
        return 'ไม่สามารถเชื่อมต่อเครือข่ายได้ กรุณาตรวจสอบอินเทอร์เน็ต';
      case 'failed-precondition':
        return 'ต้องสร้าง Index ใน Firestore ก่อน (ดูลิงก์ใน Log)';
      default:
        return 'เกิดข้อผิดพลาดจาก Firestore (${e.code})';
    }
  }
}
