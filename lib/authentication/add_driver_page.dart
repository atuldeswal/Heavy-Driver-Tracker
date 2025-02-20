import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController ownerPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    ownerPasswordController.dispose();
    super.dispose();
  }

  Future<void> registerDriver() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (ownerPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Owner password is required")));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ Get the current owner user
      User? ownerUser = _auth.currentUser;
      if (ownerUser == null) throw Exception("No authenticated user found");

      // 2️⃣ Re-authenticate the owner
      AuthCredential ownerCredential = EmailAuthProvider.credential(
        email: ownerUser.email!,
        password: ownerPasswordController.text.trim(),
      );
      await ownerUser.reauthenticateWithCredential(ownerCredential);

      // 3️⃣ Fetch owner's companyId from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(ownerUser.uid).get();
      if (!userDoc.exists) throw Exception("Owner data not found");

      String companyId = userDoc.get('companyId');

      // 4️⃣ Create the new driver account
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      User? newDriver = userCredential.user;
      if (newDriver == null) throw Exception("Driver account creation failed");

      // 5️⃣ Store driver details in Firestore
      await _firestore.collection('users').doc(newDriver.uid).set({
        'uid': newDriver.uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phoneNumber': phoneController.text.trim(),
        'companyId': companyId, // Link to the correct company
        'accountType': 'driver',
        'createdAt': Timestamp.now(),
        'isOnJourney': false,
        'currentJourneyId': null,
      });

      // 6️⃣ Re-authenticate back as the owner
      await _auth.signInWithEmailAndPassword(
        email: ownerUser.email!,
        password: ownerPasswordController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver added successfully!")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        title: Text(
          "Add Driver",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(top: 10, bottom: 30),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "New Driver Registration",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Form Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Driver Information",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _inputField("Full Name", nameController, Icons.person),
                    _inputField("Phone Number", phoneController, Icons.phone, isNumber: true),
                    _inputField("Email", emailController, Icons.email),

                    const SizedBox(height: 20),
                    Text(
                      "Security",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _inputField(
                      "Password",
                      passwordController,
                      Icons.lock,
                      isPassword: true,
                    ),
                    _inputField(
                      "Confirm Password",
                      confirmPasswordController,
                      Icons.lock_outline,
                      isPassword: true,
                    ),
                    _inputField(
                      "Owner Password (for verification)",
                      ownerPasswordController,
                      Icons.admin_panel_settings,
                      isPassword: true,
                    ),
                    const SizedBox(height: 30),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : registerDriver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.person_add, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Register Driver",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
    bool isNumber = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF6C63FF),
            size: 22,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        validator: (value) => value!.isEmpty ? "Required" : null,
      ),
    );
  }
}
