import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String appGroupId =
      'group.com.example.instasave'; // iOS App Group
  static const String androidWidgetName = 'HomeWidgetProvider';

  static Future<void> updateWidget({
    required String title,
    required String message,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('title', title);
      await HomeWidget.saveWidgetData<String>('message', message);
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: 'HomeWidget',
      );
    } catch (e) {
      print("Error Updating Widget: $e");
    }
  }

  // Example: Call this when a download finishes
  static Future<void> updateLastDownload(String filename) async {
    await updateWidget(title: 'Last Saved', message: filename);
  }
}
