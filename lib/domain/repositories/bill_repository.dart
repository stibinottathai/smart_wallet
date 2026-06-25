import '../models/models.dart';

abstract class BillRepository {
  Stream<List<Bill>> watchAllBills();
  Future<List<Bill>> getAllBills();
  Future<void> addBill(Bill bill);
  Future<void> updateBill(Bill bill);
  Future<void> deleteBill(String id);
}
