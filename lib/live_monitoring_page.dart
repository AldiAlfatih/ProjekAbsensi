import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiveMonitoringPage extends StatefulWidget {
  final Map<String, dynamic> scheduleData;
  final Map<dynamic, dynamic> rtdbLogs;    
  final List<dynamic> enrolledStudents; 

  const LiveMonitoringPage({
    super.key,
    required this.scheduleData,
    required this.rtdbLogs,
    required this.enrolledStudents,
  });

  @override
  State<LiveMonitoringPage> createState() => _LiveMonitoringPageState();
}

class _LiveMonitoringPageState extends State<LiveMonitoringPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> listHadir = [];
  List<Map<String, dynamic>> listTelat = [];
  List<Map<String, dynamic>> listBelumDatang = [];
  List<Map<String, dynamic>> listTidakTerdaftar = []; // <--- LIST BARU

  @override
  void initState() {
    super.initState();
    // Tambah 1 Tab lagi jadi 4
    _tabController = TabController(length: 4, vsync: this);
    _calculateAttendance();
  }

  void _calculateAttendance() {
    // A. SIAPKAN DATA WAKTU
    // Cek apakah pakai waktu mulai real (dari dosen) atau jadwal
    String startTimeStr = widget.scheduleData['actual_start_time'] ?? widget.scheduleData['start_time'];
    DateTime now = DateTime.now();
    DateTime classStartTime;
    
    try {
       // Coba parse format lengkap "yyyy-MM-dd HH:mm:ss" (actual_start_time)
       classStartTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(startTimeStr);
    } catch (e) {
       // Fallback parse format jam "HH:mm" (start_time jadwal)
       DateTime temp = DateFormat("HH:mm").parse(startTimeStr);
       classStartTime = DateTime(now.year, now.month, now.day, temp.hour, temp.minute);
    }

    // List Nama yang sudah diproses (untuk cari yang tidak terdaftar)
    Set<String> processedLogNames = {};

    // B. PROSES MAHASISWA TERDAFTAR
    for (var student in widget.enrolledStudents) {
      String nim = (student is String) ? student : student['nim'];
      String namaMhs = (student is String) ? student : student['name']; // Nama di Jadwal

      // Cari di Log
      var logEntry = widget.rtdbLogs.values.firstWhere(
        (log) {
           String logName = (log['name'] ?? "").toString().toLowerCase();
           // Logika Pencocokan: Nama Jadwal ada di Log ATAU Nama Log ada di Jadwal
           bool isMatch = logName.contains(namaMhs.toLowerCase()) || namaMhs.toLowerCase().contains(logName);
           
           // Validasi Tanggal (Hari Ini)
           bool dateMatch = false;
           if (log['timestamp'] != null) {
              try {
                DateTime logTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(log['timestamp']);
                if (logTime.year == now.year && logTime.month == now.month && logTime.day == now.day) {
                  dateMatch = true;
                }
              } catch (e) {}
           }
           
           if (isMatch && dateMatch) {
             processedLogNames.add(log['name']); // Tandai log ini sudah punya tuan
             return true;
           }
           return false;
        },
        orElse: () => null,
      );

      if (logEntry != null) {
        // HADIR / TELAT
        String timeString = logEntry['timestamp'] ?? "";
        String timeDisplay = "-";
        
        try {
          DateTime scanTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timeString);
          timeDisplay = DateFormat("HH:mm").format(scanTime);

          if (scanTime.difference(classStartTime).inMinutes > 15) {
            listTelat.add({'nim': nim, 'name': namaMhs, 'time': timeDisplay});
          } else {
            listHadir.add({'nim': nim, 'name': namaMhs, 'time': timeDisplay});
          }
        } catch (e) {
          listHadir.add({'nim': nim, 'name': namaMhs, 'time': "Err"});
        }
      } else {
        // BELUM DATANG
        listBelumDatang.add({'nim': nim, 'name': namaMhs, 'time': "-"});
      }
    }

    // C. PROSES LOG SISA (TIDAK TERDAFTAR)
    // Cari log yang belum masuk ke processedLogNames
    widget.rtdbLogs.forEach((key, log) {
      String logName = log['name'] ?? "Unknown";
      if (!processedLogNames.contains(logName)) {
        // Cek tanggal dulu biar ga nampilin log kemarin
        try {
          DateTime logTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(log['timestamp']);
          if (logTime.year == now.year && logTime.month == now.month && logTime.day == now.day) {
             listTidakTerdaftar.add({
               'nim': '?', 
               'name': logName, 
               'time': DateFormat("HH:mm").format(logTime)
             });
          }
        } catch(e) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Live Monitoring", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          isScrollable: true, // Biar tab-nya bisa digeser kalau sempit
          tabs: [
            Tab(text: "Hadir (${listHadir.length})"),
            Tab(text: "Telat (${listTelat.length})"),
            Tab(text: "Belum (${listBelumDatang.length})"),
            Tab(text: "Unknown (${listTidakTerdaftar.length})"), // TAB BARU
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(listHadir, Colors.green, Icons.check_circle),
          _buildList(listTelat, Colors.orange, Icons.access_time_filled),
          _buildList(listBelumDatang, Colors.grey, Icons.help_outline),
          _buildList(listTidakTerdaftar, Colors.red, Icons.no_accounts), // LIST UNKNOWN
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data, Color color, IconData icon) {
    if (data.isEmpty) return const Center(child: Text("Kosong", style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      separatorBuilder: (ctx, i) => const Divider(),
      itemBuilder: (context, index) {
        var mhs = data[index];
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(mhs['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("NIM: ${mhs['nim']}"),
            trailing: Text(mhs['time'], style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}