import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey   = GlobalKey<FormState>();
  final emailCtrl  = TextEditingController();
  final nameCtrl   = TextEditingController();
  final passCtrl   = TextEditingController();
  final newPassCtrl = TextEditingController();

  String selectedGender = 'Male';
  bool isSaving         = false;
  bool obscurePass      = true;
  bool obscureNewPass   = true;

  String get enrollmentNo => widget.userData['enrollment_no'] ?? '';

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    nameCtrl.text   = widget.userData['name'] ?? '';
    emailCtrl.text  = widget.userData['email'] ?? '';
    selectedGender  = widget.userData['gender'] ?? 'Male';
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    nameCtrl.dispose();
    passCtrl.dispose();
    newPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // If changing password, verify current password
    if (newPassCtrl.text.isNotEmpty) {
      final currentPassword = widget.userData['password'] ?? '';
      if (passCtrl.text != currentPassword) {
        _snack('Current password is incorrect.', Colors.red);
        return;
      }
    }

    setState(() => isSaving = true);

    try {
      final Map<String, dynamic> updates = {
        'name':   nameCtrl.text.trim(),
        'email':  emailCtrl.text.trim(),
        'gender': selectedGender,
      };

      // Only update password if new one is provided
      if (newPassCtrl.text.isNotEmpty) {
        updates['password'] = newPassCtrl.text;
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(enrollmentNo)
          .update(updates);

      // Fetch updated doc to return to previous page
      final updatedDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(enrollmentNo)
          .get();

      _snack('Profile updated successfully!', Colors.green);

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        // Return updated userData back to student page
        Navigator.pop(context, updatedDoc.data());
      }
    } catch (e) {
      _snack('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Profile header
            Center(
              child: Column(children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(
                    (nameCtrl.text.isNotEmpty ? nameCtrl.text[0] : '?').toUpperCase(),
                    style: TextStyle(fontSize: 36, color: Colors.indigo.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Text(enrollmentNo,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Personal Details ──
            _sectionCard(
              icon: Icons.person_outline,
              title: 'Personal Details',
              color: Colors.indigo,
              child: Column(children: [
                _formField(
                  controller: nameCtrl,
                  label: 'Full Name',
                  hint: 'Your full name',
                  icon: Icons.person,
                  validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _formField(
                  controller: emailCtrl,
                  label: 'Email Address',
                  hint: 'your@email.com',
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    if (v!.trim().isEmpty) return null; // email optional
                    if (!v.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Gender', style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
                    Row(children: [
                      Expanded(child: RadioListTile<String>(
                        title: const Text('Male'),
                        value: 'Male',
                        groupValue: selectedGender,
                        activeColor: Colors.indigo,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => selectedGender = v!),
                      )),
                      Expanded(child: RadioListTile<String>(
                        title: const Text('Female'),
                        value: 'Female',
                        groupValue: selectedGender,
                        activeColor: Colors.indigo,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => selectedGender = v!),
                      )),
                    ]),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Change Password ──
            _sectionCard(
              icon: Icons.lock_outline,
              title: 'Change Password (Required)',
              color: Colors.purple,
              child: Column(children: [
                _formField(
                  controller: passCtrl,
                  label: 'Current Password',
                  hint: 'Enter current password',
                  icon: Icons.lock_outline,
                  obscure: obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        color: Colors.grey, size: 20),
                    onPressed: () => setState(() => obscurePass = !obscurePass),
                  ),
                ),
                const SizedBox(height: 16),
                _formField(
                  controller: newPassCtrl,
                  label: 'New Password',
                  hint: 'Min 6 characters',
                  icon: Icons.lock_reset_outlined,
                  obscure: obscureNewPass,
                  suffixIcon: IconButton(
                    icon: Icon(obscureNewPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        color: Colors.grey, size: 20),
                    onPressed: () => setState(() => obscureNewPass = !obscureNewPass),
                  ),
                  validator: (v) {
                    if (v!.isNotEmpty && v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text('Leave blank to keep your current password.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ),

            const SizedBox(height: 30),

            // ── Save Button ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveProfile,
                icon: isSaving
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Saving...' : 'Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  Widget _sectionCard({required IconData icon, required String title,
    required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            Icon(icon, color: color, size: 20), const SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }

  Widget _formField({required TextEditingController controller, required String label,
    required String hint, required IconData icon, bool obscure = false,
    Widget? suffixIcon, TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller, obscureText: obscure, keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, color: Colors.indigo),
        suffixIcon: suffixIcon,
        filled: true, fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2)),
      ),
      validator: validator,
    );
  }
}