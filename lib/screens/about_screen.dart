import 'package:flutter/material.dart';
import 'profile_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE6FAF9FA),
            boxShadow: [
              BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF1B1C1D)),
                        ),
                      ),
                      Image.network(
                        "https://lh3.googleusercontent.com/aida/AEtjO1X_HZjZRVzQSC59dnSb5cJtKHeSqeTngqeS63MpQvCUjbzTCu_YGk3MfzZkiubFfQTBBCajtUoN9HRwNvqecyWTtAUhoqExyAKykIYiOE5k25mdrfBJ5UeeNSDtsXCrfjZNhsgH0RmvrQsc-W8-jnr2mkxVqnI0__44c2Bjsu560-IlXD0yo5--D6LotdmnK4bqzOEGoipO86UH1_bAuc6-ECmxtHqZ42n_tHf57SLJNVQac5-bnY5xVNp6226wtwxLnqTG-X2o2TA",
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF094CB2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            "iBots Remote",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF094CB2),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            "About",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B1C1D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF094CB2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Brand Showcase Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Image.network(
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuDJ42t1_K2hzioBKBxVYgM_pgdArDerO3rwqNE0m3yrP2a9NLgtTKAt9sQtwtuhZzF_X1arq6HLfgffXVVDzsGbKkhb86ok_YlVjk9rMzrfihYMg98_AXWaSOLx32Z1GfbdqVvnHNSKjHhtlqJ10TxQQnxYiTGwLNMRmr1cgds4Ronrd4f_-Fu8aNEgXQI1eF-HxWw9BmZtrF1mGPtfRT083VvNhU01uVK1k8yCYmx3ePOvBdsIOu5qkPZkXy6kKO5pPEA",
                    height: 52,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9E2FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.smart_toy, size: 32, color: Color(0xFF094CB2)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "iBots Remote Controller",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1C1D),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E2FF).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF094CB2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Version 1.0.0 (Build 2026.1)",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001946),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Control your smart devices and robotic car through an intuitive interface.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF434653),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Specifications Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  _buildSpecRow(
                    Icons.memory,
                    "PLATFORM ARCHITECTURE",
                    "ESP32, Arduino & BLE/Wi-Fi",
                  ),
                  const Divider(height: 24, thickness: 1, color: Color(0xFFEFEDEE)),
                  _buildSpecRow(
                    Icons.smart_toy,
                    "ENGINEERING & DESIGN",
                    "iBots Robotics",
                  ),
                  const Divider(height: 24, thickness: 1, color: Color(0xFFEFEDEE)),
                  _buildSpecRow(
                    Icons.verified_user,
                    "FIRMWARE COMPATIBILITY",
                    "v2.4+ Ready & Synchronized",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Minimal Brand & Legal Footer
            const Text(
              "\"Unleash The Parts Of Electronics\"",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF6D5E00),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "© 2026 iBots. All rights reserved.",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF5A5F63),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String subtitle, String title) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEFEDEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF094CB2)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF5A5F63),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B1C1D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
