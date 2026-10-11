import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/cart_model.dart';
import '../repositories/item_repository.dart';
import '../repositories/favorites_repository.dart';
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
