// =============================================================================
// MediCaPlus — About Us (VS Arogya) Screen
//
// Company profile shown from Profile › About Us. A hero banner followed by the
// story, mission, "why choose us", cold-chain guidance, recommended storage
// temperatures, services and the product range. Pure content — no backend.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const String _intro =
      'Welcome to VS Arogya Meda Pvt. Ltd., the premier provider of lifesaving '
      'injections, critical illness medicines and vaccines in Bihar & Jharkhand. '
      'As the leading dealer in the region, we pride ourselves on offering the '
      'lowest prices without compromising on quality, ensuring that our customers '
      'receive the best value for their money.';

  static const String _story =
      'Founded in 2017, VS Enterprises began with a simple mission: to deliver '
      'the highest quality lifesaving injections, medicine & vaccine products '
      'that ensure safety, reliability, and efficiency. Over the years, we have '
      'grown from a small local shop to a recognized name in the industry, thanks '
      'to our unwavering commitment to excellence and customer satisfaction.';

  static const String _mission =
      'Our mission is to provide the highest quality medical injections to those '
      'in need, quickly and efficiently. We understand the urgency and importance '
      'of lifesaving medications, and we are dedicated to making them accessible '
      'to everyone at the most competitive prices.';

  static const String _coldChainIntro =
      'Lifesaving injections and vaccines are highly sensitive to temperature. '
      'Maintaining the cold chain from manufacture to administration is critical:';

  static const String _productRange =
      'We specialize in providing a range of lifesaving and critical illness '
      'injections to address various severe health conditions. Our product line '
      'includes insulin for diabetes management, essential for regulating blood '
      'sugar levels and preventing complications. We supply vaccines such as the '
      'Hepatitis B and Influenza vaccines, critical for preventing serious '
      'infectious diseases. For cancer patients, we offer chemotherapeutic agents '
      'like Doxorubicin, vital for treating various cancers. Additionally, we '
      'provide Epoetin alfa for anemia (particularly in chronic kidney disease) '
      'and clotting factor concentrates for hemophilia patients, crucial for '
      'managing bleeding disorders. Our commitment to maintaining the highest '
      'quality and ensuring rapid delivery means these lifesaving treatments are '
      'available when and where they are needed most.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title:
            const Text('About Us', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          // --- Hero banner -----------------------------------------------------
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.lightGreenBg,
              image: const DecorationImage(
                image: AssetImage('assets/vs_arogya_banner.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Intro -----------------------------------------------------------
          const _Paragraph(_intro),
          const SizedBox(height: 24),

          // --- Our Story -------------------------------------------------------
          const _SectionHeading('Our Story'),
          const SizedBox(height: 8),
          const _Paragraph(_story),
          const SizedBox(height: 24),

          // --- Our Mission -----------------------------------------------------
          const _SectionHeading('Our Mission'),
          const SizedBox(height: 8),
          const _Paragraph(_mission),
          const SizedBox(height: 24),

          // --- Why Choose Us ---------------------------------------------------
          const _SectionHeading('Why Choose Us?'),
          const SizedBox(height: 12),
          const _NumberedPoint(
            1,
            'Unmatched Quality',
            'We source our injections from reputable manufacturers and dealers '
                'so every product meets the highest standards of quality and '
                'safety, backed by strict cold-chain maintenance.',
          ),
          const _NumberedPoint(
            2,
            'Lowest Prices',
            'We are committed to offering the most affordable prices in the '
                'market, ensuring you get the best value for your money.',
          ),
          const _NumberedPoint(
            3,
            'Rapid Delivery',
            'Our efficient delivery system fulfils orders within a few hours, '
                'maintaining the integrity of the cold chain to preserve the '
                'effectiveness of the medications.',
          ),
          const _NumberedPoint(
            4,
            'Convenient Ordering',
            'With our user-friendly app you can create quick purchase orders and '
                'have products delivered to your doorstep or shop in no time.',
          ),
          const SizedBox(height: 24),

          // --- Cold chain ------------------------------------------------------
          const _SectionHeading('Why Cold Chain Maintenance is Critical'),
          const SizedBox(height: 8),
          const _Paragraph(_coldChainIntro),
          const SizedBox(height: 12),
          const _NumberedPoint(
            1,
            'Preservation of Potency',
            'Maintaining the correct temperature preserves potency, keeping '
                'injections and vaccines effective when administered.',
          ),
          const _NumberedPoint(
            2,
            'Prevention of Degradation',
            'Biological materials degrade quickly outside the recommended range, '
                'leading to loss of therapeutic effect.',
          ),
          const _NumberedPoint(
            3,
            'Safety Assurance',
            'Incorrect storage can cause contamination or microbial growth, '
                'posing serious health risks to patients.',
          ),
          const _NumberedPoint(
            4,
            'Regulatory Compliance',
            'Adhering to cold-chain protocols meets legal standards, preventing '
                'issues and ensuring patient trust.',
          ),
          const SizedBox(height: 24),

          // --- Recommended temperatures ---------------------------------------
          const _SectionHeading('Recommended Storage Temperatures'),
          const SizedBox(height: 12),
          const _TempCard(
            label: 'Vaccines',
            range: '2°C – 8°C',
            note: 'Hepatitis, influenza, diphtheria and similar vaccines.',
          ),
          const _TempCard(
            label: 'Insulin',
            range: '2°C – 8°C',
            note: 'Never freeze. Opened vials keep below 25°C for up to 28 days.',
          ),
          const _TempCard(
            label: 'Blood Products',
            range: '2°C – 8°C',
            note: 'Clotting factors and certain albumins, for stability.',
          ),
          const _TempCard(
            label: 'Monoclonal Antibodies',
            range: '2°C – 8°C',
            note: 'Avoid fluctuations that degrade the protein structure.',
          ),
          const _TempCard(
            label: 'Antivenoms',
            range: '2°C – 8°C',
            note: 'Preserves potency in neutralizing venom.',
          ),
          const SizedBox(height: 24),

          // --- Our Services ----------------------------------------------------
          const _SectionHeading('Our Services'),
          const SizedBox(height: 12),
          const _BulletPoint(
            'Retail & Wholesale',
            'Tailored solutions for individual customers and bulk purchasers.',
          ),
          const _BulletPoint(
            'Online Ordering',
            'Place orders quickly and track delivery in real time.',
          ),
          const _BulletPoint(
            'Cold Chain Management',
            'Products stored and transported under optimal conditions.',
          ),
          const SizedBox(height: 24),

          // --- Product range ---------------------------------------------------
          const _SectionHeading('What We Provide'),
          const SizedBox(height: 8),
          const _Paragraph(_productRange),
        ],
      ),
    );
  }
}

/// Bold green section title.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: AppColors.darkGreen,
      ),
    );
  }
}

/// Justified body paragraph.
class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: AppColors.darkText,
      ),
    );
  }
}

/// A numbered point with an emphasised lead-in title.
class _NumberedPoint extends StatelessWidget {
  const _NumberedPoint(this.number, this.title, this.body);

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: AppColors.lightGreenBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A check-marked service bullet with a lead-in title.
class _BulletPoint extends StatelessWidget {
  const _BulletPoint(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle,
                size: 20, color: AppColors.darkGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A card showing a product family, its temperature range and a short note.
class _TempCard extends StatelessWidget {
  const _TempCard({
    required this.label,
    required this.range,
    required this.note,
  });

  final String label;
  final String range;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.thermostat, size: 22, color: AppColors.darkGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              range,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
