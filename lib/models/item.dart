import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final int id;
  final String title;
  final double price;
  final String description;
  final String category;
  final String imageUrl;

  /// uid ของผู้โพสต์ (null สำหรับสินค้าจาก Fake Store API)
  final String? sellerId;

  /// id ของเอกสารใน Firestore (null สำหรับสินค้าจาก Fake Store API)
  final String? docId;

  const Item({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.sellerId,
    this.docId,
  });

  /// true ถ้าเป็นประกาศที่นักศึกษาโพสต์จริงผ่าน Firestore
  bool get isStudentPost => docId != null;

  factory Item.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final title = json['title'] as String;
    final price = (json['price'] as num).toDouble();
    final description = json['description'] as String;
    final category = json['category'] as String;
    final imageUrl =
        json['image'] as String; // key 'image' ไม่ตรงกับชื่อ field imageUrl

    return Item(
      id: id,
      title: title,
      price: price,
      description: description,
      category: category,
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'price': price,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
    };
  }

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: _stableIdFromDocId(doc.id),
      docId: doc.id,
      title: data['title'] as String? ?? '',
      price: (data['price'] as num? ?? 0).toDouble(),
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      sellerId: data['sellerId'] as String?,
    );
  }

  // ตารางรายการโปรด (Drift) ใช้ id เป็นตัวเลข แต่ id ของเอกสาร Firestore เป็น String
  // จึงแปลงเป็นตัวเลขแบบคงที่ (FNV-1a) เพื่อไม่ต้องแก้ Schema ของฐานข้อมูล
  // และบวก offset ไม่ให้ชนกับ id 1-20 ของ Fake Store API
  static int _stableIdFromDocId(String docId) {
    var hash = 0x811c9dc5;
    for (final unit in docId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash + 1000000;
  }
}
