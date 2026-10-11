import '../database/app_database.dart';
import '../models/listing_draft.dart';

abstract class ListingDraftRepository {
  // imagePath แยกมาต่างหาก เพราะ ListingDraft (สัปดาห์ 7) ไม่มี field นี้
  Future<void> saveDraft(ListingDraft draft, String imagePath);

  // เรียงจากแก้ไขล่าสุดไปเก่าสุด
  Future<List<ListingDraftRow>> getAllDrafts();

  Future<void> deleteDraft(int id);
}
