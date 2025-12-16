import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final TextEditingController _roomController = TextEditingController(text: "201");
  
  // Data Dummy (NIM & Nama harus cocok dengan jadwal Admin)
  final List<Map<String, dynamic>> _dummyStudents = [
    {'id': 1, 'name': 'Andi'}, // Pastikan nama ini sama dengan di Jadwal Admin
    {'id': 2, 'name': 'Budi'},
    {'id': 3, 'name': 'Citra'},
  ];

  // SIMULASI BUKA PINTU
  Future<void> _simulateOpenDoor() async {
    String roomId = _roomController.text.trim();
    if (roomId.isEmpty) return;

    try {
      await _rtdb.child('devices/ruang_$roomId').update({
        'status': 1, // UPDATE: Pakai 'status' bukan 'door_status'
        'opened_by': 'Ketua Tingkat (Simulasi)',
        'opened_at': DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()), // String Time
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pintu TERBUKA! 🔓"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // SIMULASI SCAN JARI
  Future<void> _simulateStudentScan(Map<String, dynamic> student) async {
    String roomId = _roomController.text.trim();
    if (roomId.isEmpty) return;

    try {
      String newLogKey = _rtdb.child('devices/ruang_$roomId/logs').push().key!;

      await _rtdb.child('devices/ruang_$roomId/logs/$newLogKey').set({
        'id': student['id'],
        'name': student['name'],
        // UPDATE: Kirim waktu sebagai String
        'timestamp': DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()), 
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${student['name']} Absen!"), duration: const Duration(milliseconds: 500)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // RESET ALAT
  Future<void> _resetDevice() async {
    String roomId = _roomController.text.trim();
    await _rtdb.child('devices/ruang_$roomId').set({
      'status': 0, // UPDATE
      'opened_by': null
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alat Direset.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("IoT Simulator (Format Baru)"), backgroundColor: Colors.orange),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _roomController, decoration: const InputDecoration(labelText: "ID Ruangan", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _simulateOpenDoor, child: const Text("SCAN KETING"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _resetDevice, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text("RESET"))),
            ],
          ),
          const Divider(height: 40),
          const Text("Klik nama untuk Absen:"),
          ..._dummyStudents.map((mhs) => ListTile(
            title: Text(mhs['name']),
            leading: const Icon(Icons.fingerprint),
            onTap: () => _simulateStudentScan(mhs),
          )).toList(),
        ],
      ),
    );
  }
}