import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moduleup/core/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ad unit ids. Release builds use the real units from config/admob.json;
/// debug and profile builds use Google's published sample units.
/// `scripts/check-release-ad-ids.sh` fails a release that still has samples.
abstract final class AdIds {
  static const _bannerReal = 'ca-app-pub-2087846699268567/5287420967';
  static const _interstitialReal = 'ca-app-pub-2087846699268567/6631633081';
  static const _rewardedReal = 'ca-app-pub-2087846699268567/9613678789';
  static const _bannerTest = 'ca-app-pub-3940256099942544/9214589741';
  static const _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const _rewardedTest = 'ca-app-pub-3940256099942544/5224354917';

  static String get banner => kReleaseMode ? _bannerReal : _bannerTest;
  static String get interstitial =>
      kReleaseMode ? _interstitialReal : _interstitialTest;
  static String get rewarded => kReleaseMode ? _rewardedReal : _rewardedTest;
}

/// Outcome of a rewarded ad. Only [Rewarded] grants anything.
sealed class RewardOutcome {
  const RewardOutcome();
}

final class Rewarded extends RewardOutcome {
  const Rewarded();
}

final class Dismissed extends RewardOutcome {
  const Dismissed();
}

final class NoFill extends RewardOutcome {
  const NoFill();
}

/// Free Challenge sets per day, and the most a student can earn on top.
const freeChallengeSetsPerDay = 2;
const maxEarnedChallengeSetsPerDay = 3;

/// Interstitial caps: at most one per N finished sets, at least M apart.
const interstitialEverySets = 3;
const interstitialMinGap = Duration(minutes: 4);

abstract interface class AdsService {
  Future<void> init();

  /// True while a rewarded ad is loaded and can be shown.
  ValueListenable<bool> get rewardedReady;
  Future<RewardOutcome> showRewarded();

  /// Call after a drill set or quiz results screen. Applies the caps and
  /// returns whether an ad was shown.
  Future<bool> maybeShowInterstitial();

  /// Challenge sets the student may still start today.
  int challengeSetsLeftToday();
  int earnedChallengeSetsToday();
  Future<void> useChallengeSet();
}

class AdMobAdsService implements AdsService {
  AdMobAdsService(this._prefs, this._clock);
  final SharedPreferences _prefs;
  final Clock _clock;
  final _rewardedReady = ValueNotifier<bool>(false);
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _started = false;

  @override
  ValueListenable<bool> get rewardedReady => _rewardedReady;

  String get _today => dayKey(_clock.now());

  @override
  Future<void> init() async {
    _prefs.getString('installDay') ??
        await _prefs.setString('installDay', _today);
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!consent.isCompleted) consent.complete();
      },
      (_) {
        if (!consent.isCompleted) consent.complete();
      },
    );
    await consent.future;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
    );
    _started = true;
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() {
    if (!_started) return;
    unawaited(
      RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _rewardedReady.value = true;
          },
          onAdFailedToLoad: (_) => _rewardedReady.value = false,
        ),
      ),
    );
  }

  void _loadInterstitial() {
    if (!_started) return;
    unawaited(
      InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      ),
    );
  }

  @override
  Future<RewardOutcome> showRewarded() async {
    final ad = _rewarded;
    if (ad == null ||
        earnedChallengeSetsToday() >= maxEarnedChallengeSetsPerDay) {
      return const NoFill();
    }
    _rewarded = null;
    _rewardedReady.value = false;
    final done = Completer<RewardOutcome>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!done.isCompleted) {
          done.complete(earned ? const Rewarded() : const Dismissed());
        }
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!done.isCompleted) done.complete(const NoFill());
        _loadRewarded();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    final outcome = await done.future;
    if (outcome is Rewarded) {
      await _prefs.setInt('earned:$_today', earnedChallengeSetsToday() + 1);
    }
    return outcome;
  }

  @override
  Future<bool> maybeShowInterstitial() async {
    final count = (_prefs.getInt('setsSinceAd') ?? 0) + 1;
    await _prefs.setInt('setsSinceAd', count);
    final last = DateTime.fromMillisecondsSinceEpoch(
      _prefs.getInt('lastAd') ?? 0,
    );
    final now = _clock.now();
    final firstDay = _prefs.getString('installDay') == _today;
    final ad = _interstitial;
    if (ad == null ||
        firstDay ||
        count < interstitialEverySets ||
        now.difference(last) < interstitialMinGap) {
      return false;
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show();
    await done.future;
    await _prefs.setInt('setsSinceAd', 0);
    await _prefs.setInt('lastAd', now.millisecondsSinceEpoch);
    _loadInterstitial();
    return true;
  }

  @override
  int earnedChallengeSetsToday() => _prefs.getInt('earned:$_today') ?? 0;

  @override
  int challengeSetsLeftToday() =>
      freeChallengeSetsPerDay +
      earnedChallengeSetsToday() -
      (_prefs.getInt('used:$_today') ?? 0);

  @override
  Future<void> useChallengeSet() => _prefs.setInt(
    'used:$_today',
    (_prefs.getInt('used:$_today') ?? 0) + 1,
  );
}

/// Overridden at the composition root with the real service.
final adsServiceProvider = Provider<AdsService>(
  (ref) => throw UnimplementedError('adsServiceProvider not overridden'),
);

/// Adaptive banner for the Home and Progress screens only.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});
  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) unawaited(_load());
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) return;
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => unawaited(ad.dispose()),
      ),
    );
    await _ad!.load();
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
