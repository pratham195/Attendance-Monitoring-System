import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class FacultyRegistrationPage extends StatefulWidget {
  const FacultyRegistrationPage({super.key});

  @override
  State<FacultyRegistrationPage> createState() => _FacultyRegistrationPageState();
}

class _FacultyRegistrationPageState extends State<FacultyRegistrationPage> {
  final _formKey      = GlobalKey<FormState>();
  final nameCtrl      = TextEditingController();
  final emailCtrl     = TextEditingController();
  final passCtrl      = TextEditingController();
  final facultyIdCtrl = TextEditingController();
  bool isLoading      = false;
  bool obscurePass    = true;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    facultyIdCtrl.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final String facultyId = facultyIdCtrl.text.trim().toUpperCase();

      final existing = await FirebaseFirestore.instance
          .collection('faculty').doc(facultyId).get();

      if (existing.exists) {
        _snack('Faculty ID already registered. Please login.', Colors.red);
        setState(() => isLoading = false);
        return;
      }

      // Faculty doc ID = faculty ID (enrollment number)
      await FirebaseFirestore.instance.collection('faculty').doc(facultyId).set({
        'enrollment_no': facultyId,
        'name':          nameCtrl.text.trim(),
        'email':         emailCtrl.text.trim(),
        'password':      passCtrl.text,
        'role':          'Faculty',
        'created_at':    FieldValue.serverTimestamp(),
      });

      _snack('Registered successfully! You can now login.', Colors.green);
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      _snack('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.pink.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Form(
              key: _formKey,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_4, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('Faculty Registration',
                    style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Create your faculty account',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 30),

                // Faculty ID
                TextFormField(
                  controller: facultyIdCtrl,
                  decoration: _inputDec('Faculty ID (e.g. FAC001)', Icons.badge_outlined),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Full Name
                TextFormField(
                  controller: nameCtrl,
                  decoration: _inputDec('Full Name', Icons.person),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDec('Email', Icons.email),
                  validator: (v) => v!.contains('@') ? null : 'Enter valid email',
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: _inputDec('Password', Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          color: Colors.grey),
                      onPressed: () => setState(() => obscurePass = !obscurePass),
                    ),
                  ),
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.deepPurple)
                        : const Text('Register as Faculty',
                        style: TextStyle(fontSize: 18,
                            color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Already registered? ', style: TextStyle(color: Colors.white70)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginPage())),
                    child: const Text('Login',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(icon, color: Colors.deepPurple),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );
}