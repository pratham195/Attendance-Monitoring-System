import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class CreateSubjectPage extends StatefulWidget {
  final String facultyEnrollment;
  final Map<String, dynamic>? existingSubject;

  const CreateSubjectPage({
    super.key,
    required this.facultyEnrollment,
    this.existingSubject,
  });

  @override
  State<CreateSubjectPage> createState() => _CreateSubjectPageState();
}

class _CreateSubjectPageState extends State<CreateSubjectPage> {
  final _formKey          = GlobalKey<FormState>();
  final subjectNameCtrl   = TextEditingController();
  final subjectCodeCtrl   = TextEditingController();
  final semesterCtrl      = TextEditingController();
  final enrollmentAddCtrl = TextEditingController();
  final passwordAddCtrl   = TextEditingController();

  String selectedCourse = 'BCA';
  bool isCreating       = false;
  bool isAddingStudent  = false;
  bool isUploadingFile  = false;
  bool subjectCreated   = false;

  List<Map<String, dynamic>> enrolledStudents = [];
  final List<String> courses = ['iMScIT', 'BCA', 'BScIT'];

  bool get isManageMode => widget.existingSubject != null;

  String get subjectCode => subjectCodeCtrl.text.trim().toUpperCase();
  int    get semester    => int.tryParse(semesterCtrl.text.trim()) ?? 1;

  @override
  void initState() {
    super.initState();
    if (isManageMode) {
      final s              = widget.existingSubject!;
      subjectNameCtrl.text = s['subject_name'] ?? '';
      subjectCodeCtrl.text = s['subject_code'] ?? '';
      semesterCtrl.text    = '${s['semester'] ?? 1}';
      selectedCourse       = s['course'] ?? 'BCA';
      subjectCreated       = true;
      _loadExistingStudents();
    }
  }

  @override
  void dispose() {
    subjectNameCtrl.dispose();
    subjectCodeCtrl.dispose();
    semesterCtrl.dispose();
    enrollmentAddCtrl.dispose();
    passwordAddCtrl.dispose();
    super.dispose();
  }

  // ── Load enrolled students — fetch names from students collection ──────────
  Future<void> _loadExistingStudents() async {
    final snap = await FirebaseFirestore.instance
        .collection('subjects')
        .doc(subjectCode)
        .collection('enrolled_students')
        .get();

    final List<Map<String, dynamic>> list = [];
    for (final doc in snap.docs) {
      final enrollmentNo = doc.id;
      final studentDoc   = await FirebaseFirestore.instance
          .collection('students').doc(enrollmentNo).get();
      list.add({
        'enrollment_no': enrollmentNo,
        'name': studentDoc.exists
            ? (studentDoc.data()?['name'] ?? '') : '',
      });
    }
    setState(() => enrolledStudents = list);
  }

  // ── Create Subject ────────────────────────────────────────────────────────
  Future<void> _createSubject() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isCreating = true);

    try {
      final existing = await FirebaseFirestore.instance
          .collection('subjects').doc(subjectCode).get();

      if (existing.exists) {
        _snack('Subject code already exists!', Colors.red);
        setState(() => isCreating = false);
        return;
      }

      await FirebaseFirestore.instance.collection('subjects').doc(subjectCode).set({
        'subject_name':       subjectNameCtrl.text.trim(),
        'subject_code':       subjectCode,
        'semester':           semester,
        'course':             selectedCourse,
        'faculty_enrollment': widget.facultyEnrollment,
        'created_at':         FieldValue.serverTimestamp(),
      });

      setState(() => subjectCreated = true);
      _snack('Subject created! Now add students.', Colors.green);
    } catch (e) {
      _snack('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => isCreating = false);
    }
  }

  // ── Semester conflict check ───────────────────────────────────────────────
  // Returns the conflicting semester number if the student is already enrolled
  // in a DIFFERENT semester, or null if it's safe to enroll.
  Future<int?> _getConflictingSemester(String enrollment) async {
    final studentDoc = await FirebaseFirestore.instance
        .collection('students')
        .doc(enrollment)
        .get();

    if (!studentDoc.exists) return null; // Brand new student — no conflict

    final existingSemester = studentDoc.data()?['semester'];
    if (existingSemester == null) return null;

    final existingSem = existingSemester is int
        ? existingSemester
        : int.tryParse(existingSemester.toString());

    if (existingSem != null && existingSem != semester) {
      return existingSem; // Conflict found — return their current semester
    }
    return null; // Same semester or no semester set — safe to enroll
  }

  // ── Core: enroll a student ────────────────────────────────────────────────
  // Returns:
  //   'enrolled'         — success
  //   'already_enrolled' — already in this subject
  //   'sem_conflict:X'   — student is locked to semester X
  Future<String> _enrollStudent({
    required String enrollment,
    required String name,
    required String password,
  }) async {
    // 1. Check already in this subject locally
    if (enrolledStudents.any((s) => s['enrollment_no'] == enrollment)) {
      return 'already_enrolled';
    }

    // 2. Check semester conflict
    final conflictSem = await _getConflictingSemester(enrollment);
    if (conflictSem != null) {
      return 'sem_conflict:$conflictSem';
    }

    // 3. Safe to enroll — write to Firestore
    final studentRef = FirebaseFirestore.instance
        .collection('students').doc(enrollment);
    final studentDoc = await studentRef.get();

    if (!studentDoc.exists) {
      // Brand new student — create full doc
      await studentRef.set({
        'enrollment_no':  enrollment,
        'name':           name,
        'password':       password,
        'email':          null,
        'gender':         null,
        'course':         selectedCourse,
        'semester':       semester,
        'role':           'Student',
        'subject_ids':    [subjectCode],
        'created_at':     FieldValue.serverTimestamp(),
      });
    } else {
      // Exists — update password if provided, add subject_id
      final Map<String, dynamic> updates = {
        'subject_ids': FieldValue.arrayUnion([subjectCode]),
        'semester':    semester, // ensure semester is set
      };
      if (password.isNotEmpty) updates['password'] = password;
      if (name.isNotEmpty) {
        final existingName = studentDoc.data()?['name'] ?? '';
        if (existingName.isEmpty) updates['name'] = name;
      }
      await studentRef.update(updates);
    }

    // enrolled_students subcollection — just a link
    await FirebaseFirestore.instance
        .collection('subjects')
        .doc(subjectCode)
        .collection('enrolled_students')
        .doc(enrollment)
        .set({
      'enrollment_no': enrollment,
      'added_at':      FieldValue.serverTimestamp(),
    });

    setState(() {
      enrolledStudents.add({'enrollment_no': enrollment, 'name': name});
    });
    return 'enrolled';
  }

  // ── Upload CSV ─────────────────────────────────────────────────────────────
  // CSV format: enrollment_no,name,password
  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => isUploadingFile = true);

    try {
      final content = utf8.decode(result.files.single.bytes!);
      final lines   = const LineSplitter().convert(content);

      int added = 0, skipped = 0, conflicts = 0;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split(',');
        if (parts.length < 2) { skipped++; continue; }

        final String enrollment = parts[0].trim();
        final String name       = parts[1].trim();
        final String password   = parts.length >= 3 ? parts[2].trim() : '';

        // Skip header row
        if (enrollment.toLowerCase() == 'enrollment_no' ||
            enrollment.toLowerCase() == 'enrollment') continue;

        final result = await _enrollStudent(
          enrollment: enrollment,
          name: name,
          password: password,
        );

        if (result == 'enrolled') {
          added++;
        } else if (result.startsWith('sem_conflict')) {
          conflicts++;
        } else {
          skipped++;
        }
      }

      String msg = '$added student${added == 1 ? '' : 's'} added.';
      if (skipped > 0)    msg += ' $skipped skipped (already enrolled).';
      if (conflicts > 0)  msg += ' $conflicts blocked (semester mismatch).';

      _snack(msg, added > 0 ? Colors.green : Colors.orange);
    } catch (e) {
      _snack('Failed: ${e.toString()}', Colors.red);
    } finally {
      setState(() => isUploadingFile = false);
    }
  }

  // ── Add Manually ──────────────────────────────────────────────────────────
  Future<void> _addStudentManually() async {
    final String enrollment = enrollmentAddCtrl.text.trim();
    final String password   = passwordAddCtrl.text.trim();

    if (enrollment.isEmpty) {
      _snack('Enter enrollment number.', Colors.orange);
      return;
    }

    setState(() => isAddingStudent = true);

    final result = await _enrollStudent(
      enrollment: enrollment,
      name: '',
      password: password,
    );

    if (result == 'already_enrolled') {
      _snack('Student already enrolled in this subject.', Colors.orange);
    } else if (result.startsWith('sem_conflict')) {
      final conflictSem = result.split(':').last;
      // Show a clear dialog so the faculty understands why it was blocked
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.block, color: Colors.red.shade600),
              const SizedBox(width: 10),
              const Text('Enrollment Blocked'),
            ]),
            content: Text(
              '$enrollment is already enrolled in Semester $conflictSem.\n\n'
                  'A student can only belong to one semester. '
                  'They cannot be added to Semester $semester.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.deepPurple)),
              ),
            ],
          ),
        );
      }
    } else {
      enrollmentAddCtrl.clear();
      passwordAddCtrl.clear();
      _snack('Student added!', Colors.green);
    }

    setState(() => isAddingStudent = false);
  }

  // ── Remove ────────────────────────────────────────────────────────────────
  Future<void> _removeStudent(String enrollmentNo) async {
    // Remove link from enrolled_students
    await FirebaseFirestore.instance
        .collection('subjects').doc(subjectCode)
        .collection('enrolled_students').doc(enrollmentNo)
        .delete();

    // Remove subject from student's subject_ids array
    await FirebaseFirestore.instance
        .collection('students').doc(enrollmentNo)
        .update({'subject_ids': FieldValue.arrayRemove([subjectCode])});

    setState(() => enrolledStudents
        .removeWhere((s) => s['enrollment_no'] == enrollmentNo));
    _snack('Student removed.', Colors.orange);
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(isManageMode ? 'Manage Students' : 'Create New Subject',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Subject Details ──
          if (!isManageMode) ...[
            _sectionCard(
              icon: Icons.book_outlined, title: 'Subject Details', color: Colors.deepPurple,
              child: Form(
                key: _formKey,
                child: Column(children: [
                  _formField(controller: subjectNameCtrl, label: 'Subject Name',
                      hint: 'e.g. Data Structures', icon: Icons.title,
                      enabled: !subjectCreated,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  _formField(controller: subjectCodeCtrl, label: 'Subject Code (doc ID)',
                      hint: 'e.g. CS301', icon: Icons.tag, enabled: !subjectCreated,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  _formField(controller: semesterCtrl, label: 'Semester', hint: '1 – 8',
                      icon: Icons.calendar_today, enabled: !subjectCreated,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 8) return 'Enter 1–8';
                        return null;
                      }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCourse,
                    decoration: InputDecoration(
                      labelText: 'Course',
                      prefixIcon: const Icon(Icons.school_outlined, color: Colors.deepPurple),
                      filled: true,
                      fillColor: subjectCreated ? Colors.grey.shade100 : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: subjectCreated ? null : (v) => setState(() => selectedCourse = v!),
                  ),
                  const SizedBox(height: 24),
                  if (!subjectCreated)
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isCreating ? null : _createSubject,
                        icon: isCreating
                            ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(isCreating ? 'Creating...' : 'Create Subject'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  if (subjectCreated)
                    _successBanner('Subject "$subjectCode" created!'),
                ]),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Add Students ──
          _sectionCard(
            icon: Icons.people_outline, title: 'Add Students', color: Colors.teal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text('CSV Format', style: TextStyle(
                        color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'enrollment_no,name,password\nERN1000,Alex Carter,pass123\nERN1001,Jordan Blake,pass456',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Students login with their enrollment number + password.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 10),

              // Semester rule reminder
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Each student can only belong to one semester. '
                          'Students already assigned to a different semester will be blocked.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Upload CSV
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (subjectCreated || isManageMode) && !isUploadingFile
                      ? _uploadFile : null,
                  icon: isUploadingFile
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file, color: Colors.teal),
                  label: Text(isUploadingFile ? 'Uploading...' : 'Upload CSV File',
                      style: const TextStyle(color: Colors.teal)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or add manually',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),
              ),

              // Manual add
              _formField(
                controller: enrollmentAddCtrl,
                label: 'Enrollment Number',
                hint: 'e.g. ERN1001',
                icon: Icons.person_search,
                enabled: subjectCreated || isManageMode,
              ),
              const SizedBox(height: 10),
              _formField(
                controller: passwordAddCtrl,
                label: 'Password for student',
                hint: 'e.g. pass123',
                icon: Icons.lock_outline,
                enabled: subjectCreated || isManageMode,
                obscure: true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (subjectCreated || isManageMode) && !isAddingStudent
                      ? _addStudentManually : null,
                  icon: isAddingStudent
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_outlined),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),

              const SizedBox(height: 16),

              if (enrolledStudents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      '${enrolledStudents.length} student${enrolledStudents.length == 1 ? '' : 's'} enrolled',
                      style: TextStyle(color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),

              if (enrolledStudents.isEmpty && (subjectCreated || isManageMode))
                Center(child: Text('No students added yet.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),

              ...enrolledStudents.map((s) => _StudentTile(
                student: s,
                onRemove: () => _removeStudent(s['enrollment_no'] ?? ''),
              )),
            ]),
          ),

          const SizedBox(height: 30),
        ]),
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
            Icon(icon, color: color, size: 22), const SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: child),
      ]),
    );
  }

  Widget _formField({required TextEditingController controller, required String label,
    required String hint, required IconData icon, bool enabled = true,
    bool obscure = false, TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller, enabled: enabled, keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          filled: true, fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      validator: validator,
    );
  }

  Widget _successBanner(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200)),
    child: Row(children: [
      Icon(Icons.check_circle, color: Colors.green.shade700),
      const SizedBox(width: 10),
      Text(msg, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _StudentTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onRemove;
  const _StudentTile({required this.student, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name       = student['name'] ?? '';
    final enrollment = student['enrollment_no'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade100)),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: Colors.teal.shade100,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isNotEmpty ? name : 'Not registered yet',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                  color: name.isNotEmpty ? Colors.black87 : Colors.grey.shade500)),
          Text(enrollment, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ])),
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: onRemove),
      ]),
    );
  }
}
