import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'iot_control_page.dart';
import 'live_monitoring_page.dart';
import 'report_page.dart';
// Import halaman lain
import 'schedule_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref();

  // Default role dosen agar aman, nanti diupdate di initState
  String _userRole = 'dosen';

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  // --- AMBIL ROLE USER (ADMIN/DOSEN) ---
  Future<void> _getUserRole() async {
    if (currentUser != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _userRole = (doc.data() as Map<String, dynamic>)['role'] ?? 'dosen';
          });
        }
      } catch (e) {
        print("Gagal ambil role: $e");
      }
    }
  }

  String _getTodayName() {
    // Menggunakan locale Indonesia
    return DateFormat('EEEE', 'id_ID').format(DateTime.now());
  }

  // --- FUNGSI 1: BUKA ABSENSI (DOSEN) ---
  Future<void> _activateAttendance(String roomId) async {
    try {
      await _rtdbRef.child('devices/ruang_$roomId').update({
        'attendance_status': 1, // Status Absen Aktif
        'attendance_started_at': DateFormat(
          "yyyy-MM-dd HH:mm:ss",
        ).format(DateTime.now()),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Absensi Dibuka! Mahasiswa silakan scan. 🔓"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- FUNGSI 2: TUTUP & REKAP (DOSEN) ---
  Future<void> _recapAttendance(
    String roomId,
    String scheduleId,
    Map<String, dynamic> scheduleData,
    String? realStartTimeStr,
  ) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Tutup Absensi?"),
            content: const Text(
              "Sistem akan menghitung kehadiran dan menyimpan ke riwayat.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text("REKAP SEKARANG"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    // Loading Indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // 1. Ambil Log dari RTDB
      DataSnapshot snapshot = await _rtdbRef
          .child('devices/ruang_$roomId/logs')
          .get();
      Map<dynamic, dynamic> logs = {};

      if (snapshot.value != null) {
        // Fix Bug: Handle List vs Map dari Firebase
        if (snapshot.value is List) {
          logs = Map<dynamic, dynamic>.from((snapshot.value as List).asMap());
        } else {
          logs = Map<dynamic, dynamic>.from(
            snapshot.value as Map<dynamic, dynamic>,
          );
        }
        logs.removeWhere((key, value) => value == null);
      }

      // 2. Siapkan Data
      List<dynamic> enrolledRaw = scheduleData['enrolled_students'] ?? [];
      List<Map<String, dynamic>> finalAttendance = [];

      // Tentukan Waktu Mulai (Pakai Waktu Dosen Buka Absen jika ada)
      DateTime classStartTime;
      if (realStartTimeStr != null) {
        classStartTime = DateFormat(
          "yyyy-MM-dd HH:mm:ss",
        ).parse(realStartTimeStr);
      } else {
        DateTime now = DateTime.now();
        DateTime schedTime = DateFormat(
          "HH:mm",
        ).parse(scheduleData['start_time']);
        classStartTime = DateTime(
          now.year,
          now.month,
          now.day,
          schedTime.hour,
          schedTime.minute,
        );
      }

      int countHadir = 0;
      int countTelat = 0;
      int countAlpa = 0;

      // 3. Loop Mahasiswa
      for (var student in enrolledRaw) {
        String nim = (student is String) ? student : student['nim'];
        String namaMhs = (student is String) ? student : student['name'];

        // Cari di Log
        var foundLogEntry = logs.values.firstWhere((log) {
          if (log == null) return false;
          String logName = (log['name'] ?? "").toString().toLowerCase();
          bool nameMatch =
              logName.contains(namaMhs.toLowerCase()) ||
              namaMhs.toLowerCase().contains(logName);

          // Cek Tanggal Hari Ini
          bool dateMatch = false;
          if (log['timestamp'] != null) {
            try {
              DateTime logTime = DateFormat(
                "yyyy-MM-dd HH:mm:ss",
              ).parse(log['timestamp']);
              DateTime now = DateTime.now();
              if (logTime.year == now.year &&
                  logTime.month == now.month &&
                  logTime.day == now.day) {
                dateMatch = true;
              }
            } catch (e) {}
          }
          return nameMatch && dateMatch;
        }, orElse: () => null);

        String status = "ALPA";
        String scanTime = "-";
        String lateDuration = "";

        if (foundLogEntry != null) {
          String timeString = foundLogEntry['timestamp'] ?? "";
          try {
            DateTime timeScan = DateFormat(
              "yyyy-MM-dd HH:mm:ss",
            ).parse(timeString);
            scanTime = DateFormat("HH:mm").format(timeScan);

            // Toleransi 15 Menit dari Absen Dibuka
            int diffMinutes = timeScan.difference(classStartTime).inMinutes;
            if (diffMinutes > 15) {
              status = "TERLAMBAT";
              lateDuration = "$diffMinutes Menit";
              countTelat++;
            } else {
              status = "HADIR";
              countHadir++;
            }
          } catch (e) {
            status = "HADIR";
            countHadir++;
          }
        } else {
          status = "ALPA";
          countAlpa++;
        }

        finalAttendance.add({
          'nim': nim,
          'name': namaMhs,
          'status': status,
          'scan_time': scanTime,
          'late_duration': lateDuration,
        });
      }

      // 4. Simpan ke Firestore Riwayat
      await FirebaseFirestore.instance.collection('attendance_history').add({
        'schedule_id': scheduleId,
        'subject_name': scheduleData['subject_name'],
        'room': roomId,
        'date': Timestamp.now(),
        'lecturer_email': currentUser?.email, // Email dosen pemilik kelas
        'summary': {
          'hadir': countHadir,
          'telat': countTelat,
          'alpa': countAlpa,
        },
        'details': finalAttendance,
        'actual_start_time': realStartTimeStr,
      });

      // 5. Reset Alat IoT (Bersihkan Log & Status Absen)
      await _rtdbRef.child('devices/ruang_$roomId').update({
        'attendance_status': 0,
        'attendance_started_at': null,
        'logs': null,
      });

      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Absensi Ditutup & Direkap ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- KOMPONEN DASHBOARD ---
  Widget _buildDashboardContent() {
    String today = _getTodayName();

    // Tentukan Query: Admin lihat semua, Dosen lihat punya sendiri
    Query query = FirebaseFirestore.instance
        .collection('schedules')
        .where('day', isEqualTo: today);

    if (_userRole != 'admin') {
      query = query.where('lecturer_email', isEqualTo: currentUser?.email);
    }

    // Tambahkan Order By Time
    // Catatan: Jika error "Index Required", hapus .orderBy sementara atau buat index di Firebase Console
    // query = query.orderBy('start_time');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error memuat jadwal: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  _userRole == 'admin'
                      ? "Tidak ada jadwal kuliah hari ini."
                      : "Anda tidak memiliki jadwal hari ini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildLiveClassCard(
              data['room'] ?? "000",
              snapshot.data!.docs[index].id,
              data,
              isAdminView: _userRole == 'admin',
            );
          },
        );
      },
    );
  }

  // --- KARTU MONITORING KELAS ---
  Widget _buildLiveClassCard(
    String roomId,
    String scheduleId,
    Map<String, dynamic> scheduleData, {
    bool isAdminView = false,
  }) {
    return StreamBuilder(
      stream: _rtdbRef.child('devices/ruang_$roomId').onValue,
      builder: (context, snapshot) {
        int doorStatus = 0;
        int attendanceStatus = 0;
        String? attendanceStartedAt;
        String openedBy = "-";
        int studentCount = 0;
        Map<dynamic, dynamic> currentLogs = {};

        // Cek Relevansi Waktu (Toleransi 5 Menit)
        bool isScheduleRelevant = false;
        try {
          DateTime now = DateTime.now();
          DateTime startTime = DateFormat(
            "HH:mm",
          ).parse(scheduleData['start_time']);
          startTime = DateTime(
            now.year,
            now.month,
            now.day,
            startTime.hour,
            startTime.minute,
          );
          DateTime endTime = DateFormat(
            "HH:mm",
          ).parse(scheduleData['end_time']);
          endTime = DateTime(
            now.year,
            now.month,
            now.day,
            endTime.hour,
            endTime.minute,
          );

          if (now.isAfter(startTime.subtract(const Duration(minutes: 5))) &&
              now.isBefore(endTime.add(const Duration(minutes: 5)))) {
            isScheduleRelevant = true;
          }
        } catch (e) {
          isScheduleRelevant = true;
        }

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          var data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          doorStatus = data['status'] ?? 0;
          attendanceStatus = data['attendance_status'] ?? 0;
          attendanceStartedAt = data['attendance_started_at'];
          openedBy = data['opened_by'] ?? "-";

          if (data['logs'] != null) {
            if (data['logs'] is List) {
              currentLogs = Map<dynamic, dynamic>.from(
                (data['logs'] as List).asMap(),
              );
            } else {
              currentLogs = Map<dynamic, dynamic>.from(
                data['logs'] as Map<dynamic, dynamic>,
              );
            }
            currentLogs.removeWhere((key, value) => value == null);
            studentCount = currentLogs.length;
          }
        }

        // --- UI STATUS WARNA ---
        String statusText;
        Color statusColor;
        bool showActivateBtn = false;
        bool showRecapBtn = false;

        if (!isScheduleRelevant) {
          statusText = "Jadwal Selesai / Belum Mulai";
          statusColor = Colors.grey;
        } else if (doorStatus == 0) {
          statusText = "Menunggu Ketua Tingkat...";
          statusColor = Colors.orange;
        } else if (doorStatus == 1 && attendanceStatus == 0) {
          statusText = "Pintu Terbuka. Menunggu Dosen...";
          statusColor = Colors.blue;
          if (!isAdminView) {
            showActivateBtn = true; // Hanya Dosen yang bisa aktifkan
          }
        } else {
          statusText = "ABSENSI AKTIF";
          statusColor = Colors.green;
          if (!isAdminView) {
            showRecapBtn = true; // Hanya Dosen yang bisa rekap
          }
        }

        return GestureDetector(
          onTap: () {
            // Admin bisa pantau kapan saja, Dosen bisa pantau jika aktif/buka
            if (showRecapBtn || isAdminView || (doorStatus == 1)) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LiveMonitoringPage(
                    scheduleData: scheduleData,
                    rtdbLogs: currentLogs,
                    enrolledStudents: List<dynamic>.from(
                      scheduleData['enrolled_students'] ?? [],
                    ),
                  ),
                ),
              );
            }
          },
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: statusColor == Colors.green
                  ? const BorderSide(color: Colors.green, width: 2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scheduleData['subject_name'] ?? "-",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isAdminView)
                              Text(
                                "Dosen: ${scheduleData['lecturer_email']}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.room, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text("Ruang $roomId"),
                      const SizedBox(width: 15),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "${scheduleData['start_time']} - ${scheduleData['end_time']}",
                      ),
                    ],
                  ),
                  const Divider(height: 25),

                  if (doorStatus == 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Dibuka oleh:",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          openedBy,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    if (attendanceStatus == 1 || isAdminView)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Mahasiswa Scan:",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            "$studentCount Orang",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 15),

                    // TOMBOL AKSI (Disembunyikan untuk Admin)
                    if (showActivateBtn)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _activateAttendance(roomId),
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "AKTIFKAN ABSENSI",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                    if (showRecapBtn)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _recapAttendance(
                            roomId,
                            scheduleId,
                            scheduleData,
                            attendanceStartedAt,
                          ),
                          icon: const Icon(
                            Icons.stop_circle,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "TUTUP & REKAP ABSENSI",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    const Text(
                      "Menunggu Ketua Tingkat scan kartu di ruangan...",
                      style: TextStyle(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // List Halaman untuk Navigasi Bawah
    final List<Widget> pages = [
      const SizedBox(), // Placeholder Dashboard (karena dirender manual di bawah)
      const SchedulePage(),
      const IotControlPage(),
      const ReportPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      // App Bar hanya muncul di Dashboard
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/logo_kampus.png',
                    height: 35,
                    width: 35,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.school, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "ITH Smart Attendance",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                // Badge Role
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _userRole == 'admin' ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _userRole.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,

      body: _selectedIndex == 0
          // Konten Dashboard
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Halo, ${currentUser?.displayName ?? 'User'}",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    _userRole == 'admin'
                        ? "Semua Jadwal Hari Ini"
                        : "Jadwal Anda Hari Ini",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'EEEE, d MMMM yyyy',
                      'id_ID',
                    ).format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDashboardContent(),
                ],
              ),
            )
          // Halaman Lain
          : pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Jadwal',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'IoT'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Akun'),
        ],
      ),
    );
  }
}
