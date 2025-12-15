import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'attendance_page.dart';
import 'settings_page.dart';
import 'schedule_page.dart';
import 'report_page.dart';
import 'add_session_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser; // Ambil data user login

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

  // Navigasi ke Detail
  void _navigateToDetail(BuildContext context, String sessionId, String subjectName, String? filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendancePage(
          sessionId: sessionId,
          subjectName: subjectName,
          filterStatus: filter,
        ),
      ),
    );
  }

  // FUNGSI BARU: Menampilkan List Detail Kelas Aktif saat Kartu Utama diklik
  void _showActiveClassList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Rincian Kelas Aktif Anda",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 5),
              const Text("Daftar kelas yang sedang berlangsung saat ini:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              if (docs.isEmpty)
                const Center(child: Text("Tidak ada kelas aktif.")),

              // List Kelas
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    int count = data['total_present'] ?? 0;
                    
                    return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.class_, color: Colors.blueAccent),
                        ),
                        title: Text(data['subject_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Ruang: ${data['room'] ?? '-'}"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            // Ubah warna kalau sudah penuh (opsional)
                            color: (data['total_present'] ?? 0) >= (data['max_students'] ?? 0) && (data['max_students'] ?? 0) > 0 
                                ? Colors.redAccent 
                                : Colors.green, 
                            borderRadius: BorderRadius.circular(15)
                          ),
                          child: Text(
                            // FORMAT BARU: "5 / 40 Hadir"
                            "${data['total_present'] ?? 0} / ${data['max_students'] ?? '-'} Hadir",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToDetail(context, docs[index].id, data['subject_name'], null);
                        },
                      );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET DASHBOARD ---
  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('status', isEqualTo: 'OPEN')
          .where('lecturer_email', isEqualTo: currentUser?.email) // <--- FILTER: Hanya Data Saya
          .snapshots(),
      builder: (context, snapshot) {
        int activeClassesCount = 0;
        int totalHadirCount = 0;
        List<QueryDocumentSnapshot> activeDocs = [];

        if (snapshot.hasData) {
          activeDocs = snapshot.data!.docs;
          activeClassesCount = activeDocs.length;
          for (var doc in activeDocs) {
            totalHadirCount += (doc.data() as Map<String, dynamic>)['total_present'] as int? ?? 0;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Halo, ${currentUser?.displayName ?? 'Dosen'}",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Text(
                "Dashboard",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),

              // Kartu Utama (Sekarang Bisa Diklik)
              _buildMainCard(
                count: activeClassesCount, 
                onTap: () => _showActiveClassList(context, activeDocs) // <--- Aksi Klik
              ),
              const SizedBox(height: 25),

              // Grid Statistik
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(
                    title: "Hadir Total",
                    count: totalHadirCount.toString(),
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                    onTap: () => _handleStatClick(context, activeDocs, "HADIR"),
                  ),
                  _buildStatCard(
                    title: "Terlambat",
                    count: "0", 
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: Colors.purple,
                    onTap: () => _handleStatClick(context, activeDocs, "TERLAMBAT"),
                  ),
                  _buildStatCard(
                    title: "Tidak Hadir",
                    count: "0",
                    icon: Icons.cancel_outlined,
                    iconColor: Colors.red,
                    onTap: () => _handleStatClick(context, activeDocs, "TIDAK HADIR"),
                  ),
                  _buildStatCard(
                    title: "Lihat Semua",
                    count: "Data",
                    icon: Icons.list_alt_rounded,
                    iconColor: Colors.blue,
                    onTap: () => _handleStatClick(context, activeDocs, null),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper untuk klik kartu kecil (Hadir/Telat dll)
  void _handleStatClick(BuildContext context, List<QueryDocumentSnapshot> docs, String? filter) {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada kelas aktif.")));
      return;
    }
    
    // Jika cuma 1 kelas, langsung buka
    if (docs.length == 1) {
       var data = docs.first.data() as Map<String, dynamic>;
       _navigateToDetail(context, docs.first.id, data['subject_name'], filter);
    } else {
      // Jika banyak kelas, tampilkan list dulu (Reuse fungsi yang sama)
      _showActiveClassList(context, docs); 
      // Note: Idealnya kalau klik "Terlambat", listnya memfilter jumlah terlambat juga, 
      // tapi untuk simplifikasi, kita buka list kelas dulu, baru user pilih kelas mana.
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboard(),
      const SchedulePage(),
      const AddSessionPage(),
      const ReportPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _selectedIndex == 0 ? AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.transparent,
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Image.asset('assets/images/logo_kampus.png', errorBuilder: (c,o,s) => const Icon(Icons.school)),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Campus Smart", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Attendance.", style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ) : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Jadwal'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_rounded, size: 30), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_rounded), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Pengaturan'),
        ],
      ),
    );
  }

  Widget _buildMainCard({required int count, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap, // Kartu Utama Bisa Diklik
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 2))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Kelas Aktif Anda", style: TextStyle(fontSize: 16, color: Colors.black54)), // Judul diubah sedikit
              const SizedBox(height: 10),
              Text(count.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87))
            ]),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.domain_rounded, size: 40, color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String count, required IconData icon, required Color iconColor, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)), Icon(icon, color: iconColor, size: 28)]), Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87))]),
      ),
    );
  }
}