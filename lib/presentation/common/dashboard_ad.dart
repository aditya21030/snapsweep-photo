import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/billing_service.dart';

class DashboardAd extends StatefulWidget {
  const DashboardAd({super.key});
  @override
  State<DashboardAd> createState() => _DashboardAdState();
}

class _DashboardAdState extends State<DashboardAd> {
  NativeAd? _ad;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    AdService.adsAllowed.addListener(_update);
    BillingService.isPremiumNotifier.addListener(_update);
    _update();
  }

  void _update() {
    if (!AdService.adsAllowed.value ||
        BillingService.isPremium ||
        AdService.nativeAdUnitId.isEmpty) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      if (mounted) setState(() {});
      return;
    }
    if (_ad != null) return;
    final ad = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted ||
              !identical(_ad, ad) ||
              BillingService.isPremium ||
              !AdService.adsAllowed.value) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted && identical(_ad, ad)) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdService.adsAllowed.removeListener(_update);
    BillingService.isPremiumNotifier.removeListener(_update);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_loaded || _ad == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ad', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              SizedBox(height: 140, child: AdWidget(ad: _ad!)),
            ],
          ),
        );
}
