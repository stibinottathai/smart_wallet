import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

/// Handles receipt-image persistence and ZIP backup bundling.
///
/// A plain CSV can't carry binary data, so a full backup is a ZIP containing
/// `data.csv` plus an `images/` folder with every referenced receipt image.
/// This service also copies freshly-scanned images out of the OS temp/cache
/// directory into permanent app storage so they survive app restarts and can
/// be bundled at export time.
class BackupService {
  static const _backupCsvName = 'data.csv';
  static const _imagesPrefix = 'images/';

  /// Permanent directory where receipt images are stored.
  Future<Directory> receiptsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/receipts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// The last path segment, handling both `/` and `\` separators.
  String basename(String path) => path.split(RegExp(r'[\\/]')).last;

  /// Copies a freshly-scanned image from its (temporary) [tempPath] into
  /// permanent storage and returns the new path. Returns the original path
  /// unchanged if the copy fails, so saving an expense never breaks on a
  /// storage hiccup.
  Future<String> persistReceiptImage(String tempPath) async {
    try {
      final src = File(tempPath);
      if (!await src.exists()) return tempPath;
      final dir = await receiptsDir();
      final ext = tempPath.contains('.') ? tempPath.split('.').last : 'jpg';
      final dest = '${dir.path}/${const Uuid().v4()}.$ext';
      await src.copy(dest);
      return dest;
    } catch (_) {
      return tempPath;
    }
  }

  /// Builds ZIP bytes containing the CSV plus every existing image in
  /// [imagePaths] (deduplicated by filename). Missing/unreadable files are
  /// skipped rather than failing the whole export.
  Future<Uint8List> buildBackupZip({
    required String csvContent,
    required Iterable<String> imagePaths,
  }) async {
    final archive = Archive();
    archive.addFile(ArchiveFile.string(_backupCsvName, csvContent));

    final added = <String>{};
    for (final path in imagePaths) {
      if (path.isEmpty) continue;
      final name = basename(path);
      if (name.isEmpty || !added.add(name)) continue;
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile.bytes('$_imagesPrefix$name', bytes));
      } catch (_) {
        // Skip an unreadable image rather than aborting the backup.
      }
    }

    return ZipEncoder().encodeBytes(archive);
  }

  /// Extracts a backup ZIP: writes its images into permanent storage and
  /// returns the CSV text plus the directory the images landed in (so the
  /// importer can re-point each expense's [receiptImagePath]).
  Future<({String csvContent, String imageDir})> extractBackupZip(
      File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await receiptsDir();

    String csvContent = '';
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name == _backupCsvName || name.endsWith('/$_backupCsvName')) {
        csvContent = utf8.decode(file.content);
      } else if (name.startsWith(_imagesPrefix)) {
        final base = basename(name);
        if (base.isEmpty) continue;
        await File('${dir.path}/$base').writeAsBytes(file.content);
      }
    }

    return (csvContent: csvContent, imageDir: dir.path);
  }

  /// Writes [bytes] to a temp `.zip` and opens the system share sheet (which
  /// includes "Save to Drive" / Google Drive as a destination).
  Future<void> shareBackupZip(Uint8List bytes,
      {String fileName = 'smart_wallet_backup.zip'}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Smart Wallet Backup',
      ),
    );
  }
}
