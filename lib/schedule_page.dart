import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Pastikan nama hari sesuai dengan data di Firebase (Huruf Besar Awal)
    final List<String> days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    
    return DefaultTabController(
      length: days.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Jadwal Perkuliahan"),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            tabs: days.map((day) => Tab(text: day)).toList(),
          ),
        ),
        body: TabBarView(
          children: days.map((day) => _ScheduleList(day: day)).toList(),
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final String day;
  const _ScheduleList({required this.day});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ⚠️ PERBAIKAN PENTING:
      // Saya menghapus .orderBy('start_time') untuk mengatasi loading terus menerus.
      // Jika ingin sorting, kita lakukan manual di bawah (docs.sort).
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('day', isEqualTo: day)
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
                Icon(Icons.calendar_today_outlined, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("Tidak ada jadwal $day", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // SORTING MANUAL DI SINI (Biar gak perlu Index Firebase)
        var sortedDocs = snapshot.data!.docs.toList();
        sortedDocs.sort((a, b) {
          var timeA = (a.data() as Map)['start_time'] ?? "00:00";
          var timeB = (b.data() as Map)['start_time'] ?? "00:00";
          return timeA.compareTo(timeB);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            var data = sortedDocs[index].data() as Map<String, dynamic>;
            bool isMe = data['lecturer_email'] == FirebaseAuth.instance.currentUser?.email;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isMe ? Border.all(color: Colors.blue, width: 1.5) : null,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue[50] : Colors.grey[100], 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Icon(Icons.class_, color: isMe ? Colors.blue : Colors.grey),
                ),
                title: Text(data['subject_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("R. ${data['room']} • ${data['start_time']} - ${data['end_time']}\n${data['lecturer_email']}", style: const TextStyle(fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }
}