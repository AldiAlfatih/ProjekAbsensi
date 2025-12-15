import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controller untuk mengambil teks dari inputan
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Fungsi untuk Login
  Future<void> _login() async {
    try {
      // 1. Proses Login ke Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Jika berhasil, munculkan pesan (Nanti kita arahkan ke Home)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 3. Jika gagal (password salah / user tidak ada)
      if (mounted) {
        String message = "Login Gagal";
        if (e.code == 'user-not-found') {
          message = "Email tidak ditemukan.";
        } else if (e.code == 'wrong-password') {
          message = "Password salah.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login Aplikasi")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gambar Logo (Opsional, pakai icon dulu)
            const Icon(Icons.lock_person, size: 80, color: Colors.blue),
            const SizedBox(height: 20),

            // Input Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 10),

            // Input Password
            TextField(
              controller: _passwordController,
              obscureText: true, // Biar teks jadi bintang-bintang
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Login
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
                child: const Text("MASUK"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}