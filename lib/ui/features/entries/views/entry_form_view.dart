import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

class EntryFormView extends ConsumerStatefulWidget {
  final domain.Income? initialIncome;
  final domain.Expense? initialExpense;

  const EntryFormView({
    super.key,
    this.initialIncome,
    this.initialExpense,
  });

  @override
  ConsumerState<EntryFormView> createState() => _EntryFormViewState();
}

class _EntryFormViewState extends ConsumerState<EntryFormView> {
  final _formKey = GlobalKey<FormState>();

  // Shared fields
  bool _isExpense = true;
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Income specific fields
  final _sourceController = TextEditingController();
  bool _isRecurring = false;
  domain.IncomeFrequency _frequency = domain.IncomeFrequency.oneOff;

  // Expense specific fields
  String? _selectedCategoryId;
  final _noteController = TextEditingController();
  String? _receiptImagePath;
  domain.ExpenseSource _expenseSource = domain.ExpenseSource.manual;
  double? _aiConfidence;

  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIncome != null) {
      _isExpense = false;
      _amountController.text = widget.initialIncome!.amount.toString();
      _selectedDate = widget.initialIncome!.date;
      _sourceController.text = widget.initialIncome!.source;
      _isRecurring = widget.initialIncome!.isRecurring;
      _frequency = widget.initialIncome!.frequency;
    } else if (widget.initialExpense != null) {
      _isExpense = true;
      _amountController.text = widget.initialExpense!.amount.toString();
      _selectedDate = widget.initialExpense!.date;
      _selectedCategoryId = widget.initialExpense!.categoryId;
      _noteController.text = widget.initialExpense!.note ?? '';
      _receiptImagePath = widget.initialExpense!.receiptImagePath;
      _expenseSource = widget.initialExpense!.source;
      _aiConfidence = widget.initialExpense!.aiConfidence;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _scanReceipt() async {
    final apiKey = ref.read(geminiApiKeyProvider);
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a Gemini API Key in Settings to scan receipts.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Photo Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _isScanning = true;
      });

      final scanService = ref.read(receiptScanServiceProvider);
      final result = await scanService.scanReceipt(
        imagePath: pickedFile.path,
        apiKey: apiKey,
      );

      if (result != null) {
        // Fetch categories to fuzzy match
        final categoriesAsync = ref.read(allCategoriesProvider);
        final categories = categoriesAsync.value ?? [];

        final matchedId = scanService.matchCategory(result.categoryGuess, categories);

        if (!mounted) return;

        setState(() {
          _amountController.text = result.total.toString();
          _selectedDate = result.date;
          _selectedCategoryId = matchedId;
          _noteController.text = '${result.merchant}${result.lineItems.isNotEmpty ? '\nItems:\n${result.lineItems.join('\n')}' : ''}';
          _receiptImagePath = pickedFile.path;
          _expenseSource = domain.ExpenseSource.aiScan;
          _aiConfidence = 0.90; // Default placeholder for successful scan
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form pre-filled from receipt details! Review and tap Add.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to parse receipt. Please enter details manually.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    final uuid = const Uuid().v4();

    if (_isExpense) {
      final categoriesAsync = ref.read(allCategoriesProvider);
      final categories = categoriesAsync.value ?? [];
      final defaultCat = categories.isNotEmpty ? categories.first.id : 'cat_uncategorized';

      final expense = domain.Expense(
        id: widget.initialExpense?.id ?? uuid,
        amount: amount,
        categoryId: _selectedCategoryId ?? defaultCat,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        receiptImagePath: _receiptImagePath,
        source: _expenseSource,
        aiConfidence: _aiConfidence,
      );

      final repo = ref.read(expenseRepositoryProvider);
      if (widget.initialExpense != null) {
        await repo.updateExpense(expense);
      } else {
        await repo.addExpense(expense);
      }
    } else {
      final income = domain.Income(
        id: widget.initialIncome?.id ?? uuid,
        amount: amount,
        source: _sourceController.text.trim().isEmpty ? 'General' : _sourceController.text.trim(),
        date: _selectedDate,
        isRecurring: _isRecurring,
        frequency: _frequency,
      );

      final repo = ref.read(incomeRepositoryProvider);
      if (widget.initialIncome != null) {
        await repo.updateIncome(income);
      } else {
        await repo.addIncome(income);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final isEdit = widget.initialIncome != null || widget.initialExpense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? 'Edit ${_isExpense ? "Expense" : "Income"}'
            : 'Add transaction'),
        actions: [
          if (_isExpense && !isEdit)
            IconButton(
              icon: const Icon(Icons.document_scanner),
              onPressed: _isScanning ? null : _scanReceipt,
              tooltip: 'Scan Receipt',
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Toggle pill if not editing
                  if (!isEdit) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpense = false),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: !_isExpense ? AppColors.primary : AppColors.surface,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8.0)),
                              ),
                              child: Text(
                                'Income',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isExpense ? Colors.white : AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpense = true),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: _isExpense ? AppColors.secondary : AppColors.surface,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8.0)),
                              ),
                              child: Text(
                                'Expense',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isExpense ? Colors.white : AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                  ],

                  // Common amount field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: const Icon(Icons.attach_money, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter an amount';
                      if (double.tryParse(value) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // Common Date selector
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 16.0),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: AppColors.text),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Form details based on type
                  if (!_isExpense) ...[
                    // Income Form
                    TextFormField(
                      controller: _sourceController,
                      decoration: const InputDecoration(
                        labelText: 'Source (e.g. Salary, Client, Sale)',
                        prefixIcon: Icon(Icons.business, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    SwitchListTile(
                      title: const Text('Recurring Income'),
                      value: _isRecurring,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isRecurring = val),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 8.0),
                      DropdownButtonFormField<domain.IncomeFrequency>(
                        value: _frequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: Icon(Icons.repeat, color: AppColors.primary),
                        ),
                        items: domain.IncomeFrequency.values.map((freq) {
                          return DropdownMenuItem(
                            value: freq,
                            child: Text(freq.displayName),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _frequency = val);
                        },
                      ),
                    ],
                  ] else ...[
                    // Expense Form
                    categoriesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error loading categories: $err'),
                      data: (categories) {
                        // Exclude Income category from expense list
                        final expenseCategories = categories.where((c) => c.id != 'cat_income').toList();

                        if (_selectedCategoryId == null && expenseCategories.isNotEmpty) {
                          _selectedCategoryId = expenseCategories.first.id;
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category, color: AppColors.primary),
                          ),
                          items: expenseCategories.map((cat) {
                            return DropdownMenuItem(
                              value: cat.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(cat.color.replaceAll('#', '0xFF'))),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(cat.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedCategoryId = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note / Merchant / Details',
                        prefixIcon: Icon(Icons.note, color: AppColors.primary),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_receiptImagePath != null) ...[
                      const SizedBox(height: 16.0),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: Image.file(
                                File(_receiptImagePath!),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(Icons.receipt_long, size: 40),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Receipt Attached',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('OCR details scanned'),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.secondary),
                              onPressed: () {
                                setState(() {
                                  _receiptImagePath = null;
                                  _expenseSource = domain.ExpenseSource.manual;
                                  _aiConfidence = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _saveForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isExpense ? AppColors.secondary : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    child: Text(
                      isEdit ? 'Save Changes' : 'Add ${_isExpense ? "Expense" : "Income"}',
                      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isScanning)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  margin: const EdgeInsets.symmetric(horizontal: 40.0),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16.0),
                      Text(
                        'Scanning Receipt...',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'AI is reading transaction totals and categories from your image.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.0, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
