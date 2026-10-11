import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'database/app_database.dart';
import 'models/cart_model.dart';
import 'screens/main_scaffold.dart';
import 'repositories/item_repository_api.dart';
import 'repositories/favorites_repository_drift.dart';
import 'repositories/listing_draft_repository_drift.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // สร้าง AppDatabase ครั้งเดียว แล้วส่งต่อผ่าน Constructor
  final db = AppDatabase();

  runApp(
    ChangeNotifierProvider(
      create: (context) => CartModel(),
      child: MyApp(db: db),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppDatabase db;
  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Marketplace',
      debugShowCheckedModeBanner: false,
      home: MainScaffold(
        itemRepository: ItemRepositoryApi(),
        favoritesRepository: FavoritesRepositoryDrift(db),
        draftRepository: ListingDraftRepositoryDrift(db),
      ),
    );
  }
}
