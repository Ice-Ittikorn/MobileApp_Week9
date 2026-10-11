import 'package:flutter/material.dart';
import '../repositories/item_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/listing_draft_repository.dart';
import 'favorites_page.dart';
import 'home_page.dart';
import 'sell_item_page.dart';

class MainScaffold extends StatefulWidget {
  final List<ItemRepository> itemRepositories;
  final FavoritesRepository favoritesRepository;
  final ListingDraftRepository draftRepository; // จะมีจริงหลังทำส่วนที่ 5 เสร็จ
  const MainScaffold({
    super.key,
    required this.itemRepositories,
    required this.favoritesRepository,
    required this.draftRepository,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int _homeVersion = 0; // เปลี่ยนค่าทุกครั้งที่กลับมาแท็บหน้าหลัก เพื่อโหลดสินค้าใหม่ (เช่น หลังโพสต์ขาย)
  int _favoritesVersion = 0; // เปลี่ยนค่าทุกครั้งที่เปิด Tab รายการโปรด เพื่อให้โหลดข้อมูลใหม่

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        key: ValueKey(_homeVersion),
        repositories: widget.itemRepositories,
        favoritesRepository: widget.favoritesRepository,
      ),
      SellItemPage(draftRepository: widget.draftRepository),
      FavoritesPage(
        key: ValueKey(_favoritesVersion),
        repository: widget.favoritesRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() {
          if (index == 0 && _selectedIndex != 0) _homeVersion++;
          _selectedIndex = index;
          if (index == 2) _favoritesVersion++;
        }),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_a_photo),
            label: 'ลงประกาศขาย',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'รายการโปรด',
          ),
        ],
      ),
    );
  }
}
