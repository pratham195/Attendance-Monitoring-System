import 'package:flutter/material.dart';
import '../pages/login_page.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String role;

  const AppDrawer({super.key, required this.userData, required this.role});

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'Unknown';
    final String email = userData['email'] ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.pink.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                role == 'Student' ? Icons.school : Icons.person_4,
                color: Colors.purple,
                size: 36,
              ),
            ),
            accountName: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(email),
            otherAccountsPictures: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  role,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),

          // ── Dashboard ──
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.purple),
            title: const Text("Dashboard"),
            onTap: () => Navigator.pop(context),
          ),

          const Divider(),

          // ── Logout ──
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}