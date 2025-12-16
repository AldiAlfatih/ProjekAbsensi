import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSchedulePage extends StatefulWidget {
  const ManageSchedulePage({super.key});

  @override
  State<ManageSchedulePage> createState() => _ManageSchedulePageState();
}

class _ManageSchedulePageState extends State<ManageSchedulePage> {
  // Fungsi Cek Bentrok (Tetap Sama, Logic Penting)
  Future<bool> _isConflict(String room, String day, String start, String end, String? excludeId) async {
    var snap = await FirebaseFirestore.instance.collection('schedules')
        .where('room', isEqualTo: room).where('day', isEqualTo: day).get();
    int newStart = _toInt(start); int newEnd = _toInt(end);
    for (var doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      var d = doc.data();
      if (newStart < _toInt(d['end_time']) && newEnd > _toInt(d['start_time'])) return true;
    }
    return false;
  }
  int _toInt(String t) => (int.parse(t.split(':')[0])*60) + int.parse(t.split(':')[1]);

  // --- UI DIALOG YANG BARU & SMOOTH ---
  void _showForm({DocumentSnapshot? doc}) {
    final subjectCtrl = TextEditingController(text: doc?['subject_name']);
    final roomCtrl = TextEditingController(text: doc?['room']);
    final emailCtrl = TextEditingController(text: doc?['lecturer_email']);
    final startCtrl = TextEditingController(text: doc?['start_time']);
    final endCtrl = TextEditingController(text: doc?['end_time']);
    final studentCtrl = TextEditingController();
    
    if (doc != null) {
      List s = doc['enrolled_students'] ?? [];
      studentCtrl.text = s.map((e) => e is Map ? (e['nim']=='-' ? e['name'] : "${e['nim']}-${e['name']}") : e).join('\n');
    }

    String selectedDay = doc?['day'] ?? 'Senin';
    bool isLoading = false;

    // ANIMASI DIALOG
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Form",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(builder: (context, setSt) {
          return Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(doc == null ? "Tambah Jadwal" : "Edit Jadwal", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _input(subjectCtrl, "Mata Kuliah", Icons.book),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _input(roomCtrl, "Ruangan (201)", Icons.room)),
                              const SizedBox(width: 10),
                              Expanded(child: DropdownButtonFormField(
                                value: selectedDay,
                                decoration: _dec("Hari", Icons.calendar_today),
                                items: ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setSt(()=>selectedDay=v!),
                              ))
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _input(startCtrl, "Mulai (08:00)", Icons.access_time)),
                              const SizedBox(width: 10),
                              Expanded(child: _input(endCtrl, "Selesai (10:00)", Icons.access_time_filled)),
                            ]),
                            const SizedBox(height: 10),
                            _input(emailCtrl, "Email Dosen", Icons.email),
                            const SizedBox(height: 10),
                            _input(studentCtrl, "Mahasiswa (NIM-Nama)", Icons.people, maxLines: 3),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: isLoading ? null : () async {
                            if(subjectCtrl.text.isEmpty) return;
                            setSt(()=>isLoading=true);
                            
                            // Validasi Konflik
                            if (await _isConflict(roomCtrl.text, selectedDay, startCtrl.text, endCtrl.text, doc?.id)) {
                              setSt(()=>isLoading=false); return;
                            }

                            // Parsing Mhs
                            List<Map<String,String>> mhs = [];
                            for(var line in studentCtrl.text.split('\n')) {
                              if(line.trim().isEmpty) continue;
                              var p = line.split('-');
                              if(p.length>=2) mhs.add({'nim':p[0].trim(), 'name':p.sublist(1).join('-').trim()});
                              else mhs.add({'nim':'-', 'name':line.trim()});
                            }

                            var data = {
                              'subject_name': subjectCtrl.text, 'room': roomCtrl.text, 'day': selectedDay,
                              'start_time': startCtrl.text, 'end_time': endCtrl.text, 'lecturer_email': emailCtrl.text,
                              'enrolled_students': mhs, 'created_at': FieldValue.serverTimestamp()
                            };

                            if(doc==null) await FirebaseFirestore.instance.collection('schedules').add(data);
                            else await FirebaseFirestore.instance.collection('schedules').doc(doc.id).update(data);
                            
                            Navigator.pop(context);
                          },
                          child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Simpan", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack), child: child);
      },
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    filled: true, fillColor: Colors.grey[50]
  );

  Widget _input(TextEditingController c, String l, IconData i, {int maxLines=1}) => TextField(controller: c, maxLines: maxLines, decoration: _dec(l, i));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kelola Jadwal")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(), 
        label: const Text("Jadwal Baru"), icon: const Icon(Icons.add), backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').orderBy('day').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.separated(
            padding: const EdgeInsets.all(15),
            itemCount: snap.data!.docs.length,
            separatorBuilder: (_,__) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              var doc = snap.data!.docs[i]; var d = doc.data() as Map;
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(d['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${d['day']} • ${d['start_time']}-${d['end_time']} • R.${d['room']}"),
                  trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: ()=>_showForm(doc: doc)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}