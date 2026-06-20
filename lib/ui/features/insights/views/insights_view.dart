import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_wallet/data/services/insights_service.dart';
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/providers.dart';

class InsightsView extends ConsumerStatefulWidget {
  const InsightsView({super.key});

  @override
  ConsumerState<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends ConsumerState<InsightsView> {
  List<SpendingInsight>? _insights;
  String? _lastUpdated;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCachedInsights();
  }

  Future<void> _loadCachedInsights() async {
    final service = ref.read(insightsServiceProvider);
    final cached = await service.getCachedInsights();
    final time = await service.getCachedTime();
    if (mounted) {
      setState(() {
        _insights = cached;
        _lastUpdated = time;
      });
    }
  }

  Future<void> _generateInsights() async {
    final apiKey = ref.read(geminiApiKeyProvider);
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a Gemini API Key in Settings to generate AI insights.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    final expensesAsync = ref.read(allExpensesProvider);
    final categoriesAsync = ref.read(allCategoriesProvider);

    final expenses = expensesAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];

    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add expense transactions before generating insights.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(insightsServiceProvider);
      final newInsights = await service.generateInsights(
        expenses: expenses,
        categories: categories,
        apiKey: apiKey,
      );

      final time = await service.getCachedTime();

      setState(() {
        _insights = newInsights;
        _lastUpdated = time;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating insights: $e'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Spending Insights'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intro header card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Insights',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'This tool aggregates your spending trends locally and securely consults Gemini to identify actionable adjustments. No raw transaction files leave your device.',
                    style: TextStyle(fontSize: 13.0, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Main Insights list
            if (_isLoading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16.0),
                      Text('AI is analyzing local transaction metrics...'),
                    ],
                  ),
                ),
              ),
            ] else if (_insights == null || _insights!.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 16.0),
                      const Text(
                        'No insights generated yet.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Tap the button below to generate spending feedback.',
                        style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              if (_lastUpdated != null) ...[
                Text(
                  'LAST REFRESHED: $_lastUpdated',
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text.withOpacity(0.4),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12.0),
              ],
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _insights!.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16.0),
                itemBuilder: (context, index) {
                  final insight = _insights![index];
                  return Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                insight.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          insight.observation,
                          style: const TextStyle(fontSize: 13.0, height: 1.4),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SUGGESTION: ',
                              style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary.withOpacity(0.8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                insight.suggestion,
                                style: const TextStyle(fontSize: 13.0, fontStyle: FontStyle.italic, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24.0),

            // On-demand refresh button
            if (!_isLoading)
              ElevatedButton.icon(
                onPressed: _generateInsights,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text('Refresh Insights'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
