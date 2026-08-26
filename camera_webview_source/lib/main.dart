import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String defaultLanBaseUrl = 'http://192.168.17.170:3092';
const String startPath = '/live.html?app=1';

enum ConnectionMode { auto, lan, remote }

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
  bool _checkingConnection = true;

  String _lanBaseUrl = defaultLanBaseUrl;
  String _remoteBaseUrl = '';
  String _activeBaseUrl = defaultLanBaseUrl;
  ConnectionMode _mode = ConnectionMode.auto;

  static const String _mobileScrollFixJs = r'''
(() => {
  const STYLE_ID = 'git-android-webview-scroll-fix';
  let style = document.getElementById(STYLE_ID);

  if (!style) {
    style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = `
      html, body {
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

      body { position: static !important; }

      .page, .main, .app-main, .git-main, .page-inner, .content,
      .page-content, .dashboard-content, .dashboard-page, .live-page,
      .live-content, .playback-page, .playback-content, .library-page,
      .alerts-page, .settings-page, .settings-layout, .ai-page,
      .ai-layout, .assistant-page, .assistant-layout, .assistant-grid,
      .anpr-page, .anpr-enterprise-page {
        min-height: 0 !important;
        height: auto !important;
        max-height: none !important;
        overflow-y: visible !important;
      }

      .table-wrap, .table-card, .channel-table-wrap {
        max-width: 100% !important;
        overflow-x: auto !important;
        -webkit-overflow-scrolling: touch !important;
      }

      dialog, .modal, .modal-card, .dialog {
        max-height: 88dvh !important;
        overflow-y: auto !important;
        -webkit-overflow-scrolling: touch !important;
      }
    `;
    document.head.appendChild(style);
  } else {
    document.head.appendChild(style);
  }

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
            setState(() {
              _progress = 100;
              _checkingConnection = false;
            });

            await _applyMobileScrollFix();

            unawaited(Future<void>.delayed(
              const Duration(milliseconds: 500),
              _applyMobileScrollFix,
            ));
            unawaited(Future<void>.delayed(
              const Duration(milliseconds: 1500),
              _applyMobileScrollFix,
            ));
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _checkingConnection = false;
            });
          },
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      );

    unawaited(_loadSettingsAndConnect());
  }

  Future<void> _loadSettingsAndConnect() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString('connection_mode') ?? 'auto';
    final savedLan = prefs.getString('lan_base_url') ?? defaultLanBaseUrl;
    final savedRemote = prefs.getString('remote_base_url') ?? '';

    if (!mounted) return;

    setState(() {
      _lanBaseUrl = _normalizeBaseUrl(savedLan, defaultLanBaseUrl);
      _remoteBaseUrl = _normalizeBaseUrl(savedRemote, '');
      _mode = ConnectionMode.values.firstWhere(
        (item) => item.name == savedMode,
        orElse: () => ConnectionMode.auto,
      );
      _checkingConnection = true;
    });

    await _connectByMode();
  }

  String _normalizeBaseUrl(String value, String fallback) {
    var text = value.trim();
    if (text.isEmpty) return fallback;

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }

    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }

    return text;
  }

  Uri _pageUri(String baseUrl) => Uri.parse('$baseUrl$startPath');

  Future<bool> _probe(String baseUrl) async {
    if (baseUrl.trim().isEmpty) return false;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..badCertificateCallback = (_, __, ___) => true;

    try {
      for (final path in const ['/api/health', '/api/system/status', '/']) {
        try {
          final request = await client.getUrl(Uri.parse('$baseUrl$path'));
          request.headers.set(HttpHeaders.acceptHeader, 'application/json,text/html');
          final response = await request.close().timeout(const Duration(seconds: 4));
          await response.drain<void>();

          if (response.statusCode >= 200 && response.statusCode < 500) {
            return true;
          }
        } catch (_) {
          // Thử endpoint tiếp theo.
        }
      }

      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _connectByMode() async {
    if (!mounted) return;

    setState(() {
      _checkingConnection = true;
      _hasError = false;
    });

    String? selected;

    switch (_mode) {
      case ConnectionMode.lan:
        selected = _lanBaseUrl;
        break;

      case ConnectionMode.remote:
        if (_remoteBaseUrl.isNotEmpty) {
          selected = _remoteBaseUrl;
        }
        break;

      case ConnectionMode.auto:
        if (await _probe(_lanBaseUrl)) {
          selected = _lanBaseUrl;
        } else if (_remoteBaseUrl.isNotEmpty && await _probe(_remoteBaseUrl)) {
          selected = _remoteBaseUrl;
        }
        break;
    }

    if (!mounted) return;

    if (selected == null || selected.isEmpty) {
      setState(() {
        _checkingConnection = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _activeBaseUrl = selected!;
      _checkingConnection = false;
    });

    await _controller.loadRequest(_pageUri(selected));
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

  String get _connectionLabel {
    if (_activeBaseUrl == _lanBaseUrl) return 'LAN';
    if (_remoteBaseUrl.isNotEmpty && _activeBaseUrl == _remoteBaseUrl) return 'REMOTE';
    return _mode.name.toUpperCase();
  }

  Future<void> _openConnectionSettings() async {
    final lanController = TextEditingController(text: _lanBaseUrl);
    final remoteController = TextEditingController(text: _remoteBaseUrl);
    var tempMode = _mode;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF071B2B),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kết nối Camera Center',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Auto: ưu tiên LAN, khi ra ngoài mạng sẽ chuyển sang Remote.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<ConnectionMode>(
                      segments: const [
                        ButtonSegment(
                          value: ConnectionMode.auto,
                          label: Text('Auto'),
                          icon: Icon(Icons.sync_alt),
                        ),
                        ButtonSegment(
                          value: ConnectionMode.lan,
                          label: Text('LAN'),
                          icon: Icon(Icons.wifi),
                        ),
                        ButtonSegment(
                          value: ConnectionMode.remote,
                          label: Text('Remote'),
                          icon: Icon(Icons.public),
                        ),
                      ],
                      selected: {tempMode},
                      onSelectionChanged: (values) {
                        setSheetState(() => tempMode = values.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lanController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ LAN',
                        hintText: 'http://192.168.17.170:3092',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remoteController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ Remote',
                        hintText: 'https://camera.tenmien.com hoặc http://100.x.x.x:3092',
                        helperText: 'Dùng Tailscale/VPN hoặc HTTPS public domain.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Lưu và kết nối lại'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    final prefs = await SharedPreferences.getInstance();
    final newLan = _normalizeBaseUrl(lanController.text, defaultLanBaseUrl);
    final newRemote = _normalizeBaseUrl(remoteController.text, '');

    await prefs.setString('connection_mode', tempMode.name);
    await prefs.setString('lan_base_url', newLan);
    await prefs.setString('remote_base_url', newRemote);

    if (!mounted) return;

    setState(() {
      _mode = tempMode;
      _lanBaseUrl = newLan;
      _remoteBaseUrl = newRemote;
    });

    await _connectByMode();
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

              if (_progress < 100 && !_checkingConnection)
                LinearProgressIndicator(value: _progress / 100),

              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: const Color(0xD9071B2B),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _openConnectionSettings,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _connectionLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_checkingConnection)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0xFF04121E),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 14),
                          Text('Đang tìm Camera Center...'),
                          SizedBox(height: 5),
                          Text(
                            'Ưu tiên LAN, sau đó Remote',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_hasError && !_checkingConnection)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF04121E),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 54),
                            const SizedBox(height: 14),
                            const Text(
                              'Không kết nối được GIT Camera Center',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _remoteBaseUrl.isEmpty
                                  ? 'LAN không truy cập được và chưa cấu hình địa chỉ Remote.'
                                  : 'Không truy cập được cả LAN và Remote. Kiểm tra VPN/Tailscale, tên miền hoặc port của server.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: _connectByMode,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Thử lại'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _openConnectionSettings,
                                  icon: const Icon(Icons.settings_ethernet),
                                  label: const Text('Cấu hình Remote'),
                                ),
                              ],
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
