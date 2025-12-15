import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendancePage extends StatefulWidget {
  final String sessionId;
  final String subjectName;
  final String? filterStatus; // Parameter baru untuk filter

  const AttendancePage({
    super.key,
    required this.sessionId,
    required this.subjectName,
    this.filterStatus, // Bisa null (artinya tampilkan semua)
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  // Fungsi Warna Status
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'HADIR': return Colors.green;
      case 'IZIN': return Colors.orange;
      case 'SAKIT': return Colors.amber;
      case 'ALPA': return Colors.red;
      case 'TERLAMBAT': return Colors.purple; // Tambahan warna
      default: return Colors.grey;
    }
  }

  // Fungsi Edit Status
  void _showEditStatusDialog(BuildContext context, String docId, String currentName) {
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
              Text("Ubah Status: $currentName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              _buildStatusOption(context, docId, "HADIR", Colors.green),
              _buildStatusOption(context, docId, "TERLAMBAT", Colors.purple),
              _buildStatusOption(context, docId, "IZIN", Colors.orange),
              _buildStatusOption(context, docId, "SAKIT", Colors.amber),
              _buildStatusOption(context, docId, "ALPA", Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(BuildContext context, String docId, String status, Color color) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.circle, color: color, size: 15)),
      title: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () {
        FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('attendance_logs')
            .doc(docId)
            .update({'status': status});
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Status diubah jadi $status"), duration: const Duration(seconds: 1)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Judul Halaman menyesuaikan Filter
    String title = widget.subjectName;
    if (widget.filterStatus != null) {
      title += " (${widget.filterStatus})";
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18)),
            const Text("Detail Kehadiran", style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('attendance_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada data mahasiswa"));
          }

          var docs = snapshot.data!.docs;

          // --- LOGIKA FILTERING CLIENT-SIDE ---
          // Jika ada filter, kita saring datanya di sini
          if (widget.filterStatus != null) {
            docs = docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String status = data['status'] ?? "";
              
              if (widget.filterStatus == "TIDAK HADIR") {
                // Logic khusus: Tidak Hadir = ALPA, IZIN, atau SAKIT
                return ["ALPA", "IZIN", "SAKIT"].contains(status);
              } else {
                return status == widget.filterStatus;
              }
            }).toList();
          }
          // ------------------------------------

          if (docs.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.filter_list_off, size: 60, color: Colors.grey[300]),
                   const SizedBox(height: 10),
                   Text("Tidak ada mahasiswa status '${widget.filterStatus}'"),
                 ],
               ),
             );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              String name = data['name'] ?? "Tanpa Nama";
              String status = data['status'] ?? "HADIR";
              
              Timestamp? ts = data['timestamp'];
              String timeString = "--:--";
              if (ts != null) {
                DateTime date = ts.toDate();
                timeString = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              }

              return Dismissible(
                key: Key(docId),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (d) {
                  FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).collection('attendance_logs').doc(docId).delete();
                },
                child: ListTile(
                  onTap: () => _showEditStatusDialog(context, docId, name),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[50],
                    child: Text("${index + 1}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Text("NIM: $docId"),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(4)),
                        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  trailing: Text("$timeString WIB", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}