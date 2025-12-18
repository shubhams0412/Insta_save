import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum DialogType { fetching, processing }

class StatusDialog extends StatelessWidget {
  final DialogType type;
  final VoidCallback? onButtonClick;
  final double? progress; // 0.0 to 1.0

  const StatusDialog({
    super.key,
    required this.type,
    this.onButtonClick,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFetching = type == DialogType.fetching;

    final String title = isFetching ? "Fetching Media Info" : "Processing Your Post..";
    final String subtitle = isFetching
        ? "Please wait while we retrieve the information..."
        : "We're preparing your content to repost. This may take a few moments depending on the video length.";

    final String assetName = isFetching
        ? "assets/FetchingMedia.json"
        : "assets/PreparingPreview.json";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Lottie Animation
            SizedBox(
              height: 120,
              width: 120,
              child: Lottie.asset(assetName, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),

            // 2. Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: "InstaFont",
              ),
            ),
            const SizedBox(height: 12),

            // ✅ UNIFIED PROGRESS BAR (Always Below Title)
            // If it's Fetching or Processing, we show the bar here.
            _buildProgressBar(),
            const SizedBox(height: 16),

            // 3. Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // 4. Bottom Action
            // Fetching: Empty (Progress is now up top)
            // Processing: "Got it" Button
            if (!isFetching)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onButtonClick ?? () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Got it, notify me",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        minHeight: 6,
        value: progress, // ✅ If null, it animates. If value, it's determinate.
        backgroundColor: const Color(0xFFF0F0F0),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
      ),
    );
  }
}