import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Untuk efek loading di tombol

  // Fungsi Login (Logika tetap sama, cuma nambah loading state)
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        // Pindah ke Home Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Login Gagal";
        if (e.code == 'user-not-found') {
          message = "Email tidak ditemukan.";
        } else if (e.code == 'wrong-password') {
          message = "Password salah.";
        } else if (e.code == 'invalid-email') {
           message = "Format email salah.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Background bersih
      body: Center(
        child: SingleChildScrollView( // Agar tidak error saat keyboard muncul
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. LOGO KAMPUS
              Image.asset(
                'assets/images/logo_kampus.png',
                height: 120, // Sesuaikan tinggi logo
              ),
              const SizedBox(height: 20),

              // 2. JUDUL APLIKASI
              Column(
                children: const [
                  Text(
                    "Selamat Datang di",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Campus Smart Attendance",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 3. INPUT EMAIL (Desain Modern)
              _buildModernInput(
                controller: _emailController,
                label: "Email Akademik",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),

              // 4. INPUT PASSWORD (Desain Modern)
              _buildModernInput(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                obscureText: true,
              ),

              // 5. LUPA PASSWORD (Pemanis)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Hubungi Administrator untuk reset password.")),
                      );
                  },
                  child: const Text("Lupa Password?", style: TextStyle(color: Colors.blueAccent)),
                ),
              ),
              const SizedBox(height: 20),

              // 6. TOMBOL LOGIN BESAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    shadowColor: Colors.blueAccent.withOpacity(0.3),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "MASUK SEKARANG",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              const SizedBox(height: 30),
               // Footer Versi
               Text("Versi 1.0.0 - IoT Project", style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Helper untuk Input Field Modern
  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100], // Background agak abu terang
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none, // Hilangkan border default
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}