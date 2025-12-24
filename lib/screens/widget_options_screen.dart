import 'package:flutter/material.dart';

// If you have the file, keep your import.
// If not, I have included the OptionCard class at the bottom of this file.
// import '../widgets/option_card.dart';

class WidgetOptionsScreen extends StatelessWidget {
  const WidgetOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300, // Background for preview contrast
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              // Removes hardcoded width (320) to be responsive
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  // 1. Header Section
                  _WidgetHeader(),

                  SizedBox(height: 24),

                  // 2. The Content Padding
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        // Layout A: Side by Side
                        _RowLayout(),

                        SizedBox(height: 20),
                        Divider(),
                        SizedBox(height: 20),

                        // Layout B: Stacked
                        _ColumnLayout(),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🔹 Extracted Sub-Widgets for Cleanliness
// -----------------------------------------------------------------------------

class _WidgetHeader extends StatelessWidget {
  const _WidgetHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
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
            fontFamily: "Pacifico", // Ensure this font is in pubspec.yaml
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RowLayout extends StatelessWidget {
  const _RowLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildImportButton(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRepostButton(),
        ),
      ],
    );
  }
}

class _ColumnLayout extends StatelessWidget {
  const _ColumnLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
            width: double.infinity,
            child: _buildImportButton()
        ),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: _buildRepostButton()
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 🔹 Helper Methods to Avoid Duplicating Data
// -----------------------------------------------------------------------------

Widget _buildImportButton() {
  return const OptionCard(
    title: "Import from Insta",
    icon: Icons.camera_alt,
    colors: [Color(0xFFFF3E8E), Color(0xFFBC06FF)],
  );
}

Widget _buildRepostButton() {
  return const OptionCard(
    title: "Select Pics & Repost",
    icon: Icons.repeat,
    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
  );
}

// -----------------------------------------------------------------------------
// 🔹 MOCK OPTION CARD (In case you need the implementation)
// -----------------------------------------------------------------------------
class OptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;

  const OptionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100, // Fixed height for consistency
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}