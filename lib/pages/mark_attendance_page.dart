import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarkAttendancePage extends StatefulWidget {
  final Map<String, dynamic> subjectData;
  final String facultyEnrollment;

  const MarkAttendancePage({
    super.key,
    required this.subjectData,
    required this.facultyEnrollment,
  });

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Attendance session state ──
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  bool isSubmitting = false;

  // Map<enrollmentNo, isPresent>
  Map<String, bool> attendanceMap = {};
  List<Map<String, dynamic>> students = [];
  bool loadingStudents = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load enrolled students ────────────────────────────────────────────────
  Future<void> _loadStudents() async {
    final snap = await FirebaseFirestore.instance
        .collection('subjects')
        .doc(widget.subjectData['subject_code'])
        .collection('enrolled_students')
        .get();

    final list = snap.docs.map((d) => d.data()).toList();
    setState(() {
      students = list;
      // Default everyone to present
      attendanceMap = {for (var s in list) s['enrollment_no'] as String: true};
      loadingStudents = false;
    });
  }

  // ── Date Picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // ── Time Picker ───────────────────────────────────────────────────────────
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  // ── Parse a time string like "2:30 PM" or "14:30" into total minutes ─────
  int? _parseTimeToMinutes(String timeStr) {
    try {
      timeStr = timeStr.trim();
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');
      // Strip AM/PM and whitespace
      final clean = timeStr.replaceAll(RegExp(r'[APMapm\s]'), '');
      final parts = clean.split(':');
      if (parts.length < 2) return null;

      int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  // ── Check if a session already exists within 30 mins of selected time ────
  // Compares against the date+time chosen in the pickers, NOT the device clock.
  Future<bool> _isDuplicateSession(String dateStr) async {
    final snap = await FirebaseFirestore.instance
        .collection('subjects')
        .doc(widget.subjectData['subject_code'])
        .collection('attendance_sessions')
        .where('date', isEqualTo: dateStr)
        .get();

    if (snap.docs.isEmpty) return false;

    // Convert selected picker time to total minutes
    final selectedMinutes = selectedTime.hour * 60 + selectedTime.minute;

    for (final doc in snap.docs) {
      final existingTimeStr = doc.data()['time'] as String? ?? '';
      final existingMinutes = _parseTimeToMinutes(existingTimeStr);
      if (existingMinutes == null) continue;

      final diff = (selectedMinutes - existingMinutes).abs();
      if (diff < 30) return true; // Within 30-minute buffer → block
    }

    return false;
  }

  // ── Submit Attendance to Firestore ────────────────────────────────────────
  Future<void> _submitAttendance() async {
    if (students.isEmpty) {
      _snack('No students enrolled in this subject.', Colors.orange);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final String dateStr =
          '${selectedDate.year}-${_pad(selectedDate.month)}-${_pad(selectedDate.day)}';
      final String timeStr = selectedTime.format(context);

      // ── 30-minute buffer check ─────────────────────────────────────────────
      // This compares the picked date & time against existing sessions.
      // It does NOT care about the device's real-world clock, so selecting
      // a future time (e.g. 1:00 PM on the picker) while it's 12:45 PM
      // locally is perfectly fine as long as no session exists near 1:00 PM.
      final duplicate = await _isDuplicateSession(dateStr);
      if (duplicate) {
        _snack(
          'A session already exists within 30 minutes of ${timeStr}. '
              'Please select a time at least 30 minutes away.',
          Colors.orange,
        );
        setState(() => isSubmitting = false);
        return;
      }
      // ──────────────────────────────────────────────────────────────────────

      final List<String> presentList = attendanceMap.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      final List<String> absentList = attendanceMap.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      // Save session under subjects/{code}/attendance_sessions/
      await FirebaseFirestore.instance
          .collection('subjects')
          .doc(widget.subjectData['subject_code'])
          .collection('attendance_sessions')
          .add({
        'date':           dateStr,
        'time':           timeStr,
        'subject_code':   widget.subjectData['subject_code'],
        'subject_name':   widget.subjectData['subject_name'],
        'faculty_enrollment': widget.facultyEnrollment,
        'present':        presentList,
        'absent':         absentList,
        'total_students': students.length,
        'created_at':     FieldValue.serverTimestamp(),
      });

      _snack('Attendance saved! ${presentList.length} present, ${absentList.length} absent.', Colors.green);

      // Reset to all present after submit
      setState(() {
        attendanceMap = {for (var s in students) s['enrollment_no'] as String: true};
      });
    } catch (e) {
      _snack('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ─── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final subjectCode = widget.subjectData['subject_code'] ?? '';
    final subjectName = widget.subjectData['subject_name'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subjectName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(subjectCode,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Mark'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarkTab(),
          _buildHistoryTab(subjectCode),
        ],
      ),
    );
  }

  //  TAB 1 — Mark Attendance

  Widget _buildMarkTab() {
    if (loadingStudents) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }

    if (students.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No students enrolled yet.\nAdd students to this subject first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ]),
      );
    }

    final presentCount = attendanceMap.values.where((v) => v).length;
    final absentCount = students.length - presentCount;

    return Column(
      children: [
        // ── Date & Time Picker ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value:
                    '${_pad(selectedDate.day)}/${_pad(selectedDate.month)}/${selectedDate.year}',
                    onTap: _pickDate,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: selectedTime.format(context),
                    onTap: _pickTime,
                    color: Colors.indigo,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Summary chips
              Row(children: [
                _chip('$presentCount Present', Colors.green),
                const SizedBox(width: 8),
                _chip('$absentCount Absent', Colors.red),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.check_box_outlined, size: 16),
                  label: const Text('All Present', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                  onPressed: () => setState(() {
                    for (var k in attendanceMap.keys) {
                      attendanceMap[k] = true;
                    }
                  }),
                ),
              ]),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Student Attendance List ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, i) {
              final student = students[i];
              final enrollment = student['enrollment_no'] as String;
              final isPresent = attendanceMap[enrollment] ?? true;

              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isPresent
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    child: Text(
                      (student['name'] as String? ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPresent ? Colors.green.shade700 : Colors.red.shade700),
                    ),
                  ),
                  title: Text(student['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text(enrollment,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  trailing: GestureDetector(
                    onTap: () => setState(() => attendanceMap[enrollment] = !isPresent),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPresent ? '✓ Present' : '✗ Absent',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Submit Button ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : _submitAttendance,
              icon: isSubmitting
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(isSubmitting ? 'Saving...' : 'Submit Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }


  //  TAB 2 — Attendance History

  Widget _buildHistoryTab(String subjectCode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectCode)
          .collection('attendance_sessions')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No attendance sessions yet.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            ]),
          );
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final presentList = List<String>.from(d['present'] ?? []);
            final total = d['total_students'] ?? 0;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade50,
                  child: const Icon(Icons.event_note, color: Colors.deepPurple),
                ),
                title: Text('${d['date']}  •  ${d['time']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  '${presentList.length}/$total present',
                  style: TextStyle(
                      color: presentList.length == total
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        ...students.map((s) {
                          final enr = s['enrollment_no'] as String;
                          final present = presentList.contains(enr);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Icon(
                                present ? Icons.check_circle : Icons.cancel,
                                color: present ? Colors.green : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('${s['name']} ($enr)',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Text(present ? 'Present' : 'Absent',
                                  style: TextStyle(
                                      color: present ? Colors.green.shade700 : Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Helper Widgets
  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}