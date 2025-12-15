import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_page.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  // Variable untuk Filter Tanggal
  DateTimeRange? _selectedDateRange;

  // Fungsi Pilih Rentang Tanggal
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      currentDate: DateTime.now(),
      saveText: "TERAPKAN",
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blueAccent,
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // Fungsi Reset Filter
  void _clearFilter() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  // Simulasi Export Data
  Future<void> _exportData() async {
    // Tampilkan Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Pura-pura proses berat (2 detik)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context); // Tutup Loading

      // Tampilkan Sukses
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 15),
              const Text(
                "Export Berhasil!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "File laporan_absensi.xlsx telah disimpan di folder Download.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("TUTUP"),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          "Laporan Absensi",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Tombol Filter Tanggal
          IconButton(
            onPressed: _pickDateRange,
            icon: Icon(
              Icons.date_range_outlined,
              color: _selectedDateRange != null
                  ? Colors.blueAccent
                  : Colors.grey,
            ),
            tooltip: "Filter Tanggal",
          ),
          // Tombol Export
          IconButton(
            onPressed: _exportData,
            icon: const Icon(Icons.file_download_outlined, color: Colors.green),
            tooltip: "Export Excel",
          ),
        ],
      ),
      body: Column(
        children: [
          // Indikator Filter Aktif
          if (_selectedDateRange != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Filter: ${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}",
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _clearFilter,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.blueAccent,
                    ),
                    tooltip: "Hapus Filter",
                  ),
                ],
              ),
            ),

          // List Data
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Belum ada data."));
                }

                var docs = snapshot.data!.docs;

                // LOGIKA FILTER LOKAL
                if (_selectedDateRange != null) {
                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    Timestamp? ts = data['created_at'];
                    if (ts == null) return false;
                    DateTime date = ts.toDate();
                    return date.isAfter(
                          _selectedDateRange!.start.subtract(
                            const Duration(days: 1),
                          ),
                        ) &&
                        date.isBefore(
                          _selectedDateRange!.end.add(const Duration(days: 1)),
                        );
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        const Text("Tidak ada data di tanggal ini"),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return _buildReportCard(context, data, docs[index].id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper Format Tanggal Pendek
  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  Widget _buildReportCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    String subject = data['subject_name'] ?? "Tanpa Nama";
    String room = data['room'] ?? "-";
    int count = data['total_present'] ?? 0;
    String status = data['status'] ?? "CLOSED";

    // LOGIKA SUMBER DATA (APP vs IOT)
    // Jika data lama tidak punya field ini, anggap default-nya 'IOT'
    String source = data['created_via'] ?? "IOT";
    bool isManual = source == "APP";

    Timestamp? ts = data['created_at'];
    String dateStr = "-";
    String timeStr = "--:--";

    if (ts != null) {
      DateTime dt = ts.toDate();
      List<String> months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "Mei",
        "Jun",
        "Jul",
        "Ags",
        "Sep",
        "Okt",
        "Nov",
        "Des",
      ];
      dateStr = "${dt.day} ${months[dt.month - 1]} ${dt.year}";
      timeStr =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    bool isOpen = status == 'OPEN';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AttendancePage(sessionId: docId, subjectName: subject),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // KOTAK TANGGAL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    dateStr.split(' ')[0],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  Text(
                    dateStr.split(' ')[1],
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),

            // INFO UTAMA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // IKON SUMBER (HP atau IOT)
                      Tooltip(
                        message: isManual
                            ? "Dibuka Manual (App)"
                            : "Dibuka Otomatis (IoT)",
                        child: Icon(
                          isManual
                              ? Icons.phone_android_rounded
                              : Icons.router_rounded,
                          size: 16,
                          color: isManual ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "$timeStr WIB • Ruang $room",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // JUMLAH HADIR
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOpen ? Colors.green[50] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}