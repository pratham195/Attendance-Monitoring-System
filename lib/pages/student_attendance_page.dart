import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class StudentAttendancePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const StudentAttendancePage({super.key, required this.userData});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  late Map<String, dynamic> userData;

  final TextEditingController _searchController = TextEditingController();
  String submittedQuery = '';

  String get enrollmentNo => userData['enrollment_no'] ?? '';
  String get studentName => userData['name'] ?? 'Student';
  String get studentEmail => userData['email'] ?? '';

  List<Map<String, dynamic>> enrolledSubjects = [];
  bool loadingSubjects = true;

  @override
  void initState() {
    super.initState();
    userData = Map<String, dynamic>.from(widget.userData);
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    setState(() => loadingSubjects = true);

    try {
      final freshDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(enrollmentNo)
          .get();

      if (!freshDoc.exists) {
        setState(() => loadingSubjects = false);
        return;
      }

      setState(() => userData = freshDoc.data()!);

      final List<dynamic> subjectIds =
          (freshDoc.data()?['subject_ids'] as List<dynamic>?) ?? [];

      if (subjectIds.isEmpty) {
        setState(() {
          enrolledSubjects = [];
          loadingSubjects = false;
        });
        return;
      }

      final List<Map<String, dynamic>> subjects = [];
      for (final code in subjectIds) {
        final subjectDoc = await FirebaseFirestore.instance
            .collection('subjects')
            .doc(code.toString())
            .get();

        if (subjectDoc.exists) {
          subjects.add(subjectDoc.data()!);
        }
      }

      setState(() {
        enrolledSubjects = subjects;
        loadingSubjects = false;
      });
    } catch (e) {
      setState(() => loadingSubjects = false);
    }
  }

  void _runSearch() {
    setState(() {
      submittedQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      submittedQuery = '';
    });
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    if (submittedQuery.isEmpty) return enrolledSubjects;

    return enrolledSubjects.where((subject) {
      final subjectId = (subject['subject_code'] ?? '').toString().toLowerCase();
      final subjectName = (subject['subject_name'] ?? '').toString().toLowerCase();

      return subjectId.contains(submittedQuery) ||
          subjectName.contains(submittedQuery);
    }).toList();
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.school, size: 36, color: Colors.indigo),
                ),
                const SizedBox(height: 12),
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (studentEmail.isNotEmpty)
                  Text(
                    studentEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                Text(
                  enrollmentNo,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Student',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: Colors.indigo),
            title: const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.indigo),
            title: const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              studentEmail.isEmpty ? 'Complete your profile' : 'Update your details',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            trailing: studentEmail.isEmpty
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Incomplete',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 10,
                ),
              ),
            )
                : null,
            onTap: () async {
              Navigator.pop(context);
              final updated = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(userData: userData),
                ),
              );

              if (updated != null) {
                setState(() => userData = updated);
                _loadSubjects();
              }
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSubjects = _filteredSubjects;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text(
          'My Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loadingSubjects
          ? const Center(
        child: CircularProgressIndicator(color: Colors.indigo),
      )
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: const BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${studentName.split(' ').first} 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enrollment: $enrollmentNo',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Search by subject ID or subject name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: submittedQuery.isEmpty
                    ? IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _runSearch,
                )
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Subject-wise Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.indigo),
                  onPressed: _loadSubjects,
                ),
              ],
            ),
          ),

          Expanded(
            child: enrolledSubjects.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Not enrolled in any subjects yet.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Contact your faculty to be added.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : filteredSubjects.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No subjects found.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: filteredSubjects.length,
              itemBuilder: (context, i) => _SubjectAttendanceCard(
                subjectData: filteredSubjects[i],
                enrollmentNo: enrollmentNo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectAttendanceCard extends StatelessWidget {
  final Map<String, dynamic> subjectData;
  final String enrollmentNo;

  const _SubjectAttendanceCard({
    required this.subjectData,
    required this.enrollmentNo,
  });

  Color get _courseColor {
    switch (subjectData['course']) {
      case 'iMScIT':
        return Colors.deepPurple;
      case 'BCA':
        return Colors.teal;
      case 'BScIT':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String subjectCode = subjectData['subject_code'] ?? '';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subjects')
            .doc(subjectCode)
            .collection('attendance_sessions')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final sessions = snap.data?.docs ?? [];
          final int total = sessions.length;
          int presentCount = 0;

          for (final doc in sessions) {
            final data = doc.data() as Map<String, dynamic>;
            final presentList = List<String>.from(data['present'] ?? []);
            if (presentList.contains(enrollmentNo)) {
              presentCount++;
            }
          }

          final double pct = total == 0 ? 0 : (presentCount / total) * 100;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _courseColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.book, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subjectData['subject_name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$subjectCode  •  SEM ${subjectData['semester']}  •  ${subjectData['course']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statBox('Present', '$presentCount', Colors.green),
                        _statBox('Absent', '${total - presentCount}', Colors.red),
                        _statBox('Total', '$total', Colors.blue),
                        _statBox(
                          'Score',
                          '${pct.toStringAsFixed(0)}%',
                          pct >= 75 ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : pct / 100,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct >= 75 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    if (pct < 75 && total > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Attendance below 75%',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Session History',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (sessions.isEmpty)
                      Text(
                        'No sessions recorded yet.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      )
                    else
                      ...sessions.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final presentList = List<String>.from(data['present'] ?? []);
                        final isPresent = presentList.contains(enrollmentNo);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPresent
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['date'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      data['time'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: isPresent
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}