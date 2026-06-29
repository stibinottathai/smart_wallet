import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/core/theme.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _YearRow {
  final int year;
  final double principalPaid;
  final double interestPaid;
  final double closingBalance;

  const _YearRow({
    required this.year,
    required this.principalPaid,
    required this.interestPaid,
    required this.closingBalance,
  });
}

// ─── View ─────────────────────────────────────────────────────────────────────

class EmiCalculatorView extends ConsumerStatefulWidget {
  const EmiCalculatorView({super.key});

  @override
  ConsumerState<EmiCalculatorView> createState() => _EmiCalculatorViewState();
}

class _EmiCalculatorViewState extends ConsumerState<EmiCalculatorView> {
  // Raw values (always stored in base units)
  double _amount = 500000;
  double _rate = 10.0; // annual %
  int _tenure = 24; // always months
  bool _tenureInYears = false;
  bool _showSchedule = false;

  // Controllers keep text fields in sync
  late final TextEditingController _amountCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _tenureCtrl;

  // Prevent feedback loops between slider ↔ field
  bool _updatingFromSlider = false;

  static const double _minAmount = 1000;
  static const double _maxAmount = 10000000;
  static const double _minRate = 1.0;
  static const double _maxRate = 36.0;
  static const int _minTenure = 1;
  static const int _maxTenure = 360;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: _amount.toStringAsFixed(0));
    _rateCtrl = TextEditingController(text: _rate.toStringAsFixed(1));
    _tenureCtrl = TextEditingController(text: _tenure.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  double get _monthlyRate => _rate / 12 / 100;

  double get _emi {
    if (_amount <= 0 || _rate <= 0 || _tenure <= 0) return 0;
    final r = _monthlyRate;
    final n = _tenure.toDouble();
    final factor = math.pow(1 + r, n) as double;
    return _amount * r * factor / (factor - 1);
  }

  double get _totalPayable => _emi * _tenure;
  double get _totalInterest => math.max(0, _totalPayable - _amount);

  List<_YearRow> get _schedule {
    if (_emi <= 0) return [];
    final r = _monthlyRate;
    double balance = _amount;
    final rows = <_YearRow>[];
    int month = 0;
    int year = 1;
    double yearPrincipal = 0;
    double yearInterest = 0;

    while (month < _tenure && balance > 0.01) {
      final interest = balance * r;
      final principal = math.min(_emi - interest, balance);
      balance = math.max(0, balance - principal);
      yearPrincipal += principal;
      yearInterest += interest;
      month++;

      if (month % 12 == 0 || month == _tenure) {
        rows.add(_YearRow(
          year: year,
          principalPaid: yearPrincipal,
          interestPaid: yearInterest,
          closingBalance: balance,
        ));
        year++;
        yearPrincipal = 0;
        yearInterest = 0;
      }
    }
    return rows;
  }

  // ── Syncing helpers ─────────────────────────────────────────────────────────

  void _onAmountSlider(double v) {
    _updatingFromSlider = true;
    setState(() => _amount = v);
    _amountCtrl.text = v.toStringAsFixed(0);
    _updatingFromSlider = false;
  }

  void _onAmountField(String s) {
    if (_updatingFromSlider) return;
    final v = double.tryParse(s.replaceAll(',', ''));
    if (v != null) setState(() => _amount = v.clamp(_minAmount, _maxAmount));
  }

  void _onRateSlider(double v) {
    _updatingFromSlider = true;
    setState(() => _rate = v);
    _rateCtrl.text = v.toStringAsFixed(1);
    _updatingFromSlider = false;
  }

  void _onRateField(String s) {
    if (_updatingFromSlider) return;
    final v = double.tryParse(s);
    if (v != null) setState(() => _rate = v.clamp(_minRate, _maxRate));
  }

  void _onTenureSlider(double v) {
    _updatingFromSlider = true;
    final months = v.round();
    setState(() => _tenure = months);
    _tenureCtrl.text = _tenureInYears
        ? (months / 12).toStringAsFixed(1)
        : months.toString();
    _updatingFromSlider = false;
  }

  void _onTenureField(String s) {
    if (_updatingFromSlider) return;
    final raw = double.tryParse(s);
    if (raw != null) {
      final months = (_tenureInYears ? (raw * 12).round() : raw.round())
          .clamp(_minTenure, _maxTenure);
      setState(() => _tenure = months);
    }
  }

  void _toggleTenureUnit(bool toYears) {
    setState(() {
      _tenureInYears = toYears;
      _tenureCtrl.text = toYears
          ? (_tenure / 12).toStringAsFixed(1)
          : _tenure.toString();
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(currencyCodeProvider);
    final sym = currencySymbol(code);
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    String fmtAmt(double v) => '$sym${fmt.format(v.round())}';

    return Scaffold(
      appBar: AppBar(title: const Text('EMI Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Input card ──────────────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan Details',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _InputRow(
                      label: 'Loan Amount',
                      controller: _amountCtrl,
                      prefix: sym,
                      inputType: const TextInputType.numberWithOptions(decimal: false),
                      sliderMin: _minAmount,
                      sliderMax: _maxAmount,
                      sliderValue: _amount.clamp(_minAmount, _maxAmount),
                      sliderLabel: fmtAmt(_amount),
                      onSlider: _onAmountSlider,
                      onField: _onAmountField,
                      divisions: 999,
                    ),
                    const _RowDivider(),
                    _InputRow(
                      label: 'Annual Interest Rate',
                      controller: _rateCtrl,
                      suffix: '% p.a.',
                      inputType: const TextInputType.numberWithOptions(decimal: true),
                      sliderMin: _minRate,
                      sliderMax: _maxRate,
                      sliderValue: _rate.clamp(_minRate, _maxRate),
                      sliderLabel: '${_rate.toStringAsFixed(1)}%',
                      onSlider: _onRateSlider,
                      onField: _onRateField,
                      divisions: 350,
                    ),
                    const _RowDivider(),
                    _TenureRow(
                      controller: _tenureCtrl,
                      inYears: _tenureInYears,
                      tenureMonths: _tenure,
                      onSlider: _onTenureSlider,
                      onField: _onTenureField,
                      onToggleUnit: _toggleTenureUnit,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Result card ─────────────────────────────────────────────────
            if (_emi > 0) ...[
              _ResultCard(
                emi: _emi,
                principal: _amount,
                totalInterest: _totalInterest,
                totalPayable: _totalPayable,
                symbol: sym,
                fmt: fmtAmt,
              ),
              const SizedBox(height: 16),

              // ── Amortization toggle ────────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _showSchedule = !_showSchedule),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.table_rows_rounded,
                                size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Year-wise Amortization',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const Spacer(),
                            AnimatedRotation(
                              turns: _showSchedule ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showSchedule) ...[
                      const Divider(height: 1),
                      _AmortizationTable(
                          rows: _schedule, symbol: sym, fmt: fmtAmt),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.calculate_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withValues(alpha: 0.35)),
                      const SizedBox(height: 12),
                      Text(
                        'Fill in the loan details above',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Input widgets ─────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 28, color: AppColors.divider);
}

class _InputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? suffix;
  final TextInputType inputType;
  final double sliderMin;
  final double sliderMax;
  final double sliderValue;
  final String sliderLabel;
  final ValueChanged<double> onSlider;
  final ValueChanged<String> onField;
  final int divisions;

  const _InputRow({
    required this.label,
    required this.controller,
    this.prefix,
    this.suffix,
    required this.inputType,
    required this.sliderMin,
    required this.sliderMax,
    required this.sliderValue,
    required this.sliderLabel,
    required this.onSlider,
    required this.onField,
    required this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // Editable value chip
            Container(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (prefix != null)
                      Text(prefix!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    Flexible(
                      child: EditableText(
                        controller: controller,
                        focusNode: FocusNode(),
                        onChanged: onField,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        cursorColor: AppColors.primary,
                        backgroundCursorColor: AppColors.primary,
                        keyboardType: inputType,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]')),
                        ],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (suffix != null)
                      Text(suffix!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: sliderValue,
            min: sliderMin,
            max: sliderMax,
            divisions: divisions,
            onChanged: onSlider,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _shortLabel(sliderMin),
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
            Text(
              _shortLabel(sliderMax),
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  String _shortLabel(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(0)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }
}

class _TenureRow extends StatelessWidget {
  final TextEditingController controller;
  final bool inYears;
  final int tenureMonths;
  final ValueChanged<double> onSlider;
  final ValueChanged<String> onField;
  final ValueChanged<bool> onToggleUnit;

  const _TenureRow({
    required this.controller,
    required this.inYears,
    required this.tenureMonths,
    required this.onSlider,
    required this.onField,
    required this.onToggleUnit,
  });

  @override
  Widget build(BuildContext context) {
    const minM = 1.0;
    const maxM = 360.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Loan Tenure',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // Month / Year toggle
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UnitBtn(label: 'Mo', active: !inYears, onTap: () => onToggleUnit(false)),
                  _UnitBtn(label: 'Yr', active: inYears, onTap: () => onToggleUnit(true)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: EditableText(
                        controller: controller,
                        focusNode: FocusNode(),
                        onChanged: onField,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        cursorColor: AppColors.primary,
                        backgroundCursorColor: AppColors.primary,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      inYears ? ' yr' : ' mo',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: tenureMonths.toDouble().clamp(minM, maxM),
            min: minM,
            max: maxM,
            divisions: 359,
            onChanged: onSlider,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('1 mo', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const Text('30 yr', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _UnitBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UnitBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final double emi;
  final double principal;
  final double totalInterest;
  final double totalPayable;
  final String symbol;
  final String Function(double) fmt;

  const _ResultCard({
    required this.emi,
    required this.principal,
    required this.totalInterest,
    required this.totalPayable,
    required this.symbol,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final interestRatio = totalPayable > 0 ? totalInterest / totalPayable : 0.0;
    final principalRatio = 1.0 - interestRatio;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Summary',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Donut chart
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: principalRatio * 100,
                              color: AppColors.primary,
                              radius: 38,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: interestRatio * 100,
                              color: AppColors.secondary,
                              radius: 38,
                              showTitle: false,
                            ),
                          ],
                          centerSpaceRadius: 44,
                          sectionsSpace: 3,
                          pieTouchData: PieTouchData(enabled: false),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'EMI',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt(emi),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '/month',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Summary rows
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        dot: AppColors.primary,
                        label: 'Principal',
                        value: fmt(principal),
                        percent:
                            '${(principalRatio * 100).toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        dot: AppColors.secondary,
                        label: 'Total Interest',
                        value: fmt(totalInterest),
                        percent:
                            '${(interestRatio * 100).toStringAsFixed(0)}%',
                        valueColor: AppColors.secondary,
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        label: 'Total Payable',
                        value: fmt(totalPayable),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (totalInterest > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'ll pay ${fmt(totalInterest)} in interest — '
                        '${(interestRatio * 100).toStringAsFixed(0)}% of the total outflow.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final Color? dot;
  final String label;
  final String value;
  final String? percent;
  final Color? valueColor;
  final bool isBold;

  const _SummaryRow({
    this.dot,
    required this.label,
    required this.value,
    this.percent,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (dot != null) ...[
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
            if (percent != null)
              Text(
                percent!,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Amortization table ────────────────────────────────────────────────────────

class _AmortizationTable extends StatelessWidget {
  final List<_YearRow> rows;
  final String symbol;
  final String Function(double) fmt;

  const _AmortizationTable({
    required this.rows,
    required this.symbol,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Header
    Widget header(String t, {bool right = true}) => Text(
          t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        );

    Widget cell(String t, {Color? color}) => Text(
          t,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color ?? AppColors.text,
          ),
        );

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              SizedBox(width: 36, child: header('Yr', right: false)),
              Expanded(child: header('Principal')),
              Expanded(child: header('Interest')),
              Expanded(child: header('Balance')),
            ],
          ),
        ),
        const Divider(height: 1),
        for (int i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${rows[i].year}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: cell(
                    fmt(rows[i].principalPaid),
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: cell(
                    fmt(rows[i].interestPaid),
                    color: AppColors.secondary,
                  ),
                ),
                Expanded(
                  child: cell(
                    rows[i].closingBalance < 1
                        ? '—'
                        : fmt(rows[i].closingBalance),
                  ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1)
            const Divider(height: 1, indent: 20, endIndent: 20),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
