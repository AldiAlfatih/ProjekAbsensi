import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- JANGAN LUPA INI
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? user = FirebaseAuth.instance.currentUser;
  bool _isNotifEnabled = true;

  // --- FUNGSI 1: EDIT PROFIL ---
  void _editProfile() {
    final TextEditingController nameController = TextEditingController(text: user?.displayName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ubah Nama Profil"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await user?.updateDisplayName(nameController.text);
                  await user?.reload();
                  setState(() { user = FirebaseAuth.instance.currentUser; });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama berhasil diubah!")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                }
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI 2: GANTI PASSWORD ---
  void _changePassword() {
    final TextEditingController passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ganti Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Masukkan password baru Anda:"),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password Baru", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.length >= 6) {
                try {
                  await user?.updatePassword(passController.text);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password berhasil diganti!")));
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal. Coba Logout lalu Login ulang.")));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password minimal 6 karakter.")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI 3: LOGOUT ---
  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Keluar", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Pengaturan", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KARTU PROFIL
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 30, backgroundColor: Colors.blueAccent.withOpacity(0.2), child: const Icon(Icons.person, size: 35, color: Colors.blueAccent)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? "User Tanpa Nama", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(user?.email ?? "-", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit, color: Colors.blueAccent), tooltip: "Ubah Nama")
                ],
              ),
            ),
            const SizedBox(height: 30),

            // BAGIAN UMUM
            const Text("Akun & Keamanan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            _buildSettingTile(title: "Ganti Password", icon: Icons.lock_outline, onTap: _changePassword),
            _buildSettingTile(
              title: "Notifikasi Aplikasi",
              icon: Icons.notifications_active_outlined,
              isSwitch: true,
              switchValue: _isNotifEnabled,
              onSwitchChanged: (val) {
                setState(() => _isNotifEnabled = val);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Notifikasi ${val ? 'Diaktifkan' : 'Dimatikan'}")));
              },
            ),

            const SizedBox(height: 20),

            // --- BAGIAN IOT REAL-TIME MONITORING ---
            const Text("Perangkat Keras", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('devices').doc('esp32_main').snapshots(),
              builder: (context, snapshot) {
                String statusText = "Memuat...";
                Color statusColor = Colors.grey;
                String lastSeen = "-";
                IconData statusIcon = Icons.router;

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  Timestamp? lastHeartbeat = data['last_heartbeat'];
                  
                  if (lastHeartbeat != null) {
                    DateTime lastTime = lastHeartbeat.toDate();
                    DateTime now = DateTime.now();
                    int diffSeconds = now.difference(lastTime).inSeconds;
                    lastSeen = "${lastTime.hour}:${lastTime.minute.toString().padLeft(2,'0')}";

                    if (diffSeconds < 60) {
                      statusText = "Online (Aktif)";
                      statusColor = Colors.green;
                      statusIcon = Icons.wifi;
                    } else {
                      statusText = "Offline (Terputus)";
                      statusColor = Colors.red;
                      statusIcon = Icons.wifi_off;
                    }
                  }
                } else {
                   statusText = "Menunggu Data Alat...";
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: statusColor.withOpacity(0.3))
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    title: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                    subtitle: Text("Heartbeat terakhir: $lastSeen WIB"),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // TOMBOL LOGOUT (SANGAT PENTING JANGAN HILANG)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Keluar Aplikasi", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: Text("Versi Aplikasi 1.0.0 (Beta Build)", style: TextStyle(color: Colors.grey[400], fontSize: 12))),
          ],
        ),
      ),
    );
  }

  // Widget Tile Helper
  Widget _buildSettingTile({required String title, required IconData icon, String? subtitle, VoidCallback? onTap, bool isSwitch = false, bool switchValue = false, ValueChanged<bool>? onSwitchChanged, Color iconColor = Colors.black54}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: isSwitch ? null : onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)) : null,
        trailing: isSwitch ? Switch(value: switchValue, onChanged: onSwitchChanged, activeColor: Colors.blueAccent) : (onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null),
      ),
    );
  }
}