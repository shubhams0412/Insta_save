import 'package:flutter/material.dart';

// You can save this as 'tutorial_screen.dart'
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // iOS-style back arrow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "How to Repost a Post?",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0, // No shadow
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStepCard(
              step: "Step 1:",
              instruction: "Find a post on Instagram",
            ),
            _buildStepCard(
              step: "Step 2:",
              instruction: "Tap on the share button below the post",
            ),
            _buildStepCard(
              step: "Step 3:",
              instruction: "Tap on \"Copy Link\".",
            ),
            _buildStepCard(
              step: "Step 4:",
              instruction:
              "Come back to this app, allow paste and then post will appear.",
            ),
          ],
        ),
      ),
    );
  }

  /// A reusable widget to build the step cards
  Widget _buildStepCard(
      {required String step, required String instruction}) {
    return Container(
      width: double.infinity, // Take full width
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      margin: const EdgeInsets.only(bottom: 12), // Space between cards
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Light gray background
        borderRadius: BorderRadius.circular(12), // Rounded corners
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the top
        children: [
          Text(
            step,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600, // Bolder text for the step
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          // Use Expanded so the instruction text wraps correctly
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}