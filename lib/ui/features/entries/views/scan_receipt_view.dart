import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:smart_wallet/data/services/receipt_scan_service.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/providers.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/account_icons.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:uuid/uuid.dart';

enum ScanState { initial, pickingImage, scanning, analysis, success, error }

class ScanReceiptState {
  final ScanState state;
  final String? imagePath;
  final ReceiptScanResult? result;
  final String? errorMessage;
  final domain.Category? matchedCategory;

  ScanReceiptState({
    this.state = ScanState.initial,
    this.imagePath,
    this.result,
    this.errorMessage,
    this.matchedCategory,
  });

  ScanReceiptState copyWith({
    ScanState? state,
    String? imagePath,
    ReceiptScanResult? result,
    String? errorMessage,
    domain.Category? matchedCategory,
  }) {
    return ScanReceiptState(
      state: state ?? this.state,
      imagePath: imagePath ?? this.imagePath,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      matchedCategory: matchedCategory ?? this.matchedCategory,
    );
  }
}

class ScanReceiptNotifier extends StateNotifier<ScanReceiptState> {
  final ReceiptScanService _service;
  final Ref _ref;

  ScanReceiptNotifier(this._service, this._ref) : super(ScanReceiptState());

  Future<void> pickImage(ImageSource source) async {
    state = state.copyWith(state: ScanState.pickingImage, errorMessage: null);
    try {
      String? pickedPath;
      if (source == ImageSource.camera) {
        final scanner = DocumentScanner(
          options: DocumentScannerOptions(
            pageLimit: 1,
          ),
        );
        final result = await scanner.scanDocument();
        final images = result.images;
        if (images != null && images.isNotEmpty) {
          pickedPath = images.first;
        }
        scanner.close();
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) pickedPath = pickedFile.path;
      }

      if (pickedPath == null) {
        state = state.copyWith(state: ScanState.initial);
        return;
      }
      state = state.copyWith(
        state: ScanState.scanning,
        imagePath: pickedPath,
      );
      await _processImage(pickedPath);
    } on PlatformException catch (e) {
      if (e.code == 'DocumentScanner' || (e.message?.toLowerCase().contains('cancel') ?? false)) {
        // User cancelled the native scanner, just return to initial state
        state = state.copyWith(state: ScanState.initial);
      } else {
        state = state.copyWith(state: ScanState.error, errorMessage: 'Scanner error: ${e.message}');
      }
    } catch (e) {
      state = state.copyWith(state: ScanState.error, errorMessage: 'Failed to pick image: $e');
    }
  }

  Future<void> _processImage(String path) async {
    state = state.copyWith(state: ScanState.analysis);
    try {
      final apiKey = _ref.read(aiApiKeyProvider);
      final aiModel = _ref.read(aiModelProvider);
      final aiProvider = _ref.read(aiProviderProvider);
      if (apiKey.isEmpty) {
        throw Exception('API key is missing. Please set it in Settings.');
      }
      final categories = _ref.read(allCategoriesProvider).value ?? [];
      final result = await _service.scanReceipt(imagePath: path, apiKey: apiKey, aiModel: aiModel, aiProvider: aiProvider, categories: categories);
      if (result == null) {
        throw Exception('Failed to extract information from receipt.');
      }
      
      if (result.category == 'not_a_receipt' || result.merchantName == 'ERROR_NOT_A_RECEIPT') {
        state = state.copyWith(state: ScanState.error, errorMessage: 'Please scan a valid bill or receipt.');
        return;
      }

      // Match category
      final categoryId = _service.matchCategory(result.category, categories);
      final matchedCategory = categories.firstWhere((c) => c.id == categoryId, orElse: () => categories.first);

      state = state.copyWith(
        state: ScanState.success,
        result: result,
        matchedCategory: matchedCategory,
      );
    } catch (e) {
      state = state.copyWith(state: ScanState.error, errorMessage: e.toString());
    }
  }

  Future<void> saveExpense({
    required String merchant,
    required double total,
    required DateTime date,
    required String categoryId,
    String? accountId,
  }) async {
    try {
      final repo = _ref.read(expenseRepositoryProvider);
      final expense = domain.Expense(
        id: const Uuid().v4(),
        amount: total,
        categoryId: categoryId,
        date: date,
        note: merchant, // Use merchant as note
        receiptImagePath: state.imagePath,
        source: domain.ExpenseSource.aiScan,
        accountId: accountId,
      );
      await repo.addExpense(expense);
    } catch (e) {
      throw Exception('Failed to save expense: $e');
    }
  }
}

final scanReceiptProvider = StateNotifierProvider.autoDispose<ScanReceiptNotifier, ScanReceiptState>((ref) {
  return ScanReceiptNotifier(ref.watch(receiptScanServiceProvider), ref);
});

class ScanReceiptView extends ConsumerStatefulWidget {
  const ScanReceiptView({super.key});

  @override
  ConsumerState<ScanReceiptView> createState() => _ScanReceiptViewState();
}

class _ScanReceiptViewState extends ConsumerState<ScanReceiptView> {
  final _merchantController = TextEditingController();
  final _totalController = TextEditingController();
  final _dateController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedAccountId;

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanReceiptProvider);

    ref.listen<ScanReceiptState>(scanReceiptProvider, (previous, next) {
      if (previous?.result != next.result && next.result != null) {
        _merchantController.text = next.result!.merchantName;
        _totalController.text = next.result!.totalAmount.toString();
        _dateController.text = next.result!.date.toIso8601String().split('T').first;
        _selectedCategoryId = next.matchedCategory?.id;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ScanReceiptState state) {
    if (state.state == ScanState.initial || state.state == ScanState.pickingImage) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_rounded, size: 80, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(scanReceiptProvider.notifier).pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Take Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.read(scanReceiptProvider.notifier).pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Choose from Gallery'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (state.state == ScanState.scanning || state.state == ScanState.analysis) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              state.state == ScanState.scanning ? 'Running OCR...' : 'AI is analyzing...',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (state.state == ScanState.error) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.read(scanReceiptProvider.notifier).pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.state == ScanState.success && state.result != null) {
      return _buildForm(state);
    }

    return const SizedBox.shrink();
  }

  Widget _buildForm(ScanReceiptState state) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.imagePath != null) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(state.imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.image_not_supported, size: 50, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildTextField(
            controller: _merchantController,
            label: 'Merchant Name',
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _totalController,
            label: 'Total Amount',
            icon: Icons.attach_money_rounded,
            prefixSymbol: currencySymbol(ref.watch(currencyCodeProvider)),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _dateController,
            label: 'Date (YYYY-MM-DD)',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.category_rounded, color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: AppColors.card,
            ),
            items: categories.map((c) {
              return DropdownMenuItem(value: c.id, child: Text(c.name));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCategoryId = val;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildAccountField(),
          const SizedBox(height: 16),
          if (state.result!.items.isNotEmpty) ...[
            const Text(
              'Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.result!.items.length,
                separatorBuilder: (c, i) => Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
                itemBuilder: (c, i) {
                  final item = state.result!.items[i];
                  return ListTile(
                    title: Text(item.name, style: const TextStyle(fontSize: 14)),
                    trailing: Text(item.price.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton(
            onPressed: () async {
              try {
                if (_selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
                  return;
                }
                
                await ref.read(scanReceiptProvider.notifier).saveExpense(
                  merchant: _merchantController.text,
                  total: double.tryParse(_totalController.text) ?? 0.0,
                  date: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
                  categoryId: _selectedCategoryId!,
                  accountId: _selectedAccountId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense saved successfully!'),
                      backgroundColor: AppColors.success,
                    )
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Save Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountField() {
    final accountsAsync = ref.watch(allAccountsProvider);
    return accountsAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => Text('$err', style: const TextStyle(color: AppColors.error)),
      data: (allAccounts) {
        final accounts = allAccounts.where((a) => !a.archived).toList();
        if (accounts.isEmpty) {
          return const SizedBox.shrink();
        }
        // Default to a cash account if available, otherwise the first account.
        if (_selectedAccountId == null ||
            !accounts.any((a) => a.id == _selectedAccountId)) {
          final cashAccount = accounts.firstWhere(
            (a) => a.type == domain.AccountType.cash,
            orElse: () => accounts.first,
          );
          _selectedAccountId = cashAccount.id;
        }
        return DropdownButtonFormField<String>(
          initialValue: _selectedAccountId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Account',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            filled: true,
            fillColor: AppColors.card,
          ),
          items: accounts.map((acc) {
            final accColor = Color(int.parse(acc.color.replaceAll('#', '0xFF')));
            return DropdownMenuItem(
              value: acc.id,
              child: Row(
                children: [
                  Icon(getAccountIcon(acc.type), size: 18, color: accColor),
                  const SizedBox(width: 10),
                  Flexible(child: Text(acc.name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedAccountId = v),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? prefixSymbol,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: prefixSymbol != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Text(
                  prefixSymbol,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Icon(icon, color: AppColors.textSecondary),
        prefixIconConstraints: prefixSymbol != null
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: AppColors.card,
      ),
    );
  }
}
