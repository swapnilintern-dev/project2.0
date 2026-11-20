// =============================================================================
// VS Arogya — buyer pricing tier
//
// The catalogue carries THREE prices per medicine, and which one a buyer sees
// depends on what kind of business they are:
//
//   • retail       — the base `price` (a normal pharmacy)
//   • doctor       — base price minus `drDisPercent`      (hospital / clinic)
//   • wholeseller  — base price minus `wholesellerPercent` (wholesale pharmacy)
//
// Both percentages are per-product fields the Marketing team sets, including
// through the bulk Excel upload (columns DR_DIS_% and Wholseller_%).
//
// ─── IMPORTANT: THIS IS PRESENTATION ONLY ────────────────────────────────────
// The server is the authority on what is actually charged — it computes the
// order total at placement. This class only decides which figure the app SHOWS,
// so a wrong tier here is a display bug, never a pricing exploit.
//
// The tier is derived from the signed-in vendor's own registration fields
// (`vendor_type` / `shop_type`), which is what the backend already stores.
// =============================================================================

import 'package:flutter/foundation.dart';

/// Which rate card an account is on.
enum BuyerPricingTier {
  /// Ordinary retail pharmacy — pays the base price.
  retail,

  /// Hospital or clinic — gets the doctor rate (`drDisPercent`).
  doctor,

  /// Wholesale buyer — gets the wholesale rate (`wholesellerPercent`).
  wholeseller,
}

extension BuyerPricingTierX on BuyerPricingTier {
  /// Short label for the price badge ("Doctor rate" / "Wholesale rate").
  String get label => switch (this) {
        BuyerPricingTier.doctor => 'Doctor rate',
        BuyerPricingTier.wholeseller => 'Wholesale rate',
        BuyerPricingTier.retail => 'Your price',
      };

  /// Whether this tier can attract a discount at all. Retail never does, so the
  /// UI can skip the whole "you save …" treatment for it.
  bool get isDiscounted => this != BuyerPricingTier.retail;
}

/// The signed-in account's pricing tier.
///
/// A [ChangeNotifier] singleton matching the pattern the customer app already
/// uses for shared state (CartController.instance, VendorApproval.instance), so
/// screens observe it with `ListenableBuilder` and re-price in place.
class BuyerPricing extends ChangeNotifier {
  BuyerPricing._();

  static final BuyerPricing instance = BuyerPricing._();

  BuyerPricingTier _tier = BuyerPricingTier.retail;

  /// Defaults to [BuyerPricingTier.retail] — the UNDISCOUNTED price.
  ///
  /// Deliberately the conservative direction: if the account's type is unknown
  /// or the login response is missing it, the buyer sees the normal price and
  /// the server charges whatever it charges. Defaulting the other way would
  /// advertise a discount the account may not be entitled to.
  BuyerPricingTier get tier => _tier;

  /// Maps the vendor's registration fields onto a tier.
  ///
  /// `vendor_type` is the primary signal ("Hospital / Clinic" vs
  /// "Shop / Pharmacy"); `shop_type` refines a shop into wholesale or retail.
  /// Both are free-text on the backend, so matching is loose and lowercase.
  static BuyerPricingTier tierFrom({String? vendorType, String? shopType}) {
    final v = (vendorType ?? '').toLowerCase();
    final s = (shopType ?? '').toLowerCase();

    // Checked first: a hospital pharmacy is a hospital buyer, even though its
    // shop_type also contains "pharmacy".
    if (v.contains('hospital') || v.contains('clinic') || v.contains('doctor')) {
      return BuyerPricingTier.doctor;
    }
    if (s.contains('hospital') || s.contains('clinic')) {
      return BuyerPricingTier.doctor;
    }
    if (s.contains('wholesale') || s.contains('wholeseller') ||
        s.contains('distributor')) {
      return BuyerPricingTier.wholeseller;
    }
    return BuyerPricingTier.retail;
  }

  /// Adopts the tier from a login response or a fetched vendor profile.
  ///
  /// Safe to call with any map — unknown shapes simply leave the tier at
  /// [BuyerPricingTier.retail].
  void adoptFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return;
    set(tierFrom(
      vendorType: profile['vendor_type']?.toString(),
      shopType: profile['shop_type']?.toString(),
    ));
  }

  void set(BuyerPricingTier next) {
    if (_tier == next) return;
    _tier = next;
    notifyListeners();
  }

  /// Back to the default. Call on logout so one account's rate card can never
  /// leak into the next session.
  void reset() => set(BuyerPricingTier.retail);
}
