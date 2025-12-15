import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSubjectsPage extends StatefulWidget {
  const ManageSubjectsPage({super.key});

  @override
  State<ManageSubjectsPage> createState() => _ManageSubjectsPageState();
}

class _ManageSubjectsPageState extends State<ManageSubjectsPage> {
  // Fungsi Tambah Matkul
  void _showAddDialog() {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final startController = TextEditingController();
    final endController = TextEditingController();
    final countController = TextEditingController();
    
    String selectedDay = 'Senin';
    final List<String> days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Tambah Mata Kuliah"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nama Matkul")),
                    TextField(controller: roomController, decoration: const InputDecoration(labelText: "Ruangan Default")),
                    TextField(
                      controller: countController, 
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Total Mahasiswa (Kuota)"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: selectedDay,
                      isExpanded: true,
                      items: days.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (val) => setStateDialog(() => selectedDay = val!),
                    ),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: startController, decoration: const InputDecoration(labelText: "Mulai (08:00)"))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: endController, decoration: const InputDecoration(labelText: "Selesai (10:00)"))),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      FirebaseFirestore.instance.collection('subjects').add({
                        'matkul_name': nameController.text, // <--- UBAH JADI matkul_name
                        'room': roomController.text,
                        'student_limit': int.tryParse(countController.text) ?? 0,
                        'day': selectedDay,
                        'start_time': startController.text,
                        'end_time': endController.text,
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Matkul berhasil ditambah!")));
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kelola Data Mata Kuliah")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              int limit = data['student_limit'] ?? 0;

              return ListTile(
                // <--- UBAH JADI matkul_name
                title: Text(data['matkul_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data['day']} • ${data['start_time']}-${data['end_time']} • Kuota: $limit Mhs"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("Hapus Matkul?"),
                        content: const Text("Data ini akan hilang permanen."),
                        actions: [
                          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Batal")),
                          TextButton(
                            onPressed: () {
                              FirebaseFirestore.instance.collection('subjects').doc(docs[index].id).delete();
                              Navigator.pop(c);
                            }, 
                            child: const Text("Hapus", style: TextStyle(color: Colors.red))
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}