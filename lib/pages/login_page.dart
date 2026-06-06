import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'admin_page.dart';
import 'faculty_registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final enrollmentCtrl = TextEditingController();
  final passCtrl       = TextEditingController();
  bool isLoading       = false;
  bool obscurePass     = true;
  String message       = '';

  @override
  void dispose() {
    enrollmentCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final String enrollment = enrollmentCtrl.text.trim();
    final String password   = passCtrl.text;

    if (enrollment.isEmpty || password.isEmpty) {
      setState(() => message = 'Please enter enrollment number and password.');
      return;
    }

    setState(() { isLoading = true; message = ''; });

    try {
      // ── 1. Static Admin check ─────────────────────────────────────────────
      if (enrollment == 'admin@gmail.com' && password == 'Admin@123') {
        _navigate(const AdminPage());
        return;
      }

      // ── 2. Check students collection by enrollment_no (doc ID) ────────────
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(enrollment)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        if (data['password'] == password) {
          _navigate(DashboardPage(userData: data, role: 'Student'));
          return;
        } else {
          setState(() => message = 'Incorrect password.');
          return;
        }
      }

      // ── 3. Check faculty collection by enrollment_no (doc ID) ─────────────
      final facultyDoc = await FirebaseFirestore.instance
          .collection('faculty')
          .doc(enrollment)
          .get();

      if (facultyDoc.exists) {
        final data = facultyDoc.data()!;
        if (data['password'] == password) {
          _navigate(DashboardPage(userData: data, role: 'Faculty'));
          return;
        } else {
          setState(() => message = 'Incorrect password.');
          return;
        }
      }

      setState(() => message = 'Enrollment number not found.');
    } catch (e) {
      setState(() => message = 'Error: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _navigate(Widget page) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.purple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text('Attendance App',
                    style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Sign in with your enrollment number',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 40),

                // Enrollment Number
                TextField(
                  controller: enrollmentCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Enrollment Number (e.g. ERN1000)',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.purple),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  onSubmitted: (_) => login(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.purple),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          color: Colors.grey),
                      onPressed: () => setState(() => obscurePass = !obscurePass),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 28),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      login();
                    },
                    child: Text("Login"),
                  ),
                ),
                const SizedBox(height: 20),

                // Error message
                if (message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(message,
                          style: const TextStyle(color: Colors.white, fontSize: 14))),
                    ]),
                  ),

                const SizedBox(height: 28),

                // Faculty register link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Are you faculty? ',
                      style: TextStyle(color: Colors.white70)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const FacultyRegistrationPage())),
                    child: const Text('Register here',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}