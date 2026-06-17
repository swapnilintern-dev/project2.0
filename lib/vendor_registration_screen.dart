// =============================================================================
// MediCaPlus — B2B Medicine Delivery
// Vendor Registration Flow
//
// Connected to the Express + MongoDB backend via VendorApiService
// (POST /vsArogya/register-vendor). The screen owns the UI + validation; the
// network call lives in lib/services/vendor_api_service.dart.
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'services/vendor_api_service.dart';

// =============================================================================
// THEME
// =============================================================================

/// Centralised palette so the whole flow stays visually consistent.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4CAF82); // Primary Green
  static const Color darkGreen = Color(0xFF2E7D5E); // Dark Green
  static const Color lightGreenBg = Color(0xFFE8F5EE); // Light Green Background
  static const Color lighterGreen = Color(0xFFF0FAF5); // Lighter Green
  static const Color pageBg = Color(0xFFF5F7F5); // Page Background
  static const Color white = Color(0xFFFFFFFF); // White
  static const Color darkText = Color(0xFF1A1A2E); // Dark Text
  static const Color greyText = Color(0xFF757575); // Grey Text
  static const Color error = Color(0xFFE53935); // Error Red
  static const Color border = Color(0xFFDDEEE6); // Border Color

  /// Reused gradient for hero banners and the primary submit button.
  static const LinearGradient greenGradient = LinearGradient(
    colors: [primary, darkGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// =============================================================================
// DATA MODEL
// =============================================================================

/// Single source of truth for everything the vendor enters across all 4 steps.
///
/// The screen keeps `TextEditingController`s for live input and copies their
/// values into an instance of this model as the user advances. `toJson()`
/// produces the exact payload the backend will eventually receive.
class VendorRegistrationModel {
  // --- Step 1: Basic Details ---
  String? vendorType;
  String? shopType;
  String storeName;
  String contactPerson;
  String mobile;
  String email;
  String fullAddress;
  String city;
  String state;
  String pinCode;

  // --- Step 2: Business Info ---
  String? gstStatus;
  String gstNumber;
  String drugLicenseNumber;
  DateTime? drugLicenseExpiry;

  // --- Step 3: Documents (local file paths; real upload handled by the API) ---
  String? storePhotoPath;
  String? drugLicenseCopyPath;
  String? gstCertificatePath;
  bool declarationAccepted;

  VendorRegistrationModel({
    this.vendorType,
    this.shopType,
    this.storeName = '',
    this.contactPerson = '',
    this.mobile = '',
    this.email = '',
    this.fullAddress = '',
    this.city = '',
    this.state = '',
    this.pinCode = '',
    this.gstStatus,
    this.gstNumber = '',
    this.drugLicenseNumber = '',
    this.drugLicenseExpiry,
    this.storePhotoPath,
    this.drugLicenseCopyPath,
    this.gstCertificatePath,
    this.declarationAccepted = false,
  });

  /// Serialises the registration into the request body for the backend.
  ///
  /// TODO: POST /api/vendor/register
  Map<String, dynamic> toJson() {
    return {
      'basicDetails': {
        'vendorType': vendorType,
        'shopType': shopType,
        'storeName': storeName,
        'contactPerson': contactPerson,
        'mobile': mobile,
        'email': email,
        'fullAddress': fullAddress,
        'city': city,
        'state': state,
        'pinCode': pinCode,
      },
      'businessInfo': {
        'gstStatus': gstStatus,
        'gstNumber': gstNumber,
        'drugLicenseNumber': drugLicenseNumber,
        'drugLicenseExpiry': drugLicenseExpiry?.toIso8601String(),
      },
      'documents': {
        // These are local paths for now; the API will receive multipart files.
        'storePhoto': storePhotoPath,
        'drugLicenseCopy': drugLicenseCopyPath,
        'gstCertificate': gstCertificatePath,
      },
      'declarationAccepted': declarationAccepted,
    };
  }
}

// =============================================================================
// STATIC OPTION LISTS
// =============================================================================

const List<String> _vendorTypes = [
  'Shop / Pharmacy',
  'Hospital / Clinic',
  
];

const List<String> _shopTypes = [
  'Retail Pharmacy',
  'Wholesale Pharmacy',
  'Online Pharmacy',
  'Hospital Pharmacy',
  'Ayurvedic / Herbal Store',
  'Medical Equipment',
];

const List<String> _gstStatuses = [
  'Registered (Regular)',
  'Registered (Composition)',
  'Unregistered',
  'Exempt',
];

// =============================================================================
// REGISTRATION SCREEN (Steps 1–4)
// =============================================================================

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // The model that accumulates everything the vendor enters.
  final VendorRegistrationModel _model = VendorRegistrationModel();

  // Current step index: 0 = Basic, 1 = Business, 2 = Docs, 3 = Review.
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Fade animation driven between step transitions.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // Independent form keys so each step validates on its own.
  final GlobalKey<FormState> _basicFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _businessFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _docsFormKey = GlobalKey<FormState>();

  // --- Step 1 controllers ---
  final _storeNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // --- Step 2 controllers ---
  final _gstNumberCtrl = TextEditingController();
  final _drugLicenseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // start fully visible
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _storeNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _gstNumberCtrl.dispose();
    _drugLicenseCtrl.dispose();
    super.dispose();
  }

  // True when the selected GST status implies a GSTIN is required.
  bool get _gstRegistered =>
      _model.gstStatus == 'Registered (Regular)' ||
      _model.gstStatus == 'Registered (Composition)';

  // ---------------------------------------------------------------------------
  // Navigation between steps (with fade animation)
  // ---------------------------------------------------------------------------

  Future<void> _animateToStep(int step) async {
    await _fadeController.reverse();
    if (!mounted) return;
    setState(() => _currentStep = step);
    FocusScope.of(context).unfocus();
    await _fadeController.forward();
  }

  /// Validates the current step, copies its values into the model and advances.
  void _onContinue() {
    switch (_currentStep) {
      case 0:
        if (!(_basicFormKey.currentState?.validate() ?? false)) return;
        _saveBasic();
        _animateToStep(1);
        break;
      case 1:
        if (!(_businessFormKey.currentState?.validate() ?? false)) return;
        _saveBusiness();
        _animateToStep(2);
        break;
      case 2:
        if (!_validateDocuments()) return;
        _animateToStep(3);
        break;
    }
  }

  void _onBack() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
    } else {
      _animateToStep(_currentStep - 1);
    }
  }

  // Jump straight to a step from the review screen's "Edit" buttons.
  void _editStep(int step) => _animateToStep(step);

  void _saveBasic() {
    _model
      ..storeName = _storeNameCtrl.text.trim()
      ..contactPerson = _contactPersonCtrl.text.trim()
      ..mobile = _mobileCtrl.text.trim()
      ..email = _emailCtrl.text.trim()
      ..fullAddress = _addressCtrl.text.trim()
      ..city = _cityCtrl.text.trim()
      ..state = _stateCtrl.text.trim()
      ..pinCode = _pinCtrl.text.trim();
  }

  void _saveBusiness() {
    _model
      ..gstNumber = _gstRegistered ? _gstNumberCtrl.text.trim() : ''
      ..drugLicenseNumber = _drugLicenseCtrl.text.trim();
  }

  // Documents step isn't a normal Form, so validate manually.
  bool _validateDocuments() {
    // Backend hard-requires the store photo (multer field `store_pic`).
    if (_model.storePhotoPath == null) {
      _showSnack('Please upload a Store Photo (required).');
      return false;
    }
    if (_model.drugLicenseCopyPath == null) {
      _showSnack('Please upload the Drug License Copy (required).');
      return false;
    }
    if (!_model.declarationAccepted) {
      _showSnack('Please accept the declaration to continue.');
      return false;
    }
    return true;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.darkGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // POST /vsArogya/register-vendor (multipart) via the API service.
    final VendorApiResult result =
        await const VendorApiService().registerVendor(_model);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      // Surface the backend's message (e.g. "Store image is required",
      // duplicate email, validation errors) instead of failing silently.
      _showSnack(result.message);
      return;
    }

    // Prefer the real MongoDB id as the application reference; fall back to a
    // generated one if the server didn't echo the vendor document.
    final id = result.vendor?['_id']?.toString();
    final ref = (id != null && id.length >= 6)
        ? 'VND-${id.substring(id.length - 6).toUpperCase()}'
        : 'VND-2024-MP-${(1000 + Random().nextInt(9000))}';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrationSuccessScreen(referenceId: ref),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _StepperBar(currentStep: _currentStep),
            // Animated, scrollable step body.
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepBody(),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const titles = [
      'Step 1 of 4 · Basic Details',
      'Step 2/4 · Business Info',
      'Step 3/4 · Documents Upload',
      'Step 4/4 · Review & Submit',
    ];
    final percent = _currentStep * 25;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: AppColors.darkText,
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vendor Registration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titles[_currentStep],
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          // Progress percentage badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    // IndexedStack keeps each step's state (and form) alive when switching.
    return SingleChildScrollView(
      key: ValueKey(_currentStep),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: switch (_currentStep) {
        0 => _buildBasicStep(),
        1 => _buildBusinessStep(),
        2 => _buildDocumentsStep(),
        _ => _buildReviewStep(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1 — Basic Details
  // ---------------------------------------------------------------------------

  Widget _buildBasicStep() {
    return Form(
      key: _basicFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          _SectionCard(
            icon: Icons.storefront_outlined,
            title: 'Basic Information',
            children: [
              _AppDropdown(
                label: 'Vendor Type',
                required: true,
                value: _model.vendorType,
                hint: 'Select vendor type',
                items: _vendorTypes,
                onChanged: (v) => setState(() => _model.vendorType = v),
              ),
              _AppDropdown(
                label: 'Shop Type',
                required: true,
                value: _model.shopType,
                hint: 'Select Shop Type',
                items: _shopTypes,
                onChanged: (v) => setState(() => _model.shopType = v),
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.call_outlined,
            title: 'Contact Details',
            children: [
              _AppTextField(
                label: 'Store / Clinic Name',
                required: true,
                controller: _storeNameCtrl,
                hint: 'Enter your store/clinic name',
                validator: _requiredValidator('Store / Clinic Name'),
              ),
              _AppTextField(
                label: 'Contact Person Name',
                required: true,
                controller: _contactPersonCtrl,
                hint: 'Name of the contact person',
                validator: _requiredValidator('Contact Person Name'),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AppTextField(
                      label: 'Mobile (WhatsApp)',
                      required: true,
                      controller: _mobileCtrl,
                      hint: '10-digit number',
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Mobile number is required';
                        }
                        if (v.trim().length != 10) {
                          return 'Enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AppTextField(
                      // Required + unique on the backend, so required here too.
                      label: 'Email Address',
                      required: true,
                      controller: _emailCtrl,
                      hint: 'name@email.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        final ok = RegExp(
                          r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$',
                        ).hasMatch(v.trim());
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.location_on_outlined,
            title: 'Address Details',
            children: [
              _AppTextField(
                label: 'Full Address',
                required: true,
                controller: _addressCtrl,
                hint: 'Street address, area, landmark',
                maxLines: 2,
                validator: _requiredValidator('Full Address'),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AppTextField(
                      label: 'City',
                      required: true,
                      controller: _cityCtrl,
                      hint: 'City',
                      validator: _requiredValidator('City'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AppTextField(
                      label: 'State',
                      required: true,
                      controller: _stateCtrl,
                      hint: 'State',
                      validator: _requiredValidator('State'),
                    ),
                  ),
                ],
              ),
              _AppTextField(
                label: 'Pin Code',
                required: true,
                controller: _pinCtrl,
                hint: '6-digit pin code',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Pin Code is required';
                  }
                  if (v.trim().length != 6) return 'Enter a valid 6-digit pin';
                  return null;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2 — Business Info
  // ---------------------------------------------------------------------------

  Widget _buildBusinessStep() {
    return Form(
      key: _businessFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          _SectionCard(
            icon: Icons.business_center_outlined,
            title: 'Business Details',
            children: [
              _AppDropdown(
                label: 'GST Status',
                required: true,
                value: _model.gstStatus,
                hint: 'Select GST status',
                items: _gstStatuses,
                onChanged: (v) => setState(() => _model.gstStatus = v),
              ),
              // GSTIN only shown when a "Registered" status is selected.
              if (_gstRegistered)
                _AppTextField(
                  label: 'GST Number (GSTIN)',
                  required: true,
                  controller: _gstNumberCtrl,
                  hint: '15-character GSTIN',
                  maxLength: 15,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [_UpperCaseFormatter()],
                  validator: (v) {
                    if (!_gstRegistered) return null;
                    if (v == null || v.trim().isEmpty) {
                      return 'GSTIN is required';
                    }
                    if (v.trim().length != 15) {
                      return 'GSTIN must be 15 characters';
                    }
                    return null;
                  },
                ),
              _AppTextField(
                label: 'Drug License Number',
                required: true,
                controller: _drugLicenseCtrl,
                hint: 'License number issued by FDA',
                validator: _requiredValidator('Drug License Number'),
              ),
              _DatePickerField(
                label: 'Drug License Expiry Date',
                required: true,
                value: _model.drugLicenseExpiry,
                hint: 'Select expiry date',
                onTap: _pickExpiryDate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _model.drugLicenseExpiry ??
          now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)), // future dates only
      lastDate: DateTime(now.year + 30),
      helpText: 'Select Drug License Expiry Date',
      builder: (context, child) {
        // Green theme override for the calendar dialog.
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.darkText,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _model.drugLicenseExpiry = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 3 — Documents Upload
  // ---------------------------------------------------------------------------

  Widget _buildDocumentsStep() {
    return Form(
      key: _docsFormKey,
      child: Column(
        children: [
          // Yellow warning banner.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF9A825), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upload clear images or PDFs  (Max: 5 MB each)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8D6E00),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.cloud_upload_outlined,
            title: 'Documents Upload',
            children: [
              _DocumentUploadTile(
                title: 'Store Photo',
                subtitle: 'Upload a clear photo of your store',
                required: true,
                fileName: _fileName(_model.storePhotoPath),
                onCamera: () =>
                    _pickDoc(ImageSource.camera, (p) => _model.storePhotoPath = p),
                onGallery: () => _pickDoc(
                    ImageSource.gallery, (p) => _model.storePhotoPath = p),
                onRemove: () =>
                    setState(() => _model.storePhotoPath = null),
              ),
              _DocumentUploadTile(
                title: 'Drug License Copy',
                subtitle: 'Mandatory document',
                required: true,
                fileName: _fileName(_model.drugLicenseCopyPath),
                onCamera: () => _pickDoc(
                    ImageSource.camera, (p) => _model.drugLicenseCopyPath = p),
                onGallery: () => _pickDoc(
                    ImageSource.gallery, (p) => _model.drugLicenseCopyPath = p),
                onRemove: () =>
                    setState(() => _model.drugLicenseCopyPath = null),
              ),
              _DocumentUploadTile(
                title: 'GST Certificate',
                subtitle: 'GST registration certificate (optional)',
                fileName: _fileName(_model.gstCertificatePath),
                onCamera: () => _pickDoc(
                    ImageSource.camera, (p) => _model.gstCertificatePath = p),
                onGallery: () => _pickDoc(
                    ImageSource.gallery, (p) => _model.gstCertificatePath = p),
                onRemove: () =>
                    setState(() => _model.gstCertificatePath = null),
                isLast: true,
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.verified_user_outlined,
            title: 'Declaration',
            children: [
              _AnimatedCheckTile(
                value: _model.declarationAccepted,
                onChanged: (v) =>
                    setState(() => _model.declarationAccepted = v),
                label:
                    'I confirm that I am submitting this registration as a '
                    'genuine vendor and all information provided is accurate.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Picks an image from camera/gallery and stores its path via [assign].
  ///
  /// Images are downscaled and recompressed at capture so uploads stay well
  /// under the backend's 10 MB-per-file limit (raw phone-camera photos are
  /// often 10–20 MB, which would abort the multipart request).
  Future<void> _pickDoc(
      ImageSource source, void Function(String path) assign) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() => assign(file.path));
      }
    } catch (e) {
      // Camera/gallery may be unavailable (e.g. on desktop / no permission).
      if (mounted) _showSnack('Could not open ${source.name}. ($e)');
    }
  }

  String? _fileName(String? path) {
    if (path == null) return null;
    return path.split(RegExp(r'[/\\]')).last;
  }

  // ---------------------------------------------------------------------------
  // STEP 4 — Review & Submit
  // ---------------------------------------------------------------------------

  Widget _buildReviewStep() {
    String dash(String v) => v.trim().isEmpty ? '—' : v;
    final expiry = _model.drugLicenseExpiry;

    return Column(
      children: [
        // Green gradient "Almost Done" banner.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.white, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost Done!',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review your details carefully before submitting',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Basic Details ---
        _ReviewSection(
          icon: Icons.storefront_outlined,
          title: 'Basic Details',
          onEdit: () => _editStep(0),
          rows: [
            _ReviewRow('Vendor Type', dash(_model.vendorType ?? '')),
            _ReviewRow('Shop Type', dash(_model.shopType ?? '')),
            _ReviewRow('Store Name', dash(_model.storeName)),
            _ReviewRow('Contact Person', dash(_model.contactPerson)),
            _ReviewRow('Mobile', dash(_model.mobile)),
            _ReviewRow('Email', dash(_model.email)),
            _ReviewRow('Address', dash(_model.fullAddress)),
            _ReviewRow('City / State',
                '${dash(_model.city)}, ${dash(_model.state)}'),
            _ReviewRow('Pin Code', dash(_model.pinCode)),
          ],
        ),

        // --- Business Info ---
        _ReviewSection(
          icon: Icons.business_center_outlined,
          title: 'Business Info',
          onEdit: () => _editStep(1),
          rows: [
            _ReviewRow('GST Status', dash(_model.gstStatus ?? '')),
            if (_gstRegistered) _ReviewRow('GSTIN', dash(_model.gstNumber)),
            _ReviewRow('Drug License No.', dash(_model.drugLicenseNumber)),
            _ReviewRow(
              'License Expiry',
              expiry == null ? '—' : _formatDate(expiry),
            ),
          ],
        ),

        // --- Documents ---
        _ReviewSection(
          icon: Icons.folder_open_outlined,
          title: 'Documents',
          onEdit: () => _editStep(2),
          rows: [
            _ReviewRow.doc('Store Photo', _model.storePhotoPath != null),
            _ReviewRow.doc(
                'Drug License Copy', _model.drugLicenseCopyPath != null),
            _ReviewRow.doc('GST Certificate', _model.gstCertificatePath != null),
          ],
        ),

        const SizedBox(height: 8),
        // Security note.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lighterGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: const [
              Text('🔒', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your information is secure and will only be used for '
                  'verification purposes.',
                  style: TextStyle(fontSize: 12, color: AppColors.greyText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar (changes per step)
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bool showBack = _currentStep > 0;
    final bool isReview = _currentStep == 3;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              flex: 2,
              child: _SecondaryButton(
                label: '← Back',
                onPressed: _isSubmitting ? null : _onBack,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: isReview
                ? _GradientButton(
                    label: '🚀 Submit Registration',
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  )
                : _GradientButton(
                    label: 'Continue →',
                    onPressed: _onContinue,
                  ),
          ),
        ],
      ),
    );
  }

  // Shared "required" validator factory.
  String? Function(String?) _requiredValidator(String field) {
    return (v) =>
        (v == null || v.trim().isEmpty) ? '$field is required' : null;
  }
}

// =============================================================================
// SUCCESS SCREEN (Step 5)
// =============================================================================

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key, required this.referenceId});

  final String referenceId;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Green gradient top half with the success check.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 44),
              decoration: const BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.white, size: 60),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Registration Submitted!',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your application is under review',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // "What happens next?" card.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'What happens next?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          SizedBox(height: 16),
                          _NextStepItem(
                            icon: Icons.search,
                            title: 'Application Review',
                            subtitle:
                                'Our team will verify your documents within '
                                '24–48 hours.',
                          ),
                          _NextStepItem(
                            icon: Icons.phone_in_talk_outlined,
                            title: 'Verification Call',
                            subtitle:
                                "You'll receive a WhatsApp/call from our "
                                'onboarding team.',
                          ),
                          _NextStepItem(
                            icon: Icons.verified_outlined,
                            title: 'Account Activation',
                            subtitle:
                                'Once verified, your vendor account will be '
                                'activated.',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Application reference with copy button.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Application Reference',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.greyText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '#$referenceId',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: '#$referenceId'));
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Reference copied'),
                                    backgroundColor: AppColors.darkGreen,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions.
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
              color: AppColors.white,
              child: Column(
                children: [
                  _GradientButton(
                    label: 'Go to Home',
                    onPressed: () => Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: navigate to application status tracking screen.
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Track Application Status',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepItem extends StatelessWidget {
  const _NextStepItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon dot + connecting vertical line.
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreenBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.darkGreen),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.greyText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REUSABLE WIDGETS
// =============================================================================

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

/// A titled white card with an icon header — the building block of every step.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.darkGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

/// Field label with an optional red asterisk for required inputs.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared input border styling so every field looks identical.
InputDecoration _inputDecoration(String hint) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
    filled: true,
    fillColor: AppColors.lighterGreen,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    counterText: '',
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
  );
}

/// Themed text field with inline validation (red border + message).
class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: const TextStyle(fontSize: 14, color: AppColors.darkText),
          decoration: _inputDecoration(hint),
        ),
      ],
    );
  }
}

/// Themed dropdown built on `DropdownButtonFormField`.
class _AppDropdown extends StatelessWidget {
  const _AppDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.required = false,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.greyText),
          hint: Text(
            hint,
            style: const TextStyle(color: AppColors.greyText, fontSize: 13),
          ),
          validator: required
              ? (v) => v == null ? 'Please select $label' : null
              : null,
          style: const TextStyle(fontSize: 14, color: AppColors.darkText),
          decoration: _inputDecoration(hint),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A read-only field that opens a date picker; styled like a normal input.
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final String hint;
  final VoidCallback onTap;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _inputDecoration(hint).copyWith(
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.primary),
              ),
              suffixIcon: const Icon(Icons.edit_calendar_outlined,
                  size: 18, color: AppColors.greyText),
            ),
            child: Text(
              hasValue ? _formatDate(value!) : hint,
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? AppColors.darkText : AppColors.greyText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Upload tile: title + subtitle, camera/gallery buttons, or the selected file
/// name with a remove button once a file is chosen.
class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.title,
    required this.subtitle,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    this.fileName,
    this.required = false,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;
  final String? fileName;
  final bool required;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final uploaded = fileName != null;
    return Container(
      margin: EdgeInsets.only(top: 12, bottom: isLast ? 4 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uploaded ? AppColors.lightGreenBg : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: uploaded ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: uploaded
                      ? AppColors.primary
                      : AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  uploaded ? Icons.check : Icons.description_outlined,
                  size: 20,
                  color: uploaded ? AppColors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                        children: [
                          if (required)
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(color: AppColors.error),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uploaded ? fileName! : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              if (uploaded)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.error,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          // Camera + gallery buttons only when nothing is uploaded yet.
          if (!uploaded) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _UploadButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onPressed: onCamera,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _UploadButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onPressed: onGallery,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkGreen,
        backgroundColor: AppColors.lighterGreen,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Custom animated checkbox + declaration label.
class _AnimatedCheckTile extends StatelessWidget {
  const _AnimatedCheckTile({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: value ? 1 : 0,
                child: const Icon(Icons.check,
                    size: 16, color: AppColors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.darkText,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// STEPPER
// =============================================================================

enum _StepState { inactive, active, completed }

class _StepperBar extends StatelessWidget {
  const _StepperBar({required this.currentStep});

  final int currentStep;

  static const _labels = ['Basic', 'Business', 'Docs', 'Review'];

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = [];
    for (int i = 0; i < 4; i++) {
      final state = i < currentStep
          ? _StepState.completed
          : (i == currentStep ? _StepState.active : _StepState.inactive);
      row.add(_StepDot(index: i, state: state, label: _labels[i]));
      if (i < 3) {
        // Connector turns green once the previous step is completed.
        row.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i < currentStep
                      ? AppColors.primary
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row,
      ),
    );
  }
}

/// A single numbered step: grey outline (inactive), green glowing (active),
/// or green filled with a check (completed).
class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.state,
    required this.label,
  });

  final int index;
  final _StepState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool active = state == _StepState.active;
    final bool completed = state == _StepState.completed;
    final bool filled = active || completed;

    return SizedBox(
      width: 52,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: filled ? AppColors.primary : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: filled ? AppColors.primary : AppColors.border,
                width: 2,
              ),
              boxShadow: active
                  ? [
                      // Glow only on the active step.
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, size: 16, color: AppColors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.white : AppColors.greyText,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
              color: filled ? AppColors.darkText : AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REVIEW WIDGETS
// =============================================================================

/// A collapsible review card with an Edit action and label/value rows.
class _ReviewSection extends StatefulWidget {
  const _ReviewSection({
    required this.icon,
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final List<_ReviewRow> rows;

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          // Header: icon + title + Edit + expand/collapse.
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: AppColors.darkGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.greyText,
                  ),
                ],
              ),
            ),
          ),
          // Rows.
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(children: widget.rows),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// One label/value row with a divider. Use `_ReviewRow.doc` for ✅/❌ documents.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value)
      : isDoc = false,
        present = false;

  const _ReviewRow.doc(this.label, this.present)
      : value = '',
        isDoc = true;

  final String label;
  final String value;
  final bool isDoc;
  final bool present;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: isDoc
                    ? Row(
                        children: [
                          Text(present ? '✅' : '❌',
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            present ? 'Uploaded' : 'Missing',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: present
                                  ? AppColors.darkGreen
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// BUTTONS
// =============================================================================

/// Full-width gradient green button with an optional loading spinner.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary button (Back).
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkGreen,
          backgroundColor: AppColors.lighterGreen,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================

/// Formats a date as dd-MM-yyyy (e.g. 15-06-2026).
String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year}';
}

/// Forces input to uppercase as the user types (e.g. GSTIN).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
