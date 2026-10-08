import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
import 'package:salesvista/phase_1_core/app_routes.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController termsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool isGstEnabled = false;
  bool isLogoCompressionEnabled = true; // Compression applies only to logo
  Uint8List? logoBytes;
  Uint8List? signatureBytes;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    final box = await Hive.openBox('companyBox');

    setState(() {
      logoBytes = box.get('logoBytes') as Uint8List?;
      signatureBytes = box.get('signatureBytes') as Uint8List?;
      nameController.text = box.get('companyName', defaultValue: '');
      addressController.text = box.get('companyAddress', defaultValue: '');
      phoneController.text = box.get('companyPhone', defaultValue: '');
      emailController.text = box.get('companyEmail', defaultValue: '');
      gstController.text = box.get('companyGst', defaultValue: '');
      termsController.text = box.get('companyTerms', defaultValue: '');
      isGstEnabled = box.get('isGstEnabled', defaultValue: false);
      isLogoCompressionEnabled = box.get('isLogoCompressionEnabled', defaultValue: true);
    });
  }

  /// Compress Image (only used for logo)
  Future<Uint8List> _compressImage(Uint8List bytes, {int quality = 50}) async {
    if (!isLogoCompressionEnabled) return bytes;
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality, // 0-100
      );
      return result;
    } catch (e) {
      debugPrint("Compression failed: $e");
      return bytes;
    }
  }

  /// PICK LOGO
  Future<void> pickLogo() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        Uint8List bytes = kIsWeb
            ? await picked.readAsBytes()
            : await File(picked.path).readAsBytes();

        bytes = await _compressImage(bytes); // Apply compression only on logo

        final box = await Hive.openBox('companyBox');
        await box.put('logoBytes', bytes);

        setState(() {
          logoBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Logo pick error: $e");
    }
  }

  /// PICK SIGNATURE
  Future<void> pickSignature() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        Uint8List bytes = kIsWeb
            ? await picked.readAsBytes()
            : await File(picked.path).readAsBytes();

        // No compression applied on signature
        final box = await Hive.openBox('companyBox');
        await box.put('signatureBytes', bytes);

        setState(() {
          signatureBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Signature pick error: $e");
    }
  }

  void saveData() async {
    if (_formKey.currentState!.validate()) {
      final box = await Hive.openBox('companyBox');

      final companyName = nameController.text.trim();
      final companyAddress = addressController.text.trim();
      final companyPhone = phoneController.text.trim();
      final companyEmail = emailController.text.trim();
      final companyGst = gstController.text.trim().toUpperCase();

      await box.put('companyName', companyName);
      await box.put('companyAddress', companyAddress);
      await box.put('companyPhone', companyPhone);
      await box.put('companyEmail', companyEmail);
      await box.put('companyGst', companyGst);
      await box.put('companyTerms', termsController.text.trim());
      await box.put('isGstEnabled', isGstEnabled);
      await box.put('isLogoCompressionEnabled', isLogoCompressionEnabled);

      final settingsBox = await Hive.openBox('settingsBox');
      await settingsBox.put('companyName', companyName);
      await settingsBox.put('companyAddress', companyAddress);
      await settingsBox.put('companyPhone', companyPhone);
      await settingsBox.put('companyEmail', companyEmail);
      await settingsBox.put('companyGst', companyGst);
      await settingsBox.put('isGstEnabled', isGstEnabled);

      final stateCode = _stateCodeFromGstin(companyGst);
      if (stateCode != null) {
        await settingsBox.put('companyStateCode', stateCode);
      }

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Company information saved"),
        ),
      );
    }
  }


  String? _stateCodeFromGstin(String gstin) {
    final trimmed = gstin.trim();
    if (trimmed.length >= 2 && RegExp(r'^\d{2}').hasMatch(trimmed)) {
      return trimmed.substring(0, 2);
    }
    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    gstController.dispose();
    termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: "Company Information",
      currentRoute: AppRoutes.company,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// LOGO
              GestureDetector(
                onTap: pickLogo,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      child: logoBytes == null
                          ? const Icon(Icons.camera_alt, size: 30)
                          : ClipOval(
                              child: Image.memory(
                                logoBytes!,
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    const Text("Tap to add Logo"),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// COMPANY NAME
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Company Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              /// ADDRESS
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Address",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              /// PHONE
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              /// EMAIL
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              /// GST TOGGLE
              SwitchListTile(
                title: const Text("Enable GST"),
                value: isGstEnabled,
                onChanged: (value) {
                  setState(() {
                    isGstEnabled = value;
                  });
                },
              ),

              if (isGstEnabled) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: gstController,
                  decoration: const InputDecoration(
                    labelText: "GST Number",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              /// LOGO COMPRESSION TOGGLE
              SwitchListTile(
                title: const Text("Enable Logo Compression for PDF"),
                value: isLogoCompressionEnabled,
                onChanged: (value) {
                  setState(() {
                    isLogoCompressionEnabled = value;
                  });
                },
              ),

              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 20),

              /// SIGNATURE
              GestureDetector(
                onTap: pickSignature,
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: signatureBytes == null
                      ? const Center(
                          child: Text("Tap to add Signature"),
                        )
                      : Image.memory(
                          signatureBytes!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),

              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 20),

              /// TERMS
              TextFormField(
                controller: termsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Terms & Conditions",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              /// SAVE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveData,
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}