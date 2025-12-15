import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'attendance_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Fungsi Logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Background agak abu biar modern
      appBar: AppBar(
        title: const Text("IoT Attendance Monitor"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Sapaan
            Text(
              "Halo, Admin!",
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
            const Text(
              "Status Kelas Saat Ini",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 2. StreamBuilder untuk Data Real-time
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Query: Ambil sesi yang statusnya 'OPEN'
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .where('status', isEqualTo: 'OPEN')
                    .snapshots(),
                builder: (context, snapshot) {
                  // A. Sedang memuat data
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // B. Jika ada Error
                  if (snapshot.hasError) {
                    return const Center(child: Text("Terjadi kesalahan memuat data."));
                  }

                  // C. Jika Tidak ada kelas aktif
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  // D. Jika Ada Data Kelas Aktif
                  // Kita ambil dokumen pertama saja (asumsi 1 kelas 1 waktu)
                  var sessionData = snapshot.data!.docs.first;
                  var data = sessionData.data() as Map<String, dynamic>;
                  String docId = sessionData.id;

                  return _buildActiveSessionCard(data, docId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Tampilan Jika Kelas Kosong
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "Tidak ada sesi kelas aktif",
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
          const Text(
            "Tempelkan Kartu RFID pada alat\nuntuk membuka sesi baru.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Widget Kartu Kelas Aktif (Tampilan Utama)
  Widget _buildActiveSessionCard(Map<String, dynamic> data, String docId) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bagian Atas: Status & Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.fiber_manual_record, size: 12, color: Colors.green),
                      SizedBox(width: 5),
                      Text("SESI AKTIF",
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Icon(Icons.wifi_tethering, color: Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 20),

            // Nama Mata Kuliah
            Text(
              data['subject_name'] ?? "Mata Kuliah",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "Ruang: ${data['room'] ?? '-'}",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Divider(height: 30),

            // Counter Jumlah Hadir
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text("Mahasiswa Hadir", style: TextStyle(color: Colors.grey)),
                    Text(
                      "${data['total_present'] ?? 0}",
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 30),

            // Tombol Aksi (Hanya Kosmetik dulu)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendancePage(
                        sessionId: docId, // Mengirim ID Sesi
                        subjectName: data['subject_name'] ?? "Detail Absensi", // Mengirim Nama Matkul
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text("LIHAT DAFTAR HADIR"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}