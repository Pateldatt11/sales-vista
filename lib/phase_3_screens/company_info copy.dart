// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:hive/hive.dart';
// import 'package:salesvista/phase_4_widgets/base_scaffold.dart';
// import 'package:salesvista/phase_1_core/app_routes.dart';

// class CompanyInfoScreen extends StatefulWidget {
//   const CompanyInfoScreen({super.key});

//   @override
//   State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
// }

// class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
//   final _formKey = GlobalKey<FormState>();

//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController addressController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController gstController = TextEditingController();
//   final TextEditingController termsController = TextEditingController();

//   final ImagePicker _picker = ImagePicker();

//   bool isGstEnabled = false;
//   Uint8List? logoBytes;
//   Uint8List? signatureBytes;

//   @override
//   void initState() {
//     super.initState();
//     _loadCompanyData();
//   }

//   Future<void> _loadCompanyData() async {
//     final box = await Hive.openBox('companyBox');

//     setState(() {
//       logoBytes = box.get('logoBytes') as Uint8List?;
//       signatureBytes = box.get('signatureBytes') as Uint8List?;
//       nameController.text = box.get('companyName', defaultValue: '');
//       addressController.text = box.get('companyAddress', defaultValue: '');
//       phoneController.text = box.get('companyPhone', defaultValue: '');
//       emailController.text = box.get('companyEmail', defaultValue: '');
//       gstController.text = box.get('companyGst', defaultValue: '');
//       termsController.text = box.get('companyTerms', defaultValue: '');
//       isGstEnabled = box.get('isGstEnabled', defaultValue: false);
//     });
//   }

//   /// PICK LOGO
//   Future<void> pickLogo() async {
//     try {
//       final picked = await _picker.pickImage(source: ImageSource.gallery);
//       if (picked != null) {
//         Uint8List bytes = kIsWeb
//             ? await picked.readAsBytes()
//             : await File(picked.path).readAsBytes();

//         final box = await Hive.openBox('companyBox');
//         await box.put('logoBytes', bytes);

//         setState(() {
//           logoBytes = bytes;
//         });
//       }
//     } catch (e) {
//       debugPrint("Logo pick error: $e");
//     }
//   }

//   /// PICK SIGNATURE
//   Future<void> pickSignature() async {
//     try {
//       final picked = await _picker.pickImage(source: ImageSource.gallery);
//       if (picked != null) {
//         Uint8List bytes = kIsWeb
//             ? await picked.readAsBytes()
//             : await File(picked.path).readAsBytes();

//         final box = await Hive.openBox('companyBox');
//         await box.put('signatureBytes', bytes);

//         setState(() {
//           signatureBytes = bytes;
//         });
//       }
//     } catch (e) {
//       debugPrint("Signature pick error: $e");
//     }
//   }

//   void saveData() async {
//     if (_formKey.currentState!.validate()) {
//       final box = await Hive.openBox('companyBox');

//       await box.put('companyName', nameController.text.trim());
//       await box.put('companyAddress', addressController.text.trim());
//       await box.put('companyPhone', phoneController.text.trim());
//       await box.put('companyEmail', emailController.text.trim());
//       await box.put('companyGst', gstController.text.trim());
//       await box.put('companyTerms', termsController.text.trim());
//       await box.put('isGstEnabled', isGstEnabled);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Company information saved"),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     addressController.dispose();
//     phoneController.dispose();
//     emailController.dispose();
//     gstController.dispose();
//     termsController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BaseScaffold(
//       title: "Company Information",
//       currentRoute: AppRoutes.company,
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               /// LOGO
//               GestureDetector(
//                 onTap: pickLogo,
//                 child: Column(
//                   children: [
//                     CircleAvatar(
//                       radius: 50,
//                       backgroundColor: Colors.grey.shade200,
//                       child: logoBytes == null
//                           ? const Icon(Icons.camera_alt, size: 30)
//                           : ClipOval(
//                               child: Image.memory(
//                                 logoBytes!,
//                                 height: 100,
//                                 width: 100,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                     ),
//                     const SizedBox(height: 8),
//                     const Text("Tap to add Logo"),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 25),

//               /// COMPANY NAME
//               TextFormField(
//                 controller: nameController,
//                 decoration: const InputDecoration(
//                   labelText: "Company Name",
//                   border: OutlineInputBorder(),
//                 ),
//               ),

//               const SizedBox(height: 15),

//               /// ADDRESS
//               TextFormField(
//                 controller: addressController,
//                 maxLines: 2,
//                 decoration: const InputDecoration(
//                   labelText: "Address",
//                   border: OutlineInputBorder(),
//                 ),
//               ),

//               const SizedBox(height: 15),

//               /// PHONE
//               TextFormField(
//                 controller: phoneController,
//                 keyboardType: TextInputType.phone,
//                 decoration: const InputDecoration(
//                   labelText: "Phone",
//                   border: OutlineInputBorder(),
//                 ),
//               ),

//               const SizedBox(height: 15),

//               /// EMAIL
//               TextFormField(
//                 controller: emailController,
//                 keyboardType: TextInputType.emailAddress,
//                 decoration: const InputDecoration(
//                   labelText: "Email",
//                   border: OutlineInputBorder(),
//                 ),
//               ),

//               const SizedBox(height: 20),

//               /// GST TOGGLE
//               SwitchListTile(
//                 title: const Text("Enable GST"),
//                 value: isGstEnabled,
//                 onChanged: (value) {
//                   setState(() {
//                     isGstEnabled = value;
//                   });
//                 },
//               ),

//               if (isGstEnabled) ...[
//                 const SizedBox(height: 10),
//                 TextFormField(
//                   controller: gstController,
//                   decoration: const InputDecoration(
//                     labelText: "GST Number",
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               ],

//               const SizedBox(height: 25),
//               const Divider(),
//               const SizedBox(height: 20),

//               /// SIGNATURE
//               GestureDetector(
//                 onTap: pickSignature,
//                 child: Container(
//                   height: 100,
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: signatureBytes == null
//                       ? const Center(
//                           child: Text("Tap to add Signature"),
//                         )
//                       : Image.memory(
//                           signatureBytes!,
//                           fit: BoxFit.contain,
//                         ),
//                 ),
//               ),

//               const SizedBox(height: 25),
//               const Divider(),
//               const SizedBox(height: 20),

//               /// TERMS
//               TextFormField(
//                 controller: termsController,
//                 maxLines: 3,
//                 decoration: const InputDecoration(
//                   labelText: "Terms & Conditions",
//                   border: OutlineInputBorder(),
//                 ),
//               ),

//               const SizedBox(height: 30),

//               /// SAVE BUTTON
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: saveData,
//                   child: const Text("Save"),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }