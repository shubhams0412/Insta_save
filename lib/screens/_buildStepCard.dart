import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  // Data for the steps
  final List<Map<String, dynamic>> _steps = const [
    {
      "step": "Step 1",
      "instruction": "Open Instagram and find the post, reel, or video you want to repost.",
      "icon": Icons.search,
    },
    {
      "step": "Step 2",
      "instruction": "Tap on the 'Share' (paper plane) button below the post.",
      "icon": Icons.send_outlined, // Instagram style share icon
    },
    {
      "step": "Step 3",
      "instruction": "Tap on 'Copy Link' from the options menu.",
      "icon": Icons.link,
    },
    {
      "step": "Step 4",
      "instruction": "Return to this app. The post will appear automatically.",
      "icon": Icons.download_done_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Prevents Material 3 tint
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "How to Repost?",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final item = _steps[index];
          return _buildStepCard(
            step: item['step'],
            instruction: item['instruction'],
            icon: item['icon'],
            isLast: index == _steps.length - 1,
          );
        },
      ),
    );
  }

  /// A reusable widget to build the step cards
  Widget _buildStepCard({
    required String step,
    required String instruction,
    required IconData icon,
    bool isLast = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50, // Very subtle grey
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200), // Subtle border
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Icon Bubble
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(icon, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 16),

          // 2. Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent, // Accent color for "Step X"
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  instruction,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4, // Better line height for reading
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}