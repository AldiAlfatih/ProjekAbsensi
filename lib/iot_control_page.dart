import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class IotControlPage extends StatefulWidget {
  const IotControlPage({super.key});

  @override
  State<IotControlPage> createState() => _IotControlPageState();
}

class _IotControlPageState extends State<IotControlPage> {
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final TextEditingController _roomController = TextEditingController(text: "201"); // Default Ruang 201
  bool _isLoading = false;

  // Fungsi Manual Override (Buka/Tutup Paksa)
  Future<void> _toggleDoor(int currentStatus) async {
    String roomId = _roomController.text.trim();
    if (roomId.isEmpty) return;

    setState(() => _isLoading = true);
    
    int newStatus = currentStatus == 1 ? 0 : 1; // Jika 1 jadi 0, Jika 0 jadi 1
    String action = newStatus == 1 ? "MEMBUKA" : "MENUTUP";

    try {
      await _rtdb.child('devices/ruang_$roomId').update({
        'status': newStatus,
        'opened_by': newStatus == 1 ? "Dosen (Manual App)" : null,
        'opened_at': newStatus == 1 ? DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()) : null,
      });

      if (newStatus == 0) {
        // Jika ditutup paksa, hapus log juga biar bersih
        await _rtdb.child('devices/ruang_$roomId/logs').remove();
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Berhasil $action Pintu Ruang $roomId")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String roomId = _roomController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Kontrol Perangkat IoT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Ruangan (Bisa diganti Dropdown jika mau)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pilih Ruangan untuk Dikontrol:", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      hintText: "Contoh: 201",
                      border: InputBorder.none,
                      suffixIcon: Icon(Icons.search, color: Colors.blueAccent),
                    ),
                    onChanged: (val) => setState(() {}), // Refresh UI saat ngetik
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // STATUS REALTIME DARI FIREBASE
            StreamBuilder(
              stream: _rtdb.child('devices/ruang_$roomId').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text("Perangkat Ruang $roomId tidak terdeteksi.", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                var data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                int status = data['status'] ?? 0;
                String opener = data['opened_by'] ?? "-";
                bool isOpen = status == 1;

                return Column(
                  children: [
                    // Visual Indikator
                    Center(
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          border: Border.all(color: isOpen ? Colors.green : Colors.red, width: 3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isOpen ? Icons.lock_open : Icons.lock, size: 50, color: isOpen ? Colors.green : Colors.red),
                            const SizedBox(height: 10),
                            Text(isOpen ? "TERBUKA" : "TERKUNCI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isOpen ? Colors.green : Colors.red)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Detail Info
                    if (isOpen)
                      Container(
                        padding: const EdgeInsets.all(15),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                        child: Text("Dibuka oleh: $opener", textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue)),
                      ),
                    
                    const SizedBox(height: 30),

                    // TOMBOL KONTROL MANUAL
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _toggleDoor(status),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOpen ? Colors.redAccent : Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : Icon(isOpen ? Icons.lock : Icons.lock_open, color: Colors.white),
                        label: Text(
                          isOpen ? "KUNCI PINTU (DARURAT)" : "BUKA PINTU (DARURAT)", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Gunakan tombol ini hanya jika alat RFID rusak atau dalam keadaan darurat.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}