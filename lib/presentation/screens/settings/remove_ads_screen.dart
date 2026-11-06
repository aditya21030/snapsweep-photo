import 'package:flutter/material.dart';
import '../../../core/constants/legal_content.dart';
import '../../../core/services/billing_service.dart';
import 'legal_screen.dart';

class RemoveAdsScreen extends StatefulWidget {
  const RemoveAdsScreen({super.key});
  @override
  State<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends State<RemoveAdsScreen> {
  @override
  void initState() {
    super.initState();
    BillingService.initialize();
  }

  void _legal(String title, String content) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalScreen(title: title, content: content),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      BillingService.state,
      BillingService.isPremiumNotifier,
    ]),
    builder: (context, _) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final p = _PaywallColors(dark);
      final state = BillingService.state.value;
      final active = BillingService.isPremium;
      final product = BillingService.removeAdsProduct;
      final label = switch (state.stage) {
        BillingStage.loading => 'Loading price…',
        BillingStage.opening => 'Opening Google Play…',
        BillingStage.pending => 'Payment pending',
        BillingStage.restoring => 'Restoring purchase…',
        _ => product == null ? 'Purchase unavailable' : 'Remove ads',
      };
      return Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton.outlined(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          backgroundColor: p.surface,
                          side: BorderSide(color: p.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          color: p.foreground,
                          size: 27,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Enjoy your photos without advertising',
                    image: true,
                    child: AspectRatio(
                      aspectRatio: 350 / 156,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CustomPaint(
                          painter: _NoAdsIllustration(dark: dark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'SNAPSWEEP PRO',
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    active ? 'Ads removed' : 'Remove ads',
                    style: TextStyle(
                      color: p.foreground,
                      fontSize: 34,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    active
                        ? 'Your one-time purchase is active. Enjoy SnapSweep without advertising.'
                        : 'Pay once and the ads are gone from SnapSweep. No subscription, no renewals.',
                    style: TextStyle(color: p.muted, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 25),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      children: [
                        _benefit(
                          p,
                          Icons.tv_off_outlined,
                          'No ads in the app',
                          'Every screen, from now on',
                        ),
                        Divider(height: 1, color: p.border),
                        _benefit(
                          p,
                          Icons.check_circle_outline_rounded,
                          'One payment',
                          'Lifetime. Nothing recurring',
                        ),
                        Divider(height: 1, color: p.border),
                        _benefit(
                          p,
                          Icons.person_outline_rounded,
                          'Tied to your Google account',
                          'Restore it on a new phone',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!active) ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Lifetime, one-time',
                          style: TextStyle(fontSize: 14, color: p.muted),
                        ),
                        Text(
                          product?.price ?? 'Price unavailable',
                          style: TextStyle(
                            fontSize: product == null ? 18 : 28,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.8,
                            color: p.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('remove_ads_checkout'),
                      onPressed: state.busy || product == null
                          ? null
                          : () => BillingService.buyRemoveAds(),
                      style: FilledButton.styleFrom(
                        backgroundColor: dark
                            ? const Color(0xFFFFCC00)
                            : const Color(0xFF7028FF),
                        foregroundColor: dark ? p.background : Colors.white,
                        disabledBackgroundColor: p.iconSurface,
                        disabledForegroundColor: p.muted,
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (state.busy) ...[
                            SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.muted,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Continue ad-free'),
                    ),
                  if (state.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: state.stage == BillingStage.error
                                ? (dark
                                      ? const Color(0xFFFF7A88)
                                      : const Color(0xFFB3223D))
                                : p.muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  if (!active &&
                      !state.busy &&
                      (product == null || state.stage == BillingStage.error))
                    TextButton(
                      onPressed: BillingService.retry,
                      child: const Text('Retry Google Play'),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: state.busy && state.stage != BillingStage.pending
                        ? null
                        : BillingService.restorePurchases,
                    style: TextButton.styleFrom(
                      foregroundColor: p.foreground,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Restore purchase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Billed once through Google Play',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => _legal(
                          'Terms and Conditions',
                          LegalContent.termsOfService,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: p.muted,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Terms'),
                      ),
                      TextButton(
                        onPressed: () => _legal(
                          'Privacy Policy',
                          LegalContent.privacyPolicy,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: p.muted,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Privacy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _benefit(
    _PaywallColors p,
    IconData icon,
    String title,
    String subtitle,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: p.iconSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 23, color: p.icon),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: p.foreground,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: p.muted, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PaywallColors {
  const _PaywallColors(this.dark);
  final bool dark;
  Color get background =>
      dark ? const Color(0xFF100522) : const Color(0xFFF7F5FF);
  Color get foreground =>
      dark ? const Color(0xFFF8F5FF) : const Color(0xFF16082D);
  Color get muted => dark ? const Color(0xFFB6A6D3) : const Color(0xFF71628F);
  Color get surface => dark ? const Color(0xFF1E0E42) : Colors.white;
  Color get border => dark ? const Color(0xFF342063) : const Color(0xFFE4D9FF);
  Color get iconSurface =>
      dark ? const Color(0xFF2B1757) : const Color(0xFFE9DFFF);
  Color get icon => dark ? const Color(0xFFD7C5FF) : const Color(0xFF7028FF);
}

class _NoAdsIllustration extends CustomPainter {
  const _NoAdsIllustration({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 350, size.height / 156);
    final paint = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 350, 156),
      paint..color = dark ? const Color(0xFF2B175B) : const Color(0xFFE9DFFF),
    );
    void photo(double x, Color color, Color mountain, double sunX, Color sun) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 22, 84, 64),
          const Radius.circular(14),
        ),
        paint..color = color,
      );
      canvas.drawCircle(Offset(x + sunX, 42), 8, paint..color = sun);
      canvas.drawPath(
        Path()
          ..moveTo(x, 68)
          ..lineTo(x + 26, 50)
          ..lineTo(x + 58, 74)
          ..lineTo(x + 70, 66)
          ..lineTo(x + 84, 77)
          ..lineTo(x + 84, 86)
          ..lineTo(x, 86)
          ..close(),
        paint..color = mountain,
      );
    }

    photo(
      38,
      const Color(0xFF7028FF),
      const Color(0xFFE9DFFF),
      60,
      const Color(0xFFFFCC00),
    );
    photo(
      133,
      const Color(0xFFFFCC00),
      const Color(0xFF100522),
      24,
      Colors.white,
    );
    photo(
      228,
      const Color(0xFF8C3AFF),
      const Color(0xFFE9DFFF),
      62,
      const Color(0xFFE9DFFF),
    );
    canvas.save();
    canvas.translate(38, 108);
    canvas.rotate(-.055);
    final ad = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 274, 36),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      ad,
      paint..color = dark ? const Color(0xFF1E0E42) : Colors.white,
    );
    if (!dark) {
      canvas.drawRRect(
        ad,
        paint
          ..color = const Color(0xFFD9C5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 8, 26, 18),
        const Radius.circular(5),
      ),
      paint..color = const Color(0xFF100522),
    );
    final text = TextPainter(
      text: const TextSpan(
        text: 'AD',
        style: TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFFFFCC00),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, const Offset(16, 11));
    for (final line in [
      const Rect.fromLTWH(46, 11, 130, 6),
      const Rect.fromLTWH(46, 22, 88, 5),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(line, const Radius.circular(3)),
        paint..color = const Color(0xFFD9C5FF),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(206, 8, 58, 19),
        const Radius.circular(10),
      ),
      paint..color = const Color(0xFF7028FF),
    );
    canvas.restore();
    canvas.drawLine(
      const Offset(31, 147),
      const Offset(319, 88),
      paint
        ..color = const Color(0xFFDC2045)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NoAdsIllustration oldDelegate) =>
      oldDelegate.dark != dark;
}
