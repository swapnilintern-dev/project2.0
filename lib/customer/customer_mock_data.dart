// =============================================================================
// MediCaPlus — Customer Mock Data
//
// Sample catalogue / categories / coupons / addresses / orders used while the
// backend product & order endpoints are still being built. The CustomerApi
// (customer_api.dart) falls back to this data automatically when the server is
// unreachable, so the whole customer flow is fully clickable offline.
// =============================================================================

import 'package:flutter/material.dart';

import 'customer_models.dart';
import '../vendor_registration_screen.dart' show AppColors;

class MockData {
  MockData._();

  // Only three product categories exist across the whole app.
  static const List<Category> categories = [
    Category(id: 'injections', name: 'Lifesaving Injections', icon: Icons.vaccines, color: Color(0xFF3B82F6)),
    Category(id: 'vaccines', name: 'Vaccines', icon: Icons.health_and_safety, color: AppColors.primary),
    Category(id: 'medicine', name: 'Medicine', icon: Icons.medication, color: Color(0xFF8B5CF6)),
  ];

  static const List<Product> products = [
    Product(
      id: 'p1',
      title: 'Paracetamol 650mg',
      brand: 'Calpol · Strip of 15',
      description:
          'Effective relief from fever and mild-to-moderate pain. Each tablet '
          'contains 650mg paracetamol IP. Store below 30°C, away from direct light.',
      price: 36,
      mrp: 42,
      category: 'medicine',
      icon: Icons.medication,
      rating: 4.6,
      reviewCount: 1240,
      inStock: true,
      stockCount: 500,
      badge: 'BEST SELLER',
      packInfo: 'Strip of 15 tablets',
    ),
    Product(
      id: 'p2',
      title: 'Amoxicillin 500mg',
      brand: 'Mox · 10 caps',
      description:
          'Broad-spectrum antibiotic used to treat a wide range of bacterial '
          'infections. Take only as prescribed by your physician.',
      price: 84,
      mrp: 96,
      category: 'medicine',
      icon: Icons.medical_services,
      rating: 4.4,
      reviewCount: 860,
      inStock: true,
      stockCount: 320,
      badge: 'NEW',
      packInfo: 'Strip of 10 capsules',
    ),
    Product(
      id: 'p3',
      title: 'Insulin Glargine',
      brand: 'Lantus · 3ml pen',
      description:
          'Long-acting insulin for the management of diabetes mellitus. '
          'Refrigerate between 2°C and 8°C. Do not freeze.',
      price: 845,
      mrp: 980,
      category: 'injections',
      icon: Icons.vaccines,
      rating: 4.8,
      reviewCount: 410,
      inStock: true,
      stockCount: 18,
      badge: 'LOW STOCK',
      packInfo: '3ml prefilled pen',
    ),
    Product(
      id: 'p4',
      title: 'Cough Syrup 100ml',
      brand: 'Benadryl',
      description:
          'Soothes dry cough and throat irritation. Non-drowsy formula suitable '
          'for adults and children above 6 years.',
      price: 118,
      mrp: 135,
      category: 'medicine',
      icon: Icons.science,
      rating: 4.3,
      reviewCount: 690,
      inStock: true,
      stockCount: 210,
      packInfo: '100ml bottle',
    ),
    Product(
      id: 'p5',
      title: 'Azithromycin 250mg',
      brand: 'Azee · 6 caps',
      description:
          'Macrolide antibiotic capsule used for respiratory, skin and ENT '
          'infections. Complete the full course as prescribed.',
      price: 112,
      mrp: 130,
      category: 'medicine',
      icon: Icons.medication_outlined,
      rating: 4.5,
      reviewCount: 740,
      inStock: true,
      stockCount: 260,
      badge: 'BEST SELLER',
      packInfo: 'Strip of 6 capsules',
    ),
    Product(
      id: 'p6',
      title: 'Omeprazole 20mg',
      brand: 'Omez · 15 caps',
      description:
          'Proton-pump inhibitor capsule for acidity, heartburn and acid '
          'reflux. Take before meals or as advised.',
      price: 58,
      mrp: 72,
      category: 'medicine',
      icon: Icons.medication_outlined,
      rating: 4.4,
      reviewCount: 530,
      inStock: true,
      stockCount: 340,
      packInfo: 'Strip of 15 capsules',
    ),
    Product(
      id: 'p7',
      title: 'Antiseptic Cream 20g',
      brand: 'Burnol · Tube',
      description:
          'Soothing antiseptic ointment for minor burns, cuts and abrasions. '
          'For external use only.',
      price: 75,
      mrp: 90,
      category: 'medicine',
      icon: Icons.healing,
      rating: 4.6,
      reviewCount: 910,
      inStock: true,
      stockCount: 180,
      badge: 'NEW',
      packInfo: '20g tube',
    ),
    Product(
      id: 'p8',
      title: 'Pain Relief Gel 30g',
      brand: 'Volini · Tube',
      description:
          'Fast-acting topical gel for muscle, joint and back pain relief. '
          'Apply gently to the affected area up to thrice daily.',
      price: 145,
      mrp: 170,
      category: 'medicine',
      icon: Icons.healing,
      rating: 4.5,
      reviewCount: 1320,
      inStock: true,
      stockCount: 220,
      packInfo: '30g tube',
    ),
  ];

  static List<Product> get featured =>
      products.where((p) => p.badge == 'NEW' || p.badge == 'BEST SELLER').toList();

  static List<Product> get bestSellers =>
      products.where((p) => p.badge == 'BEST SELLER').toList();

  /// Promotional banners for the home carousel. In production these come from
  /// the marketing/admin backend (GET /vsArogya/promo-banners).
  static const List<PromoBanner> banners = [
    PromoBanner(
      id: 'b1',
      tag: 'BULK OFFER',
      title: 'Flat 20% OFF on orders above ₹5,000',
      ctaLabel: 'Shop Now',
      startColor: Color(0xFF4CAF82),
      endColor: Color(0xFF2E7D5E),
    ),
    PromoBanner(
      id: 'b2',
      tag: 'NEW ARRIVALS',
      title: 'Antibiotics & syrups now up to 30% OFF',
      ctaLabel: 'Explore',
      startColor: Color(0xFF3B82F6),
      endColor: Color(0xFF1E40AF),
      categoryId: 'syrups',
    ),
    PromoBanner(
      id: 'b3',
      tag: 'MONSOON CARE',
      title: 'Stock up on essentials · Free delivery',
      ctaLabel: 'Order Now',
      startColor: Color(0xFFF59E0B),
      endColor: Color(0xFFB45309),
    ),
    PromoBanner(
      id: 'b4',
      tag: 'FIRST ORDER',
      title: 'Get 10% OFF with code FIRST10',
      ctaLabel: 'Grab Deal',
      startColor: Color(0xFF8B5CF6),
      endColor: Color(0xFF5B21B6),
    ),
  ];

  static const List<Coupon> coupons = [
    Coupon(code: 'BULK20', description: 'Flat 20% off on orders above ₹5,000', percentOff: 20, maxDiscount: 2000),
    Coupon(code: 'FIRST10', description: '10% off on your first order', percentOff: 10, maxDiscount: 500),
    Coupon(code: 'HEALTH15', description: '15% off on select medicines', percentOff: 15, maxDiscount: 1000),
  ];

  static const List<Address> addresses = [
    Address(
      id: 'a1',
      label: 'Home',
      fullName: 'Apollo Pharmacy',
      phone: '+91 98765 43210',
      line1: 'Shop 14, Link Road, Andheri West',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400053',
      isDefault: true,
    ),
    Address(
      id: 'a2',
      label: 'Work',
      fullName: 'Apollo Pharmacy',
      phone: '+91 98765 43210',
      line1: 'Unit 4, MIDC Industrial Area, Marol',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400059',
    ),
  ];

  /// Seed orders so the Orders tab is populated on first run.
  static List<Order> seedOrders() {
    final now = DateTime(2026, 6, 15, 11, 2);
    return [
      Order(
        id: 'MCP-48210',
        placedAt: now,
        status: OrderStatus.outForDelivery,
        items: [
          OrderItem(title: 'Paracetamol 650mg', brand: 'Calpol', price: 36, quantity: 15, icon: Icons.medication),
          OrderItem(title: 'Amoxicillin 500mg', brand: 'Mox', price: 84, quantity: 10, icon: Icons.medical_services),
        ],
        address: addresses.first,
        paymentMethod: PaymentMethod.cod,
        subtotal: 1380,
        deliveryFee: 40,
        gst: 165,
        discount: 66,
      ),
      Order(
        id: 'MCP-48108',
        placedAt: DateTime(2026, 6, 12, 9, 30),
        status: OrderStatus.delivered,
        items: [
          OrderItem(title: 'Insulin Glargine', brand: 'Lantus', price: 845, quantity: 4, icon: Icons.vaccines),
        ],
        address: addresses.first,
        paymentMethod: PaymentMethod.upi,
        subtotal: 3380,
        deliveryFee: 0,
        gst: 169,
        discount: 169,
      ),
      Order(
        id: 'MCP-47855',
        placedAt: DateTime(2026, 6, 2, 18, 45),
        status: OrderStatus.cancelled,
        items: [
          OrderItem(title: 'Cough Syrup 100ml', brand: 'Benadryl', price: 118, quantity: 12, icon: Icons.science),
        ],
        address: addresses.first,
        paymentMethod: PaymentMethod.netBanking,
        subtotal: 1416,
        deliveryFee: 0,
        gst: 0,
        discount: 0,
      ),
    ];
  }
}
