import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_wallet/ui/providers.dart';

/// Entry point card for the AI assistant, with an animated Siri-style orb.
///
/// Owns its own rotation controller so the looping animation repaints in
/// isolation rather than driving a rebuild from the dashboard state.
class AiAssistantCard extends ConsumerStatefulWidget {
  const AiAssistantCard({super.key});

  @override
  ConsumerState<AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends ConsumerState<AiAssistantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(aiApiKeyProvider);
    final isConfigured = apiKey.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(activeTabIndexProvider.notifier).state = isConfigured ? 2 : 4;
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF132A35), Color(0xFF1B4D46)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B4D46).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Financial Assistant',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isConfigured ? 'Tap the orb to start chatting' : 'Setup required to unlock AI',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Siri-style Orb
                    RepaintBoundary(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isConfigured
                                      ? const Color(0xFF00A3FF).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          RotationTransition(
                            turns: _animationController,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isConfigured
                                    ? const SweepGradient(
                                        colors: [
                                          Color(0xFF00FFC2),
                                          Color(0xFF00A3FF),
                                          Color(0xFFB026FF),
                                          Color(0xFFFF26A8),
                                          Color(0xFF00FFC2),
                                        ],
                                      )
                                    : SweepGradient(
                                        colors: [
                                          Colors.grey.shade600,
                                          Colors.grey.shade400,
                                          Colors.grey.shade600,
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                                radius: 0.8,
                              ),
                            ),
                          ),
                          Icon(
                            isConfigured ? Icons.auto_awesome_rounded : Icons.settings_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
