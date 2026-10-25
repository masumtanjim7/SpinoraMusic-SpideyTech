import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../profile/application/user_profile_provider.dart';

// ---------------------------------------------------------------------------
// Onboarding Screen — "Lucid Glass" entry flow
// ---------------------------------------------------------------------------

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _vibeCtrl = TextEditingController();
  String? _avatarPath;
  bool _isSaving = false;
  bool _showPermissionNote = false;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _floatAnim = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vibeCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => _avatarPath = file.path);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _showPermissionNote = true);
      }
    }
  }

  Future<void> _enter() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final name = _nameCtrl.text.trim();
    final vibe = _vibeCtrl.text.trim();

    await ref
        .read(userProfileProvider.notifier)
        .updateProfile(
          displayName: name.isEmpty ? null : name,
          vibeSubtitle: vibe.isEmpty ? null : vibe,
          avatarPath: _avatarPath,
        );
    await ref.read(userProfileProvider.notifier).completeOnboarding();

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF08070F),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // — Ambient gradient blobs —
          Positioned(
            top: -60,
            left: -60,
            child: _GlowBlob(
              color: const Color(0xFF8B5CF6),
              size: size.width * 0.72,
              opacity: 0.22,
            ),
          ),
          Positioned(
            bottom: size.height * 0.15,
            right: -80,
            child: _GlowBlob(
              color: const Color(0xFFFF758F),
              size: size.width * 0.65,
              opacity: 0.18,
            ),
          ),
          Positioned(
            top: size.height * 0.38,
            left: size.width * 0.2,
            child: _GlowBlob(
              color: const Color(0xFF3B82F6),
              size: size.width * 0.45,
              opacity: 0.12,
            ),
          ),

          // — Main scroll content —
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 32,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Brand emblem with floating animation
                  AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _floatAnim.value),
                      child: child,
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: child,
                      ),
                      child: CustomPaint(
                        size: const Size(130, 130),
                        painter: _SpiderwebFrequencyPainter(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // — Headline —
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF758F), Color(0xFF8B5CF6)],
                    ).createShader(bounds),
                    child: Text(
                      'Welcome to Spinora',
                      style: tt.displayLarge?.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up your sound identity in seconds.',
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // — Avatar picker —
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _avatarPath == null
                            ? const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        image: _avatarPath != null
                            ? DecorationImage(
                                image: FileImage(File(_avatarPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _avatarPath == null
                          ? const Center(
                              child: Icon(
                                Icons.add_a_photo_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to set profile photo',
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  if (_showPermissionNote) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Grant gallery access in Settings to pick a photo.',
                      style: tt.labelSmall?.copyWith(
                        color: const Color(0xFFFF758F).withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // — Glass input card —
                  _GlassInputCard(nameCtrl: _nameCtrl, vibeCtrl: _vibeCtrl),

                  const SizedBox(height: 32),

                  // — Permission note —
                  _GlassPermissionNote(),

                  const SizedBox(height: 28),

                  // — Enter button —
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF758F), Color(0xFF8B5CF6)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: _isSaving ? null : _enter,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Allow audio access & Enter Spinora',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _GlassInputCard extends StatelessWidget {
  const _GlassInputCard({required this.nameCtrl, required this.vibeCtrl});
  final TextEditingController nameCtrl;
  final TextEditingController vibeCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlassTextField(
            controller: nameCtrl,
            label: 'Your name',
            hint: 'e.g. Masum',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          _GlassTextField(
            controller: vibeCtrl,
            label: 'Your vibe',
            hint: 'e.g. Late night frequencies',
            icon: Icons.music_note_outlined,
          ),
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }
}

class _GlassPermissionNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.headphones_rounded,
            color: Color(0xFF8B5CF6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Spinora needs audio library access to scan your local music collection.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spiderweb-Frequency Emblem CustomPainter
// ---------------------------------------------------------------------------

class _SpiderwebFrequencyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Outer glow ring
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
          const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          const Color(0xFFFF758F).withValues(alpha: 0.0),
        ],
        stops: const [0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxR, glowPaint);

    // Concentric web rings
    for (int ring = 1; ring <= 5; ring++) {
      final r = maxR * (ring / 5.5);
      final ringPaint = Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.15 + 0.04 * ring)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      canvas.drawCircle(center, r, ringPaint);
    }

    // Radial spokes (frequency lines)
    const spokeCount = 12;
    for (int i = 0; i < spokeCount; i++) {
      final angle = (2 * math.pi * i) / spokeCount;
      final dx = math.cos(angle) * maxR;
      final dy = math.sin(angle) * maxR;
      final spokePaint = Paint()
        ..color = const Color(0xFFFF758F).withValues(alpha: 0.18)
        ..strokeWidth = 0.8;
      canvas.drawLine(center, center + Offset(dx, dy), spokePaint);
    }

    // Waveform arc in the center
    final wavePaint = Paint()
      ..color = const Color(0xFFFF758F).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const steps = 80;
    const waveR = 30.0;
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = 2 * math.pi * t;
      final wave = math.sin(angle * 4) * 7;
      final r = waveR + wave;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, wavePaint);

    // Center dot
    final dotPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF758F), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: 7))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
