import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- HELPER TO OPEN LOGIN ---
Future<bool> openInstaLogin(BuildContext context) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const InstagramLoginWebView()),
  );
  return result == true;
}

class InstagramLoginWebView extends StatefulWidget {
  const InstagramLoginWebView({super.key});

  @override
  State<InstagramLoginWebView> createState() => _InstagramLoginWebViewState();
}

class _InstagramLoginWebViewState extends State<InstagramLoginWebView>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;

  // UI State
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasHandledSuccess = false;

  // Custom Overlay States
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _errorMessage = "Please check your internet connection.";
  String _errorTitle = "Connection Error";

  // Constants
  static const String _instagramAuthUrl =
      "https://www.instagram.com/accounts/login/";

  @override
  void initState() {
    super.initState();
    _setupWebView();
  }

  void _setupWebView() {
    // Basic WebViewController setup
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36",
      ) // Helps avoid some login blocks
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _showErrorOverlay = false; // Hide error on new load
              });
            }
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            // Check logic on finish
            _checkLoginSuccess(url);
          },
          onWebResourceError: (WebResourceError error) {
            // Handle connection errors
            if (error.errorType == WebResourceErrorType.connect ||
                error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout) {
              if (mounted) {
                setState(() {
                  _errorTitle = "Connection Error";
                  _errorMessage =
                      "Unable to load Instagram. Please check your internet connection.";
                  _showErrorOverlay = true;
                  _isLoading = false;
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Basic check if we are navigating within Instagram
            if (url.contains("instagram.com/")) {
              // Delay check slightly to allow cookies to set
              Future.delayed(
                const Duration(seconds: 1),
                () => _checkLoginSuccess(request.url),
              );
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_instagramAuthUrl));

    // Clear cookies on start to ensure fresh login attempt if needed
    WebViewCookieManager().clearCookies();
  }

  // --- LOGIC: Check Cookies for 'sessionid' ---
  Future<void> _checkLoginSuccess(String currentUrl) async {
    if (_hasHandledSuccess) return;

    // Swift Logic: Check if URL contains instagram.com AND NOT login/signup
    final url = currentUrl.toLowerCase();
    if (url.contains("instagram.com/") &&
        !url.contains("/accounts/login") &&
        !url.contains("/accounts/signup")) {
      // Check Cookies via JavaScript execution since WebViewCookieManager.getCookies is not available
      try {
        final Object result = await _controller.runJavaScriptReturningResult(
          'document.cookie',
        );
        final String cookieString = result.toString();

        if (cookieString.contains('sessionid') ||
            cookieString.contains('csrftoken')) {
          _handleLoginSuccess();
        }
      } catch (e) {
        debugPrint("Error reading cookies: $e");
      }
    }
  }

  void _handleLoginSuccess() async {
    if (_hasHandledSuccess) return;
    _hasHandledSuccess = true;

    // 1. Save to SharedPreferences (Equivalent to UserDefaults)
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{'isInstagramLoggedIn', 'instagramLoginDate'},
      ),
    );
    await prefs.setBool('isInstagramLoggedIn', true);
    await prefs.setString(
      'instagramLoginDate',
      DateTime.now().toIso8601String(),
    );

    // 2. Show Success Overlay
    if (mounted) {
      setState(() {
        _showSuccessOverlay = true;
      });

      // 3. Auto Dismiss after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  void _retryLoading() {
    setState(() {
      _showErrorOverlay = false;
      _isLoading = true;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // --- CUSTOM APP BAR ---
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close Button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      // Title
                      const Text(
                        "Login to Instagram",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Spacer to balance row
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // --- PROGRESS BAR ---
                if (_isLoading && _progress < 1.0)
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF2558),
                    ), // Matches Swift Hex
                    minHeight: 2,
                  ),

                // --- WEBVIEW ---
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            ),

            // --- LOADING INDICATOR (Center) ---
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF2558)),
              ),

            // --- SUCCESS OVERLAY ---
            if (_showSuccessOverlay) _buildSuccessOverlay(),

            // --- ERROR OVERLAY ---
            if (_showErrorOverlay) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  // --- UI: Success Overlay (Matches Swift Design) ---
  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: MediaQuery.of(context).size.width - 64,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient Icon Container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFCD2BF6),
                          Color(0xFF14BEFC),
                        ], // Matches Swift Hex
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCD2BF6).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Authorization Successful!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your account is securely connected. You are ready to fetch media.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF908C9F), // Matches Swift Hex
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- UI: Error Overlay (Matches Swift Design) ---
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: MediaQuery.of(context).size.width - 64,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error Icon Container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF4B4F),
                          Color(0xFFFF6B9D),
                        ], // Matches Swift Hex
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4B4F).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF908C9F),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Retry Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _retryLoading,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF4B4F), Color(0xFFFF6B9D)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Text(
                            "Try Again",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Close Button
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Color(0xFF908C9F),
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
