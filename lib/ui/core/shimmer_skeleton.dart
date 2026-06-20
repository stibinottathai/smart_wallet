import 'package:flutter/material.dart';

class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({super.key});

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _ShimmerBody(slide: _controller.value);
      },
    );
  }
}

class _ShimmerBody extends StatelessWidget {
  final double slide;
  const _ShimmerBody({required this.slide});

  static final Color _base = Colors.grey[300]!;
  static final Color _highlight = Colors.grey[100]!;
  static final Color _card = Colors.white;

  LinearGradient _shimmer() {
    return LinearGradient(
      colors: [_base, _highlight, _base],
      stops: [slide - 0.3, slide, slide + 0.3].map((s) => s.clamp(0.0, 1.0)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeaderShimmer(),
              const SizedBox(height: 12),
              _buildSummaryShimmer(),
              const SizedBox(height: 16),
              _buildDonutShimmer(),
              const SizedBox(height: 12),
              _buildBarChartShimmer(),
              const SizedBox(height: 12),
              _buildBudgetShimmer(),
              const SizedBox(height: 12),
              _buildGoalsShimmer(),
              const SizedBox(height: 12),
              _buildBillsShimmer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBlock({double? width, double? height, double borderRadius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: _shimmer(),
      ),
    );
  }

  Widget _buildHeaderShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E463C),
              Color(0xFF0D352B),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBlock(width: 120, height: 28, borderRadius: 8),
                  _shimmerBlock(width: 80, height: 24, borderRadius: 12),
                ],
              ),
              const SizedBox(height: 20),
              _shimmerBlock(width: 200, height: 34, borderRadius: 6),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBlock(width: 140, height: 14, borderRadius: 4),
                  _shimmerBlock(width: 100, height: 14, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 8),
              _shimmerBlock(width: double.infinity, height: 6, borderRadius: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildCardShimmer(height: 80),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCardShimmer(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildCardShimmer({double height = 60}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBlock(width: 60, height: 12, borderRadius: 4),
          const Spacer(),
          _shimmerBlock(width: 100, height: 20, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildDonutShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBlock(width: 160, height: 16, borderRadius: 4),
            const SizedBox(height: 20),
            Row(
              children: [
                _shimmerBlock(width: 120, height: 120, borderRadius: 60),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: List.generate(
                      4,
                      (i) => Padding(
                        padding: EdgeInsets.only(bottom: i < 3 ? 12 : 0),
                        child: Row(
                          children: [
                            _shimmerBlock(width: 10, height: 10, borderRadius: 5),
                            const SizedBox(width: 8),
                            _shimmerBlock(width: 60, height: 12, borderRadius: 4),
                            const Spacer(),
                            _shimmerBlock(width: 50, height: 12, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBlock(width: 140, height: 16, borderRadius: 4),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        _shimmerBlock(
                          width: double.infinity,
                          height: [60, 80, 40, 100, 50, 70, 30][i].toDouble(),
                          borderRadius: 6,
                        ),
                        const SizedBox(height: 8),
                        _shimmerBlock(width: 24, height: 10, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBlock(width: 120, height: 16, borderRadius: 4),
            const SizedBox(height: 16),
            ...List.generate(
              3,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i < 2 ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _shimmerBlock(width: 24, height: 24, borderRadius: 6),
                            const SizedBox(width: 10),
                            _shimmerBlock(width: 80, height: 14, borderRadius: 4),
                          ],
                        ),
                        _shimmerBlock(width: 70, height: 14, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _shimmerBlock(width: double.infinity, height: 6, borderRadius: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: _shimmerBlock(width: 120, height: 16, borderRadius: 4),
          ),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Container(
                width: 180,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBlock(width: 120, height: 14, borderRadius: 4),
                    const SizedBox(height: 12),
                    _shimmerBlock(width: double.infinity, height: 6, borderRadius: 3),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _shimmerBlock(width: 50, height: 12, borderRadius: 4),
                        _shimmerBlock(width: 60, height: 12, borderRadius: 4),
                      ],
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

  Widget _buildBillsShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: _shimmerBlock(width: 130, height: 16, borderRadius: 4),
          ),
          _buildCardShimmer(height: 72),
          const SizedBox(height: 8),
          _buildCardShimmer(height: 72),
        ],
      ),
    );
  }
}
