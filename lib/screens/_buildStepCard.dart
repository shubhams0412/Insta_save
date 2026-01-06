import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TutorialStep {
  final String step;
  final String instruction;
  final IconData icon;

  const TutorialStep({
    required this.step,
    required this.instruction,
    required this.icon,
  });
}

class TutorialScreen extends StatelessWidget {
  final String title;
  final List<TutorialStep>? steps;

  const TutorialScreen({super.key, this.title = "How to Repost?", this.steps});

  // Default steps (How to Repost)
  static const List<TutorialStep> defaultSteps = [
    TutorialStep(
      step: "1",
      instruction:
          "Open Instagram and find the post, reel, or video you want to repost.",
      icon: Icons.search_rounded,
    ),
    TutorialStep(
      step: "2",
      instruction: "Tap on the 'Share' (paper plane) button below the post.",
      icon: Icons.send_rounded,
    ),
    TutorialStep(
      step: "3",
      instruction: "Tap on 'Copy Link' from the options menu.",
      icon: Icons.link_rounded,
    ),
    TutorialStep(
      step: "4",
      instruction: "Return to this app. The post will appear automatically.",
      icon: Icons.check_circle_rounded,
    ),
  ];

  // Specific steps for "Select Pics & Repost"
  static const List<TutorialStep> selectPicsSteps = [
    TutorialStep(
      step: "1",
      instruction: 'Tap on "Select Pics & Repost".',
      icon: Icons.touch_app_rounded,
    ),
    TutorialStep(
      step: "2",
      instruction: "Choose a photo from your phone's gallery.",
      icon: Icons.photo_library_rounded,
    ),
    TutorialStep(
      step: "3",
      instruction: "Preview the photo and make any edits if needed.",
      icon: Icons.edit_rounded,
    ),
    TutorialStep(
      step: "4",
      instruction: "Tap Repost to repost your selected photos.",
      icon: Icons.repeat_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final displaySteps = steps ?? defaultSteps;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
        itemCount: displaySteps.length,
        itemBuilder: (context, index) {
          return _buildStepCard(displaySteps[index]);
        },
      ),
    );
  }

  Widget _buildStepCard(TutorialStep item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF7F7F7,
        ), // Light grey background like in the image
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: "Steps ${item.step}: ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: item.instruction),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
