import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 4.0;

  Future<void> _redirectToStore() async {
    final Uri url = Uri.parse(Constants.Play_Store_URL);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String get _ratingText {
    return "Excellent! ⭐";
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title with Gradient
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFA8F1A),
                      Color(0xFFFA2986),
                      Color(0xFFC405E1),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    "Rate Your Save",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Slide to rate your experience",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // Emoji Image
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFE8FF),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/emoji.png',
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Custom Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: const Color(0xFFE9EEF5),
                          trackHeight: 9,
                          thumbColor: Colors.black,
                          thumbShape: const CustomSliderThumbShape(
                            thumbRadius: 14,
                          ),
                          trackShape: const GradientRectSliderTrackShape(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFB05C2),
                                Color(0xFFFA2A84),
                                Color(0xFFFDAD2B),
                              ],
                            ),
                          ),
                        ),
                        child: Slider(
                          value: _rating,
                          min: 1,
                          max: 5,
                          onChanged: (value) {
                            setState(() {
                              _rating = value;
                            });
                          },
                          onChangeEnd: (value) async {
                            await _redirectToStore();
                            if (mounted) {
                              Navigator.of(context).pop(_rating);
                            }
                          },
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSliderLabel("1"),
                            _buildSliderLabel("2"),
                            _buildSliderLabel("3"),
                            _buildSliderLabel("4"),
                            _buildSliderLabel("5"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Dynamic Rating Text
                Text(
                  _ratingText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _redirectToStore();
                      if (mounted) {
                        Navigator.of(context).pop(_rating);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      "Submit Feedback",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Skip Button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Skip for now",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
    );
  }
}

class GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final LinearGradient gradient;

  const GradientRectSliderTrackShape({required this.gradient});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    if (sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    final Paint activePaint = Paint()
      ..shader = gradient.createShader(trackRect);
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!;

    final double thumbPos = thumbCenter.dx;

    // Paint inactive track
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackRect.height / 2)),
      inactivePaint,
    );

    // Paint active track
    final Rect activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbPos,
      trackRect.bottom,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        activeRect,
        Radius.circular(trackRect.height / 2),
      ),
      activePaint,
    );
  }
}

class CustomSliderThumbShape extends SliderComponentShape {
  final double thumbRadius;

  const CustomSliderThumbShape({this.thumbRadius = 12.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw shadow
    final Path path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: thumbRadius));
    canvas.drawShadow(path, Colors.black, 2, true);

    // Outer white circle
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius, whitePaint);

    // Inner black circle
    final Paint blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius * 0.7, blackPaint);
  }
}
