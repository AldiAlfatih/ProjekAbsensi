import 'package:flutter/material.dart';

class HistoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> historyData;

  const HistoryDetailPage({super.key, required this.historyData});

  // --- LOGIKA KECERDASAN BUATAN (FUZZY LOGIC) ---
  Map<String, dynamic> _analisisPerforma(List<dynamic> details) {
    int totalMhs = details.length;
    if (totalMhs == 0) return {'status': 'Data Kosong', 'color': Colors.grey, 'saran': '-'};

    int alpa = details.where((x) => x['status'] == 'ALPA').length;
    int telat = details.where((x) => x['status'] == 'TERLAMBAT').length;
    
    // Hitung Persentase Ketidakhadiran/Ketidakdisiplinan
    double skorDisiplin = ((totalMhs - (alpa + (telat * 0.5))) / totalMhs) * 100;

    // Klasifikasi (Rule Base)
    if (skorDisiplin >= 90) {
      return {
        'status': 'SANGAT BAIK 🌟',
        'color': Colors.green,
        'saran': 'Pertahankan metode pengajaran. Mahasiswa sangat antusias.',
      };
    } else if (skorDisiplin >= 70) {
      return {
        'status': 'CUKUP BAIK ⚠️',
        'color': Colors.orange,
        'saran': 'Perlu sedikit teguran bagi mahasiswa yang sering terlambat.',
      };
    } else {
      return {
        'status': 'KURANG (BERMASALAH) 🚨',
        'color': Colors.red,
        'saran': 'Disarankan evaluasi mendalam atau SP (Surat Peringatan) massal.',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> details = historyData['details'] ?? [];
    
    // Sort: Alpa & Telat di atas
    details.sort((a, b) => (a['status'] ?? "").compareTo(b['status'] ?? ""));

    // Jalankan Analisis AI
    var hasilAnalisis = _analisisPerforma(details);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text("Detail & Analisis"), backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: Column(
        children: [
          // --- KARTU ANALISIS SISTEM CERDAS ---
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [hasilAnalisis['color'], hasilAnalisis['color'].withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.white, size: 30), // Ikon Otak/AI
                    const SizedBox(width: 10),
                    const Text("Analisis Cerdas Kelas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const Divider(color: Colors.white30),
                Text("Performa: ${hasilAnalisis['status']}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("Saran : ${hasilAnalisis['saran']}", style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          // --- LIST MAHASISWA ---
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: details.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (context, index) {
                var s = details[index];
                String nama = s['name'] ?? "Mahasiswa";
                String nim = s['nim'] ?? "-";
                String status = s['status'] ?? "ALPA";
                String scanTime = s['scan_time'] ?? "-";
                String duration = s['late_duration'] ?? "";

                Color color = status == 'HADIR' ? Colors.green : (status == 'TERLAMBAT' ? Colors.orange : Colors.red);
                IconData icon = status == 'HADIR' ? Icons.check : (status == 'TERLAMBAT' ? Icons.access_time : Icons.close);

                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                    title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("NIM: $nim"),
                        if (status == 'TERLAMBAT') 
                          Text("Terlambat: $duration", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        if (status == 'HADIR')
                          Text("Masuk: $scanTime"),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
                      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}