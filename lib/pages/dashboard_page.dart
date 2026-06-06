import 'package:flutter/material.dart';
import 'faculty_home_page.dart';
import 'student_attendance_page.dart';

class DashboardPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String role;

  const DashboardPage({super.key, required this.userData, required this.role});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (role == 'Faculty') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => FacultyHomePage(userData: userData)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => StudentAttendancePage(userData: userData)));
      }
    });

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Colors.deepPurple),
          const SizedBox(height: 20),
          Text('Welcome, ${userData['name'] ?? ''}',
              style: const TextStyle(fontSize: 18, color: Colors.deepPurple,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Loading your $role portal...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      ),
    );
  }
}