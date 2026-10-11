import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/cart_model.dart';
import '../repositories/item_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/item_repository_firestore.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import 'checkout_page.dart';

class HomePage extends StatefulWidget {
  final List<ItemRepository> repositories;
  final FavoritesRepository favoritesRepository;
  const HomePage({
    super.key,
    required this.repositories,
    required this.favoritesRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Item>> _itemsFuture;
  String? _sourceWarning; // ข้อความเตือนเมื่อบางแหล่งข้อมูลโหลดไม่สำเร็จ

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  // เรียก getItems() จากทุก Repository พร้อมกัน แล้วรวมเป็น List เดียว
  // ถ้าบางแหล่งล้มเหลว ยังแสดงผลจากแหล่งที่เหลือได้ (แสดง Error เฉพาะเมื่อล้มทั้งหมด)
  Future<List<Item>> _loadItems() async {
    final errors = <Object>[];
    _sourceWarning = null;
    final results = await Future.wait(
      widget.repositories.map((repo) async {
        try {
          return await repo.getItems();
        } catch (e) {
          errors.add(e);
          return <Item>[];
        }
      }),
    );
    if (errors.length == widget.repositories.length && errors.isNotEmpty) {
      throw errors.first;
    }
    if (errors.isNotEmpty) {
      _sourceWarning =
          'โหลดข้อมูลบางแหล่งไม่สำเร็จ: ${errors.first.toString().replaceFirst('Exception: ', '')}';
    }
    return results.expand((list) => list).toList();
  }

  Future<void> _addFavorite(Item item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.favoritesRepository.addFavorite(
        item.id,
        item.title,
        item.price,
        item.imageUrl,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('เพิ่ม "${item.title}" ลงรายการโปรดแล้ว')),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('เพิ่มรายการโปรดไม่สำเร็จ: $e')));
    }
  }

  // ชั่วคราว: จำลองการโพสต์ขายจริง 2 รายการ เพื่อดู Badge 🎓 บนหน้า Home
  // ลบทิ้งเมื่อทำ 6.3 (ปุ่ม "โพสต์ขายจริง") เสร็จแล้ว
  Future<void> _seedTestItems() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final repo = widget.repositories.whereType<ItemRepositoryFirestore>().firstOrNull;
    if (user == null || repo == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ต้องล็อกอินก่อน และต้องมี ItemRepositoryFirestore')),
      );
      return;
    }
    try {
      const samples = [
        ('หนังสือแคลคูลัส 1 มือสอง', 150.0, 'หนังสือเรียน'),
        ('เครื่องคิดเลข Casio fx-991', 450.0, 'อุปกรณ์การเรียน'),
        ('หนังสือฟิสิกส์ทั่วไป เล่ม 1', 180.0, 'หนังสือเรียน'),
        ('หนังสือโครงสร้างข้อมูลและอัลกอริทึม', 220.0, 'หนังสือเรียน'),
        ('สมุดโน้ตปกแข็ง A4 สภาพใหม่', 60.0, 'อุปกรณ์การเรียน'),
        ('ชุดปากกาเน้นข้อความ 6 สี', 45.0, 'อุปกรณ์การเรียน'),
        ('โคมไฟตั้งโต๊ะ LED ถนอมสายตา', 250.0, 'ของใช้ในหอ'),
        ('พัดลมตั้งโต๊ะ USB', 199.0, 'ของใช้ในหอ'),
        ('กระเป๋าเป้ใส่โน้ตบุ๊ก 15 นิ้ว', 390.0, 'กระเป๋า'),
        ('แฟลชไดรฟ์ 64GB Kingston', 150.0, 'อิเล็กทรอนิกส์'),
        ('หูฟังบลูทูธ มือสอง', 350.0, 'อิเล็กทรอนิกส์'),
        ('เมาส์ไร้สาย Logitech', 280.0, 'อิเล็กทรอนิกส์'),
        ('จักรยานพับ มือสอง', 2500.0, 'ยานพาหนะ'),
        ('เสื้อช็อปวิศวะ ไซส์ M', 300.0, 'เสื้อผ้า'),
        ('ชุดเครื่องเขียนเขียนแบบ ครบเซ็ต', 520.0, 'อุปกรณ์การเรียน'),
      ];

      // ข้ามรายการที่มีชื่อซ้ำใน Firestore แล้ว กันกดซ้ำแล้วได้เอกสารซ้ำ
      final existing = (await repo.getItems()).map((e) => e.title).toSet();
      var added = 0;
      for (final (title, price, category) in samples) {
        if (existing.contains(title)) continue;
        await repo.postItem(
          Item(
            id: 0,
            title: title,
            price: price,
            description: 'สินค้าทดสอบ (จำลอง)',
            category: category,
            imageUrl: 'https://picsum.photos/seed/${Uri.encodeComponent(title)}/200',
            sellerId: user.uid,
          ),
        );
        added++;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('เพิ่มสินค้าทดสอบ $added รายการแล้ว')),
      );
      setState(() {
        _itemsFuture = _loadItems();
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // AuthGate ฟัง authStateChanges() อยู่ จะสลับกลับไปหน้า Login ให้เอง
      await AuthService().signOut();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    }
  }

  bool _geminiLoading = false;

  Future<void> _testGemini() async {
    if (_geminiLoading) return;
    _geminiLoading = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('กำลังถาม Gemini...'),
          duration: Duration(seconds: 30),
        ),
      );
    String message;
    try {
      message = await GeminiService().generateText(
        'ช่วยร่างคำทักทายลูกค้าที่เป็นมิตรสำหรับร้านค้าออนไลน์ ความยาวไม่เกิน 2 ประโยค',
      );
      print('Gemini: $message');
    } catch (e) {
      message = '$e';
      print('Gemini error: $e');
    } finally {
      _geminiLoading = false;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.trim(), maxLines: 6),
          duration: const Duration(seconds: 15),
          showCloseIcon: true,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        actions: [
          // ปุ่มทดสอบชั่วคราว (ข้อ 2.3) ลบทิ้งหลังทดสอบเสร็จ
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _testGemini,
          ),
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartModel>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
          // ปุ่มทดสอบชั่วคราว: จำลองโพสต์ขายจริง (ลบทิ้งหลังทำ 6.3)
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'จำลองโพสต์ขาย (ทดสอบ)',
            onPressed: _seedTestItems,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่พบสินค้า'));
          }
          final list = ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Image.network(
                  item.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
                title: Text(item.title),
                subtitle: Text(
                  '${item.isStudentPost ? '🎓 โพสต์โดยนักศึกษา' : '🏪 จาก API'}'
                  ' · ${item.price} บาท',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () => _addFavorite(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () {
                        context.read<CartModel>().add(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เพิ่ม "${item.title}" ลงตะกร้าแล้ว'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
          if (_sourceWarning == null) return list;
          return Column(
            children: [
              MaterialBanner(
                content: Text(_sourceWarning!),
                leading: const Icon(Icons.warning_amber),
                actions: [
                  TextButton(
                    onPressed: () => setState(() {
                      _itemsFuture = _loadItems();
                    }),
                    child: const Text('ลองใหม่'),
                  ),
                ],
              ),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}
