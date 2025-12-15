import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendancePage extends StatelessWidget {
  final String sessionId;
  final String subjectName;

  const AttendancePage({
    super.key,
    required this.sessionId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subjectName),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Masuk ke: sessions -> [ID Sesi] -> attendance_logs
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionId)
            .collection('attendance_logs')
            .orderBy('timestamp', descending: true) // Yang baru absen ada di atas
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    "Belum ada mahasiswa hadir",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          var logs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              var data = logs[index].data() as Map<String, dynamic>;
              
              // Format Jam Sederhana
              Timestamp? ts = data['timestamp'];
              String timeString = "-";
              if (ts != null) {
                DateTime date = ts.toDate();
                // Mengambil Jam:Menit saja (Contoh: 10:30)
                timeString = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  data['name'] ?? "Mahasiswa Tanpa Nama",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("NIM: ${logs[index].id}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeString,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Text("WIB", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}