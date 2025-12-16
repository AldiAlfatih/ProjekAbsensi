import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- FUNGSI 1: LOGIN (HANYA UNTUK MASUK) ---
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email dan Password harus diisi!")));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Coba Login ke Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Jika berhasil, masuk ke Home
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      }

    } on FirebaseAuthException catch (e) {
      String message = "Login Gagal.";
      if (e.code == 'user-not-found') message = "Email tidak terdaftar.";
      if (e.code == 'wrong-password') message = "Password salah.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI 2: SEEDER (GENERATE AKUN OTOMATIS) ---
  // Password default semua akun: 123456
  Future<void> _runSeeder() async {
    setState(() => _isLoading = true);
    
    List<Map<String, String>> seeds = [
      {'email': 'garizah@gmail.com', 'name': 'Garizah', 'role': 'admin'},
      {'email': 'bimo@gmail.com', 'name': 'Bimo', 'role': 'dosen'},
      {'email': 'widya@gmail.com', 'name': 'Widya', 'role': 'dosen'},
    ];

    int successCount = 0;

    for (var user in seeds) {
      try {
        // 1. Buat User di Auth (Password Default: 123456)
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: user['email']!,
          password: "123456", 
        );

        // 2. Simpan Data & Role ke Firestore
        if (cred.user != null) {
          await cred.user!.updateDisplayName(user['name']);
          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'email': user['email'],
            'name': user['name'],
            'role': user['role'],
            'created_at': FieldValue.serverTimestamp(),
          });
          
          // 3. Logout langsung (karena createUser otomatis login)
          await FirebaseAuth.instance.signOut();
          successCount++;
        }
      } catch (e) {
        print("Gagal buat ${user['email']}: $e");
        // Kemungkinan error: 'email-already-in-use' (Artinya sudah pernah dibuat)
      }
    }

    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Selesai! $successCount akun baru berhasil dibuat."),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Tambahkan tombol rahasia di AppBar untuk Generate Akun
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _runSeeder,
            icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.grey),
            label: const Text("Generate Akun (Dev)", style: TextStyle(color: Colors.grey, fontSize: 10)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Kampus
                Image.asset(
                  'assets/images/logo_kampus.png', 
                  height: 100, 
                  errorBuilder: (c,e,s) => const Icon(Icons.school, size: 100, color: Colors.blue)
                ),
                const SizedBox(height: 20),
                const Text("Login ITH Smart Attendance", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Silakan masuk menggunakan akun institusi.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                TextField(
                  controller: _emailController, 
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController, 
                  obscureText: true, 
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("MASUK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}