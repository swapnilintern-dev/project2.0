// =============================================================================
// MediCaPlus — Medicine information on the product details screen
//
// The details screen shows a product in this order (agreed with the business):
//
//   Product image
//   Product name
//   MRP / price, stock
//   Composition                         ← MedicineKeyInfo
//   Marketer                            ← MedicineKeyInfo
//   Storage                             ← MedicineKeyInfo
//   Product Information                 (description, cleaned by descriptionFor)
//   Precautions                         ← MedicineInfoPanel
//   Uses of Product                     ← MedicineInfoPanel
//   Side Effects                        ← MedicineInfoPanel
//   Directions of Use                   ← MedicineInfoPanel
//   Quantity, related products
//   Disclaimer, always last             ← MedicineDisclaimer
//
// Every part is driven by backend fields (server/model/productModel.js) and is
// HIDDEN when its value is empty, so products that have no medicine info yet
// look exactly as they did before.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'customer_models.dart';

/// "Marketed by X · Mfd. by Y", collapsed to one name when both are the same
/// company. Falls back to [Product.brand] — the line the screen always showed —
/// when neither company is known.
class MedicineCompanyLine extends StatelessWidget {
  const MedicineCompanyLine({super.key, required this.product});

  final Product product;

  /// The text to show, or '' when there is nothing to show. Exposed for tests.
  static String textFor(Product p) {
    final marketer = p.marketedBy.trim();
    final maker = p.manufacturer.trim();
    if (marketer.isEmpty && maker.isEmpty) return p.brand.trim();
    if (marketer.isEmpty) return 'Mfd. by $maker';
    if (maker.isEmpty || maker.toLowerCase() == marketer.toLowerCase()) {
      return 'By $marketer';
    }
    return 'Marketed by $marketer · Mfd. by $maker';
  }

  @override
  Widget build(BuildContext context) {
    final text = textFor(product);
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.business_outlined,
            size: 16, color: AppColors.darkGreen),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 13, color: AppColors.darkText, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// Composition, marketer and storage — shown right under the price.
class MedicineKeyInfo extends StatelessWidget {
  const MedicineKeyInfo({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final hasMarketer = MedicineCompanyLine.textFor(p).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.composition.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CompositionBox(text: p.composition),
        ],
        if (hasMarketer) ...[
          const SizedBox(height: 10),
          MedicineCompanyLine(product: p),
        ],
        if (p.storage.isNotEmpty) ...[
          const SizedBox(height: 10),
          _StorageRow(text: p.storage),
        ],
      ],
    );
  }
}

/// The product description without the "Composition: … / Uses: … /
/// Storage: …" lines the company import appended to it. A line is dropped
/// only when the same field already has its own place on the screen
/// (MedicineKeyInfo / MedicineInfoPanel), so nothing is lost — it just isn't
/// shown twice.
String descriptionFor(Product p) {
  final shownElsewhere = <String>{
    if (p.composition.isNotEmpty) 'composition',
    if (p.storage.isNotEmpty) 'storage',
    if (p.uses.isNotEmpty) 'uses',
  };
  if (shownElsewhere.isEmpty) return p.description.trim();
  final label = RegExp(r'^\s*([A-Za-z]+)\s*:');
  final kept = p.description.split('\n').where((line) {
    final m = label.firstMatch(line);
    return m == null || !shownElsewhere.contains(m.group(1)!.toLowerCase());
  });
  return kept.join('\n').trim();
}

/// The expandable Precautions / Uses / Side Effects / Directions sections,
/// in that order.
/// Renders nothing when the product carries none of them.
class MedicineInfoPanel extends StatelessWidget {
  const MedicineInfoPanel({super.key, required this.product});

  final Product product;

  /// True when there is at least one medicine-info field on the product.
  static bool hasAny(Product p) =>
      p.composition.isNotEmpty ||
      p.storage.isNotEmpty ||
      p.uses.isNotEmpty ||
      p.sideEffects.isNotEmpty ||
      p.precautions.isNotEmpty ||
      p.directions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final sections = <Widget>[
      if (p.precautions.isNotEmpty)
        _InfoSection(
          key: const ValueKey('med-precautions'),
          icon: Icons.warning_amber_rounded,
          title: 'Precautions',
          child: _paragraph(p.precautions),
        ),
      if (p.uses.isNotEmpty)
        _InfoSection(
          key: const ValueKey('med-uses'),
          icon: Icons.healing_outlined,
          title: 'Uses of Product',
          // Usually one short line, so it starts open.
          initiallyExpanded: true,
          child: _paragraph(p.uses),
        ),
      if (p.sideEffects.isNotEmpty)
        _InfoSection(
          key: const ValueKey('med-side-effects'),
          icon: Icons.report_gmailerrorred_outlined,
          title: 'Side Effects (${p.sideEffects.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final s in p.sideEffects) _bullet(s)],
          ),
        ),
      if (p.directions.isNotEmpty)
        _InfoSection(
          key: const ValueKey('med-directions'),
          icon: Icons.menu_book_outlined,
          title: 'Directions of Use',
          child: _paragraph(p.directions),
        ),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      // A Material (not a decorated Container) so the section headers' tap
      // ripple paints on it instead of being hidden underneath.
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              sections[i],
            ],
          ],
        ),
      ),
    );
  }

  static Widget _paragraph(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13.5, color: AppColors.darkText, height: 1.5),
      );

  static Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 8),
              child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.primary),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.darkText, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _CompositionBox extends StatelessWidget {
  const _CompositionBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined,
              size: 18, color: AppColors.darkGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Composition',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen)),
                const SizedBox(height: 2),
                Text(text,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.ac_unit, size: 16, color: AppColors.darkGreen),
        const SizedBox(width: 6),
        const Text('Storage: ',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText)),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.darkText, height: 1.35)),
        ),
      ],
    );
  }
}

/// One tappable, expandable section of the panel.
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile draws its own dividers; the panel already has them.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        iconColor: AppColors.darkGreen,
        collapsedIconColor: AppColors.greyText,
        leading: Icon(icon, size: 20, color: AppColors.darkGreen),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText)),
        children: [child],
      ),
    );
  }
}

/// General medical-information disclaimer. Same wording as the website
/// (src/constants/medicine.js); product-specific warnings stay in the
/// Precautions section and are never replaced by it.
const String kMedicalDisclaimer =
    'The information provided on this page is for general informational purposes '
    'and is not a substitute for professional medical advice, diagnosis, or '
    'treatment. Always follow the advice of a qualified healthcare professional '
    'and the approved product labeling. Do not start, stop, or change a medicine '
    'without consulting an appropriate healthcare professional. Verify the product '
    'name, strength, formulation, packaging, and prescription requirements before '
    'use or dispensing.';

/// Always the LAST thing on the product details screen.
class MedicineDisclaimer extends StatelessWidget {
  const MedicineDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lighterGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.darkGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              const TextSpan(children: [
                TextSpan(
                  text: 'Medical Information Disclaimer: ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: kMedicalDisclaimer),
              ]),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.greyText, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
