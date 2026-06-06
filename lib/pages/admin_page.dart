import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.amber,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Administrator',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.dashboard_outlined,
              color: Color(0xFF1a1a2e),
            ),
            title: const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(indent: 16, endIndent: 16),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined), text: 'Students'),
            Tab(icon: Icon(Icons.person_4_outlined), text: 'Faculty'),
            Tab(icon: Icon(Icons.book_outlined), text: 'Subjects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StudentsTab(),
          FacultyTab(),
          SubjectsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STUDENTS TAB
// submit-only search + delete only for students
// ══════════════════════════════════════════════════════════════════════════════

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final TextEditingController _searchController = TextEditingController();
  String submittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Stream<QuerySnapshot> _baseStream() {
    return FirebaseFirestore.instance
        .collection('students')
        .orderBy('name')
        .limit(200)
        .snapshots();
  }

  Future<void> _deleteStudent(String docId, String studentName) async {
    final confirmed = await _confirmDeleteStudent(
      context,
      studentName: studentName,
    );

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(docId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$studentName deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete student: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText: 'Search by ENR, Name, or Sem',
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
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _baseStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.school_outlined,
                  message: 'No students registered yet.',
                );
              }

              final allDocs = snap.data!.docs;

              final filtered = submittedQuery.isEmpty
                  ? allDocs
                  : allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final enr =
                (data['enrollment_no'] ?? '').toString().toLowerCase();
                final name =
                (data['name'] ?? '').toString().toLowerCase();
                final sem =
                (data['semester'] ?? '').toString().toLowerCase();

                return enr.contains(submittedQuery) ||
                    name.contains(submittedQuery) ||
                    sem.contains(submittedQuery);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off,
                  message: 'No students found for "$submittedQuery".',
                );
              }

              return Column(
                children: [
                  _CountBanner(
                    count: filtered.length,
                    label: submittedQuery.isEmpty
                        ? 'Total Students'
                        : 'Search Results',
                    color: Colors.indigo,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final studentName =
                        (d['name'] ?? 'Unknown').toString();

                        return _InfoCard(
                          avatar: _avatarLetter(d['name']),
                          avatarColor: Colors.indigo,
                          title: d['name'] ?? 'Unknown',
                          subtitle: d['enrollment_no'] ?? '',
                          chips: [
                            if (d['course'] != null)
                              _Chip(d['course'], Colors.indigo),
                            if (d['semester'] != null)
                              _Chip('SEM ${d['semester']}', Colors.blue),
                            if (d['gender'] != null)
                              _Chip(d['gender'], Colors.purple),
                          ],
                          trailing: d['email'] ?? '',
                          action: IconButton(
                            tooltip: 'Delete student',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _deleteStudent(doc.id, studentName),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FACULTY TAB
// submit-only search only, no delete
// ══════════════════════════════════════════════════════════════════════════════

class FacultyTab extends StatefulWidget {
  const FacultyTab({super.key});

  @override
  State<FacultyTab> createState() => _FacultyTabState();
}

class _FacultyTabState extends State<FacultyTab> {
  final TextEditingController _searchController = TextEditingController();
  String submittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Stream<QuerySnapshot> _baseStream() {
    return FirebaseFirestore.instance
        .collection('faculty')
        .orderBy('name')
        .limit(200)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText: 'Search faculty by ENR or Name',
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
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _baseStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.person_4_outlined,
                  message: 'No faculty registered yet.',
                );
              }

              final allDocs = snap.data!.docs;

              final filtered = submittedQuery.isEmpty
                  ? allDocs
                  : allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final enr =
                (data['enrollment_no'] ?? '').toString().toLowerCase();
                final name =
                (data['name'] ?? '').toString().toLowerCase();

                return enr.contains(submittedQuery) ||
                    name.contains(submittedQuery);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off,
                  message: 'No faculty found for "$submittedQuery".',
                );
              }

              return Column(
                children: [
                  _CountBanner(
                    count: filtered.length,
                    label: submittedQuery.isEmpty
                        ? 'Total Faculty'
                        : 'Search Results',
                    color: Colors.deepPurple,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final d =
                        filtered[i].data() as Map<String, dynamic>;

                        return _InfoCard(
                          avatar: _avatarLetter(d['name']),
                          avatarColor: Colors.deepPurple,
                          title: d['name'] ?? 'Unknown',
                          subtitle: d['enrollment_no'] ?? '',
                          chips: const [
                            _Chip('Faculty', Colors.deepPurple),
                          ],
                          trailing: d['email'] ?? '',
                          extraInfo: d['subjects'] != null &&
                              d['subjects'].toString().isNotEmpty
                              ? 'Subjects: ${d['subjects']}'
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUBJECTS TAB
// submit-only search only, no delete
// ══════════════════════════════════════════════════════════════════════════════

class SubjectsTab extends StatefulWidget {
  const SubjectsTab({super.key});

  @override
  State<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<SubjectsTab> {
  final TextEditingController _searchController = TextEditingController();
  String submittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Stream<QuerySnapshot> _baseStream() {
    return FirebaseFirestore.instance
        .collection('subjects')
        .orderBy('subject_name')
        .limit(200)
        .snapshots();
  }

  Color _courseColor(String? course) {
    switch (course) {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText: 'Search subjects by name, code, or sem',
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
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _baseStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.book_outlined,
                  message: 'No subjects created yet.',
                );
              }

              final allDocs = snap.data!.docs;

              final filtered = submittedQuery.isEmpty
                  ? allDocs
                  : allDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final subjectName =
                (d['subject_name'] ?? '').toString().toLowerCase();
                final subjectCode =
                (d['subject_code'] ?? doc.id).toString().toLowerCase();
                final sem =
                (d['semester'] ?? '').toString().toLowerCase();

                return subjectName.contains(submittedQuery) ||
                    subjectCode.contains(submittedQuery) ||
                    sem.contains(submittedQuery);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off,
                  message: 'No subjects found for "$submittedQuery".',
                );
              }

              return Column(
                children: [
                  _CountBanner(
                    count: filtered.length,
                    label: submittedQuery.isEmpty
                        ? 'Total Subjects'
                        : 'Search Results',
                    color: Colors.teal,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final String subjectCode =
                            d['subject_code'] ?? doc.id;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor:
                              _courseColor(d['course']).withOpacity(0.15),
                              child: Text(
                                (d['subject_name'] ?? 'S')[0].toUpperCase(),
                                style: TextStyle(
                                  color: _courseColor(d['course']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              d['subject_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Code: $subjectCode  •  SEM ${d['semester']}  •  ${d['course'] ?? ''}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('subjects')
                                    .doc(subjectCode)
                                    .collection('enrolled_students')
                                    .snapshots(),
                                builder: (context, studentSnap) {
                                  final students = studentSnap.data?.docs ?? [];
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.people_outline,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${students.length} student${students.length == 1 ? '' : 's'} enrolled',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (students.isEmpty)
                                          Text(
                                            'No students added yet.',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          )
                                        else
                                          ...students.map((s) {
                                            final sd =
                                            s.data() as Map<String, dynamic>;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor:
                                                    Colors.teal.shade50,
                                                    child: Text(
                                                      (sd['name'] ?? '?')[0]
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .teal.shade700,
                                                        fontWeight:
                                                        FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    sd['name'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '(${sd['enrollment_no'] ?? s.id})',
                                                    style: TextStyle(
                                                      color: Colors
                                                          .grey.shade500,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        const SizedBox(height: 12),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('subjects')
                                              .doc(subjectCode)
                                              .collection(
                                              'attendance_sessions')
                                              .snapshots(),
                                          builder: (context, attSnap) {
                                            final sessions =
                                                attSnap.data?.docs.length ?? 0;
                                            return Row(
                                              children: [
                                                Icon(
                                                  Icons.fact_check_outlined,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$sessions attendance session${sessions == 1 ? '' : 's'} recorded',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Faculty ID: ${d['faculty_enrollment'] ?? 'N/A'}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _CountBanner extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _CountBanner({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String avatar;
  final Color avatarColor;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final String trailing;
  final String? extraInfo;
  final Widget? action;

  const _InfoCard({
    required this.avatar,
    required this.avatarColor,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.trailing,
    this.extraInfo,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: avatarColor.withOpacity(0.15),
              child: Text(
                avatar,
                style: TextStyle(
                  color: avatarColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  if (trailing.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      trailing,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (extraInfo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      extraInfo!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: chips,
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDeleteStudent(
    BuildContext context, {
      required String studentName,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Student'),
      content: Text('Are you sure you want to delete $studentName?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return result ?? false;
}

String _avatarLetter(String? name) {
  if (name == null || name.isEmpty) return '?';
  return name[0].toUpperCase();
}