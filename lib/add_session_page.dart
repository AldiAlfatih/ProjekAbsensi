import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class AddSessionPage extends StatefulWidget {
  const AddSessionPage({super.key});

  @override
  State<AddSessionPage> createState() => _AddSessionPageState();
}

class _AddSessionPageState extends State<AddSessionPage> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedSubject;
  final TextEditingController _roomController = TextEditingController();
  bool _isLoading = false;

  // Fungsi Submit Data
  Future<void> _submitSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Mata Kuliah terlebih dahulu!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      // 1. CARI DATA MATKUL UNTUK DAPAT KUOTA
      var subjectQuery = await FirebaseFirestore.instance
          .collection('subjects')
          .where('matkul_name', isEqualTo: _selectedSubject) // Pastikan field ini sesuai database
          .limit(1)
          .get();

      int studentLimit = 0;
      if (subjectQuery.docs.isNotEmpty) {
        studentLimit = (subjectQuery.docs.first.data())['student_limit'] ?? 0;
      }

      // 2. SIMPAN KE SESI
      await FirebaseFirestore.instance.collection('sessions').add({
        'subject_name': _selectedSubject, 
        'room': _roomController.text.trim(),
        'status': 'OPEN',
        'total_present': 0,
        'max_students': studentLimit,
        'opened_by': user?.displayName ?? 'Admin Mobile',
        'lecturer_email': user?.email,
        'created_via': 'APP',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sesi Kelas Berhasil Dibuka! 🚀")));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomePage()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Background Abu Muda Modern
      appBar: AppBar(
        title: const Text("Buka Kelas", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER SECTION
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.lightBlueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.sensors, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text("Mulai Sesi Manual", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text("Gunakan fitur ini jika perangkat IoT tidak tersedia atau error.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // INPUT MATA KULIAH
              _buildSectionLabel("Mata Kuliah"),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
                builder: (context, snapshot) {
                  List<DropdownMenuItem<String>> subjectItems = [];
                  if (snapshot.hasData) {
                    for (var subject in snapshot.data!.docs) {
                      var data = subject.data() as Map<String, dynamic>;
                      String name = data['matkul_name'] ?? 'Tanpa Nama'; 
                      subjectItems.add(DropdownMenuItem(value: name, child: Text(name)));
                    }
                  }
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 2))
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.book, color: Colors.blueAccent),
                        ),
                        hint: const Text("Pilih Mata Kuliah"),
                        initialValue: _selectedSubject,
                        items: subjectItems,
                        onChanged: (val) => setState(() => _selectedSubject = val),
                        validator: (value) => value == null ? 'Wajib dipilih' : null,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // INPUT RUANGAN
              _buildSectionLabel("Lokasi / Ruangan"),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 2))
                  ],
                ),
                child: TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    hintText: "Contoh: Lab 204",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                  ),
                  validator: (value) => value!.isEmpty ? 'Ruangan tidak boleh kosong' : null,
                ),
              ),

              const SizedBox(height: 50),

              // TOMBOL SUBMIT
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    elevation: 5,
                    shadowColor: Colors.blueAccent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_circle_fill, color: Colors.white),
                          SizedBox(width: 10),
                          Text("BUKA SESI SEKARANG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget untuk Label
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
      ),
    );
  }
}