import '../models/models.dart';

abstract class TransferRepository {
  Stream<List<Transfer>> watchAllTransfers();
  Future<List<Transfer>> getAllTransfers();
  Future<void> addTransfer(Transfer transfer);
  Future<void> updateTransfer(Transfer transfer);
  Future<void> deleteTransfer(String id);
}
