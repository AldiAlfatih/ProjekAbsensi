import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'simulation_page.dart';
import 'manage_schedule_page.dart'; 

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
                  
                  await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                    'name': nameController.text,
                  });

                  setState(() => user = FirebaseAuth.instance.currentUser); 
                  
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
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Password Baru", border: OutlineInputBorder()),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal. Silakan Logout lalu Login ulang.")));
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

  // --- FUNGSI 3: SUPER INJECTOR (GENERATE DATA DUMMY CERDAS) ---
  Future<void> _injectDummyHistory(BuildContext context, String role) async {
    var collection = FirebaseFirestore.instance.collection('attendance_history');
    DateTime now = DateTime.now();
    DateTime yesterday = now.subtract(const Duration(days: 1));

    if (role == 'admin') {
      // === SKENARIO ADMIN: BUATKAN DATA UNTUK BIMO & WIDYA ===
      
      // 1. Data untuk Pak Bimo (Absensi Bagus)
      await collection.add({
        'subject_name': 'Pemrograman Mobile (Kelas Bimo)',
        'room': '205',
        'date': Timestamp.fromDate(now),
        'lecturer_email': 'bimo@gmail.com', // <--- Set ke Bimo
        'summary': {'hadir': 20, 'telat': 2, 'alpa': 0},
        'details': [
           {'nim': '601', 'name': 'Aldi', 'status': 'HADIR', 'scan_time': '08:00', 'late_duration': ''},
           {'nim': '602', 'name': 'Budi', 'status': 'TERLAMBAT', 'scan_time': '08:20', 'late_duration': '20 Menit'},
        ]
      });

      // 2. Data untuk Bu Widya (Absensi Kurang Bagus)
      await collection.add({
        'subject_name': 'Data Science (Kelas Widya)',
        'room': 'LAB-DATA',
        'date': Timestamp.fromDate(yesterday),
        'lecturer_email': 'widya@gmail.com', // <--- Set ke Widya
        'summary': {'hadir': 15, 'telat': 5, 'alpa': 3},
        'details': [
           {'nim': '701', 'name': 'Citra', 'status': 'HADIR', 'scan_time': '10:00', 'late_duration': ''},
           {'nim': '702', 'name': 'Dedi', 'status': 'ALPA', 'scan_time': '-', 'late_duration': ''},
        ]
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Sukses! Data Dummy untuk Pak Bimo & Bu Widya telah dibuat."),
          backgroundColor: Colors.green,
        ));
      }

    } else {
      // === SKENARIO DOSEN BIASA: BUAT UNTUK DIRI SENDIRI ===
      await collection.add({
        'subject_name': 'Kelas Simulasi Saya',
        'room': 'TEST-ROOM',
        'date': Timestamp.now(),
        'lecturer_email': user?.email, // <--- Set ke Diri Sendiri
        'summary': {'hadir': 10, 'telat': 0, 'alpa': 0},
        'details': [
           {'nim': 'TES-01', 'name': 'Mahasiswa Test', 'status': 'HADIR', 'scan_time': '08:00', 'late_duration': ''},
        ]
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Data Dummy milik Anda berhasil dibuat!"),
          backgroundColor: Colors.blue,
        ));
      }
    }
  }

  // --- FUNGSI 4: LOGOUT ---
  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Keluar", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Pengaturan & Akun"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- KARTU PROFIL ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  CircleAvatar(radius: 30, backgroundColor: Colors.blueAccent.withOpacity(0.2), child: const Icon(Icons.person, size: 35, color: Colors.blueAccent)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? "User", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(user?.email ?? "-", style: TextStyle(color: Colors.grey[600])),
                        
                        // STREAM UNTUK CEK ROLE
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var userData = snapshot.data!.data() as Map<String, dynamic>;
                              String role = (userData['role'] ?? 'dosen').toString().toLowerCase();
                              
                              return Container(
                                margin: const EdgeInsets.only(top: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: role == 'admin' ? Colors.red : Colors.green, 
                                  borderRadius: BorderRadius.circular(5)
                                ),
                                child: Text(
                                  role.toUpperCase(), 
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        )
                      ],
                    ),
                  ),
                  IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit, color: Colors.blueAccent)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- MENU (STREAM BUILDER UNTUK AKSES ADMIN) ---
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                // Default Role = Dosen jika loading/null
                String role = 'dosen';
                if (snapshot.hasData && snapshot.data!.exists) {
                   var userData = snapshot.data!.data() as Map<String, dynamic>;
                   role = (userData['role'] ?? 'dosen').toString().toLowerCase();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MENU KHUSUS ADMIN
                    if (role == 'admin') ...[
                      const Text("Menu Admin", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 10),
                      
                      _buildSettingTile(
                        title: "Kelola Jadwal Kuliah",
                        subtitle: "Tambah/Edit/Hapus Jadwal",
                        icon: Icons.edit_calendar,
                        iconColor: Colors.red,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageSchedulePage())),
                      ),
                      
                      _buildSettingTile(
                        title: "IoT Simulator",
                        subtitle: "Testing alat tanpa hardware",
                        icon: Icons.bug_report,
                        iconColor: Colors.orange,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SimulationPage())),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // MENU UMUM
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
                    const Text("Developer Tools", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    // TOMBOL INJECT DUMMY (Logic sudah diupdate di atas)
                    _buildSettingTile(
                      title: role == 'admin' ? "Generate Dummy (All Dosen)" : "Generate Dummy Saya",
                      subtitle: "Buat data palsu untuk tes fitur Riwayat",
                      icon: Icons.smart_toy,
                      iconColor: Colors.purple,
                      onTap: () => _injectDummyHistory(context, role), // Kirim role ke fungsi
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50], 
                  foregroundColor: Colors.red, 
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: const Text("Keluar Aplikasi", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            Center(child: Text("Versi 1.0.0 Release", style: TextStyle(color: Colors.grey[400], fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required IconData icon,
    String? subtitle,
    VoidCallback? onTap,
    bool isSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
    Color iconColor = Colors.black54,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: isSwitch ? null : onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12)) : null,
        trailing: isSwitch
            ? Switch(value: switchValue, onChanged: onSwitchChanged, activeThumbColor: Colors.blueAccent)
            : (onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null),
      ),
    );
  }
}