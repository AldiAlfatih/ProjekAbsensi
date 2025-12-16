import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _role = 'dosen';
  bool _isLoadingRole = true; // KUNCI UTAMA: Penahan Loading agar tidak kedip

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  // Ambil Role dulu sampai selesai, baru render halaman
  Future<void> _fetchRole() async {
    if (currentUser != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _role = (doc.data() as Map<String, dynamic>)['role'] ?? 'dosen';
            _isLoadingRole = false; // Loading selesai, data siap tampil
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  // --- ALGORITMA SISTEM CERDAS (FUZZY LOGIC SEDERHANA) ---
  // Konsep: Memetakan status kehadiran (Input) menjadi Prediksi Kelulusan (Output)
  // --- ANALISIS KELAS (AI CLASS ANALYST) ---
  Widget _buildClassAnalysisCard(Map<String, dynamic> summary) {
    int hadir = summary['hadir'] ?? 0;
    int telat = summary['telat'] ?? 0;
    int alpa = summary['alpa'] ?? 0;
    int total = hadir + telat + alpa;

    if (total == 0) return const SizedBox();

    double participationRate = (hadir + telat) / total; // Tingkat Partisipasi
    double disciplineRate = (hadir + telat) > 0
        ? hadir / (hadir + telat)
        : 0; // Tingkat Kedisiplinan

    String title;
    String description;
    Color color;
    IconData icon;

    // LOGIKA PENENTUAN KUALITAS KELAS
    if (participationRate >= 0.8 && disciplineRate >= 0.8) {
      title = "Kelas Sangat Efektif";
      description =
          "Materi tersampaikan dengan baik. Mahasiswa antusias dan disiplin tinggi.";
      color = Colors.green;
      icon = Icons.verified;
    } else if (participationRate >= 0.8 && disciplineRate < 0.6) {
      title = "Disiplin Rendah";
      description =
          "Mahasiswa antusias hadir (ramai), namun banyak yang terlambat. Perlu evaluasi waktu mulai kelas.";
      color = Colors.orange;
      icon = Icons.access_alarm;
    } else if (participationRate < 0.5) {
      title = "Minat/Partisipasi Rendah";
      description =
          "Lebih dari 50% mahasiswa tidak hadir. Perlu evaluasi metode pengajaran atau jadwal.";
      color = Colors.red;
      icon = Icons.warning_amber_rounded;
    } else {
      title = "Cukup Baik";
      description =
          "Kelas berjalan standar. Tingkatkan interaksi agar mahasiswa lebih termotivasi.";
      color = Colors.blue;
      icon = Icons.thumb_up_alt_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Class Analyst: $title",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(color: Colors.black87, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat("Partisipasi", participationRate, Colors.blue),
                    const SizedBox(width: 15),
                    _miniStat("Kedisiplinan", disciplineRate, Colors.purple),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double val, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          "$label ${(val * 100).toInt()}%",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Center(child: Text("Silakan Login"));

    // TAMPILKAN LOADING PENUH JIKA ROLE BELUM SIAP (Solusi Masalah Kedip)
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // QUERY BUILDER
    Query query = FirebaseFirestore.instance
        .collection('attendance_history')
        .orderBy('date', descending: true);

    // Filter Query (Dosen hanya lihat punyanya, Admin lihat semua)
    if (_role != 'admin') {
      query = query.where('lecturer_email', isEqualTo: currentUser?.email);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat & Prediksi Cerdas")),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  "Terjadi Kesalahan (Missing Index):\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    _role == 'admin'
                        ? "Belum ada data absensi masuk."
                        : "Anda belum memiliki riwayat mengajar.",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              Timestamp? t = data['date'];
              String dateStr = t != null
                  ? DateFormat(
                      'EEEE, d MMMM yyyy • HH:mm',
                      'id_ID',
                    ).format(t.toDate())
                  : "-";
              var summary =
                  data['summary'] ?? {'hadir': 0, 'telat': 0, 'alpa': 0};

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.blueAccent,
                    ), // Ikon Otak/AI
                  ),
                  title: Text(
                    data['subject_name'] ?? "-",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("$dateStr\nRuang ${data['room']}"),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. HEADER RINGKASAN
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statBadge(
                                "HADIR",
                                summary['hadir'],
                                Colors.green,
                              ),
                              _statBadge(
                                "TELAT",
                                summary['telat'],
                                Colors.orange,
                              ),
                              _statBadge("ALPA", summary['alpa'], Colors.red),
                            ],
                          ),
                          const Divider(height: 30),

                          // 2. PENJELASAN FITUR CERDAS (Untuk Show off ke Dosen)
                          // 2. AI CLASS ANALYST (Evaluasi Dosen)
                          _buildClassAnalysisCard(summary),
                          const SizedBox(height: 15),

                          // 3. DETAIL MAHASISWA & PREDIKSI
                          const Text(
                            "Detail Analisis Mahasiswa:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ...(data['details'] as List<dynamic>).map((m) {
                            String status = m['status'] ?? 'ALPA';
                            String lateDuration = m['late_duration'] ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris Atas: Nama & Status
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        m['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'ALPA'
                                              ? Colors.red
                                              : (status == 'TERLAMBAT'
                                                    ? Colors.orange
                                                    : Colors.green),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Baris Bawah: Detail Durasi
                                  if (status == 'TERLAMBAT')
                                    Text(
                                      "Terlambat $lateDuration",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else if (status == 'ALPA')
                                    const Text(
                                      "Tidak scan QR Code",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    const Text(
                                      "Hadir Tepat Waktu",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statBadge(String label, int val, Color color) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
