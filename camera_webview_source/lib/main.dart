import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String cameraCenterUrl =
    'http://192.168.17.170:3092/live.html?app=1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GitCameraViewerApp());
}

class GitCameraViewerApp extends StatelessWidget {
  const GitCameraViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GIT Camera Center',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF04121E),
      ),
      home: const CameraWebViewPage(),
    );
  }
}

class CameraWebViewPage extends StatefulWidget {
  const CameraWebViewPage({super.key});

  @override
  State<CameraWebViewPage> createState() => _CameraWebViewPageState();
}

class _CameraWebViewPageState extends State<CameraWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;

  static const String _mobileScrollFixJs = r'''
(() => {
  const STYLE_ID = 'git-android-webview-scroll-fix';

  let style = document.getElementById(STYLE_ID);
  if (!style) {
    style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = `
      html,
      body {
        width: 100% !important;
        min-height: 100% !important;
        height: auto !important;
        max-height: none !important;
        overflow-x: hidden !important;
        overflow-y: auto !important;
        overscroll-behavior-y: auto !important;
        touch-action: pan-y pinch-zoom !important;
        -webkit-overflow-scrolling: touch !important;
      }

      body {
        position: static !important;
      }

      .page,
      .main,
      .app-main,
      .git-main,
      .page-inner,
      .content,
      .page-content,
      .dashboard-content,
      .dashboard-page,
      .live-page,
      .live-content,
      .playback-page,
      .playback-content,
      .library-page,
      .alerts-page,
      .settings-page,
      .settings-layout,
      .ai-page,
      .ai-layout,
      .assistant-page,
      .assistant-layout,
      .assistant-grid {
        min-height: 0 !important;
        height: auto !important;
        max-height: none !important;
        overflow-y: visible !important;
      }

      .table-wrap,
      .table-card,
      .channel-table-wrap {
        max-width: 100% !important;
        overflow-x: auto !important;
        -webkit-overflow-scrolling: touch !important;
      }

      dialog,
      .modal,
      .modal-card,
      .dialog {
        max-height: 88dvh !important;
        overflow-y: auto !important;
        -webkit-overflow-scrolling: touch !important;
      }
    `;
    document.head.appendChild(style);
  } else {
    document.head.appendChild(style);
  }

  const forceScrollable = (el) => {
    if (!el) return;
    el.style.setProperty('height', 'auto', 'important');
    el.style.setProperty('max-height', 'none', 'important');
    el.style.setProperty('overflow-y', 'auto', 'important');
    el.style.setProperty('-webkit-overflow-scrolling', 'touch', 'important');
  };

  document.documentElement.style.setProperty('height', 'auto', 'important');
  document.documentElement.style.setProperty('min-height', '100%', 'important');
  document.documentElement.style.setProperty('max-height', 'none', 'important');
  document.documentElement.style.setProperty('overflow-y', 'auto', 'important');
  document.documentElement.style.setProperty('overflow-x', 'hidden', 'important');
  document.documentElement.style.setProperty('touch-action', 'pan-y pinch-zoom', 'important');

  document.body.style.setProperty('height', 'auto', 'important');
  document.body.style.setProperty('min-height', '100%', 'important');
  document.body.style.setProperty('max-height', 'none', 'important');
  document.body.style.setProperty('overflow-y', 'auto', 'important');
  document.body.style.setProperty('overflow-x', 'hidden', 'important');
  document.body.style.setProperty('position', 'static', 'important');
  document.body.style.setProperty('touch-action', 'pan-y pinch-zoom', 'important');

  const candidates = document.querySelectorAll(
    '.page, .main, .app-main, .git-main, .page-inner, .content, .page-content, ' +
    '.dashboard-content, .dashboard-page, .live-page, .live-content, ' +
    '.playback-page, .playback-content, .library-page, .alerts-page, ' +
    '.settings-page, .settings-layout, .ai-page, .ai-layout, ' +
    '.assistant-page, .assistant-layout, .assistant-grid'
  );

  candidates.forEach((el) => {
    el.style.setProperty('height', 'auto', 'important');
    el.style.setProperty('max-height', 'none', 'important');
    el.style.setProperty('overflow-y', 'visible', 'important');
    el.style.setProperty('min-height', '0', 'important');
  });

  forceScrollable(document.scrollingElement);

  window.dispatchEvent(new Event('resize'));
  return true;
})();
''';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF04121E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _hasError = false;
              _progress = 0;
            });
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _progress = 100);

            await _applyMobileScrollFix();

            // Một số trang Camera Center dựng shell/layout sau onPageFinished.
            // Áp lại để CSS/JS của trang không khóa body sau đó.
            unawaited(
              Future<void>.delayed(
                const Duration(milliseconds: 500),
                _applyMobileScrollFix,
              ),
            );
            unawaited(
              Future<void>.delayed(
                const Duration(milliseconds: 1500),
                _applyMobileScrollFix,
              ),
            );
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            if (!mounted) return;
            setState(() => _hasError = true);
          },
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(cameraCenterUrl));
  }

  Future<void> _applyMobileScrollFix() async {
    try {
      await _controller.runJavaScript(_mobileScrollFixJs);
    } catch (_) {
      // Không làm gián đoạn WebView nếu trang đang chuyển route/reload.
    }
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleBack();
        if (shouldExit && context.mounted) {
          exit(0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100)
                LinearProgressIndicator(value: _progress / 100),
              if (_hasError)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF04121E),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_outlined, size: 52),
                            const SizedBox(height: 14),
                            const Text(
                              'Không kết nối được GIT Camera Center',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Hãy kiểm tra điện thoại đang cùng mạng LAN với server 192.168.17.170.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _hasError = false);
                                _controller.reload();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
