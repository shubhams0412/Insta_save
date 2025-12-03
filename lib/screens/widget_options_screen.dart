import 'package:flutter/material.dart';
import '../widgets/option_card.dart';

class WidgetOptionsScreen extends StatelessWidget {
  const WidgetOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300, // preview background
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.only(top: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "InstaSave",
                    style: TextStyle(
                      fontFamily: "Pacifico",
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // -------------------------------
              // 🔹 LAYOUT 1 — Two side-by-side
              // -------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Expanded(
                    child: OptionCard(
                      title: "Import from Insta",
                      icon: Icons.camera_alt,
                      colors: [Color(0xFFFF3E8E), Color(0xFFBC06FF)],
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: OptionCard(
                      title: "Select Pics & Repost",
                      icon: Icons.repeat,
                      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // --------------------------------
              // 🔹 LAYOUT 2 — Two stacked
              // --------------------------------
              const OptionCard(
                title: "Import from Insta",
                icon: Icons.camera_alt,
                colors: [Color(0xFFFF3E8E), Color(0xFFBC06FF)],
              ),
              const OptionCard(
                title: "Select Pics & Repost",
                icon: Icons.repeat,
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
