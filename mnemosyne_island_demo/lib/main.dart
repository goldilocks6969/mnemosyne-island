import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

const _red = Color(0xFFFF454F);
const _green = Color(0xFF4FDE82);
const _yellow = Color(0xFFFFC43D);
const _paper = Color(0xFFF3F2EE);

enum DemoPhase {
  recording('recording', 'Recording', '[rec]', 'Ring + elapsed time', _red),
  processing('processing', 'Processing', '[tinkering]', 'Transcribing your speech', _red),
  working('working', 'Agent working', '[working]', 'Instinct', _green),
  approval('approval', 'Needs approval', '[approve]', 'Instinct + Review', _yellow);

  const DemoPhase(this.value, this.label, this.tag, this.detail, this.color);
  final String value;
  final String label;
  final String tag;
  final String detail;
  final Color color;

  static DemoPhase? fromValue(Object? value) {
    for (final phase in values) {
      if (phase.value == value) return phase;
    }
    return null;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mnemosyne',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _paper,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _red,
            brightness: Brightness.light,
          ).copyWith(primary: const Color(0xFF171717), surface: _paper),
          appBarTheme: const AppBarTheme(backgroundColor: _paper),
        ),
        home: const IslandDemo(),
      );
}

class IslandDemo extends StatefulWidget {
  const IslandDemo({super.key});

  @override
  State<IslandDemo> createState() => _IslandDemoState();
}

class _IslandDemoState extends State<IslandDemo>
    with WidgetsBindingObserver {
  static const _channel =
      MethodChannel('one.antimattr.mnemosyne/live_activity');
  DemoPhase? _phase;
  bool _active = false;
  bool _enabled = false;
  bool _ready = false;
  bool _busy = false;
  bool _refreshing = false;
  bool _reviewOpen = false;
  bool _supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openReview') {
        _openReview();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
      await _consumeReview();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _consumeReview();
    }
  }

  void _readStatus(Map<Object?, Object?> status) {
    _active = status['active'] == true;
    _enabled = status['enabled'] == true;
    _phase = _active ? DemoPhase.fromValue(status['phase']) : null;
    _ready = true;
  }

  Future<void> _refresh() async {
    if (!mounted || _busy || _refreshing) return;
    if (!_supported) {
      setState(() => _ready = true);
      return;
    }
    setState(() => _refreshing = true);
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('getStatus');
      if (!mounted) return;
      if (result == null) throw const FormatException('No activity status returned.');
      setState(() {
        _readStatus(result);
        _error = null;
      });
    } on MissingPluginException {
      if (mounted) setState(() { _supported = false; _ready = true; });
    } catch (error) {
      if (mounted) setState(() { _ready = true; _error = _describe(error); });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _consumeReview() async {
    if (!_supported || !mounted) return;
    try {
      final pending = await _channel.invokeMethod<bool>('consumePendingReview');
      if (pending == true && mounted) _openReview();
    } on MissingPluginException {
      // The preview can still open its own review screen without native code.
    } on PlatformException {
      // An unavailable pending link must not interrupt the demo controls.
    }
  }

  Future<void> _change(DemoPhase? next) async {
    if (_busy || _refreshing || !_ready || !_supported) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        next == null ? 'stop' : 'setState',
        next == null ? null : <String, String>{'phase': next.value},
      );
      if (!mounted) return;
      if (result == null) throw const FormatException('No activity status returned.');
      setState(() => _readStatus(result));
    } on MissingPluginException {
      if (mounted) setState(() => _supported = false);
    } catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(Object error) {
    if (error is PlatformException) {
      return error.message ?? 'The iPhone could not update this activity. Try again.';
    }
    return 'Could not read the Live Activity status. Tap refresh and try again.';
  }

  Future<void> _openReview() async {
    if (!mounted || _reviewOpen) return;
    _reviewOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const InstinctReview()),
      );
    } finally {
      _reviewOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canChange = _supported && _ready && _enabled && !_busy && !_refreshing;
    final statusLabel = !_ready
        ? 'Checking your iPhone…'
        : !_supported
            ? 'Open this app on your iPhone'
            : !_enabled
                ? 'Live Activities are disabled'
                : _active
                    ? '${_phase?.label ?? 'Activity'} · active'
                    : 'Ready to start';
    return Scaffold(
      appBar: AppBar(
        title: const Text('antimattr.', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1)),
        actions: [
          IconButton(
            tooltip: 'Refresh activity status',
            onPressed: _busy || _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                const Text('MNEMOSYNE / ISLAND DEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.black54)),
                const SizedBox(height: 12),
                const Text('Your agents.\nAt a glance.', style: TextStyle(fontSize: 36, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -1.6)),
                const SizedBox(height: 16),
                const Text('Four states. One Live Activity.\nChoose a state, then go Home to see the Island.', style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black54)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: Column(children: [
                    IslandPreview(phase: _phase, active: _active),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_busy || _refreshing) ...[
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(child: Text(_busy ? 'Updating activity…' : statusLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 22),
                if (!_supported)
                  const _Notice('The real Island controls are available in the iPhone build. This app does not simulate a successful system activity.'),
                if (_ready && _supported && !_enabled)
                  const _Notice('Enable Live Activities for Mnemosyne in iPhone Settings, then return here and tap refresh.'),
                if (_error != null)
                  _Notice(_error!, isError: true),
                for (final phase in DemoPhase.values) ...[
                  _StateButton(phase: phase, selected: _active && _phase == phase, onTap: canChange ? () => _change(phase) : null),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 2),
                TextButton.icon(
                  onPressed: _supported && _ready && _active && !_busy && !_refreshing ? () => _change(null) : null,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('End Live Activity'),
                ),
                if (_phase == DemoPhase.approval) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _openReview, child: const Text('Open Instinct review demo')),
                ],
                const SizedBox(height: 24),
                const Text('DEMO ONLY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                const Text('No microphone is recording and no agent is running. These controls demonstrate the four status views. Long-press the Island to expand it.', style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black54)),
                const SizedBox(height: 10),
                const Text('Motion above is an in-app concept preview. iOS controls Live Activity animation; continuous ring spins and waves are not promised on the system Island.', style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFE8E7) : const Color(0xFFE7E5DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
      );
}

class _StateButton extends StatelessWidget {
  const _StateButton({required this.phase, required this.selected, required this.onTap});
  final DemoPhase phase;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: Material(
          color: selected ? const Color(0xFF171717) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: selected ? Colors.white12 : const Color(0xFF171717), borderRadius: BorderRadius.circular(11)),
                  child: Center(child: CustomPaint(size: const Size(22, 22), painter: GlyphPainter(phase, 0))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(phase.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black)),
                  const SizedBox(height: 3),
                  Text(phase.detail, style: TextStyle(fontSize: 12, color: selected ? Colors.white60 : Colors.black54)),
                ])),
                Icon(selected ? Icons.check_circle : Icons.arrow_outward_rounded, size: 18, color: selected ? phase.color : Colors.black38),
              ]),
            ),
          ),
        ),
      );
}

class IslandPreview extends StatefulWidget {
  const IslandPreview({super.key, required this.phase, required this.active});
  final DemoPhase? phase;
  final bool active;

  @override
  State<IslandPreview> createState() => _IslandPreviewState();
}

class _IslandPreviewState extends State<IslandPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant IslandPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    if (!MediaQuery.disableAnimationsOf(context) && widget.active && widget.phase != DemoPhase.approval) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() { _motion.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Concept preview: ${widget.active ? widget.phase?.label ?? 'active' : 'idle'}',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 272, height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
            child: Row(children: [
              SizedBox(width: 26, height: 24, child: widget.active && widget.phase != null
                  ? AnimatedBuilder(animation: _motion, builder: (_, child) => CustomPaint(painter: GlyphPainter(widget.phase!, _motion.value)))
                  : const SizedBox.shrink()),
              const Spacer(),
              Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF11141B), shape: BoxShape.circle)),
              const Spacer(),
              if (widget.active && widget.phase != null) ...[
                if (widget.phase == DemoPhase.working || widget.phase == DemoPhase.recording) ...[
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: widget.phase!.color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                Text(widget.phase!.tag, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500, color: widget.phase == DemoPhase.working ? Colors.white : widget.phase!.color)),
              ] else const SizedBox(width: 66),
            ]),
          ),
        ),
      );
}

class GlyphPainter extends CustomPainter {
  GlyphPainter(this.phase, this.progress);
  final DemoPhase phase;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    switch (phase) {
      case DemoPhase.recording:
        canvas.translate(12, 12);
        canvas.rotate(32 * math.pi / 180);
        final width = 3 + 11.16 * math.cos(progress * math.pi * 2).abs();
        canvas.drawOval(Rect.fromCenter(center: const Offset(2.88, 0.96), width: width, height: 18.48), stroke..color = Colors.white70..strokeWidth = 1.56);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: width, height: 18.48), stroke..color = Colors.white..strokeWidth = 2.88);
      case DemoPhase.processing:
        final path = Path();
        for (var i = 0; i <= 48; i++) {
          final x = 1.44 + i * 21.12 / 48;
          final envelope = math.sin(i / 48 * math.pi);
          final y = 12 - math.sin(i / 48 * math.pi * 4 - progress * math.pi * 4) * 8.4 * envelope;
          if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
        }
        canvas.drawPath(path, stroke..strokeWidth = 1.5);
      case DemoPhase.working:
        canvas.translate(math.sin(progress * math.pi * 2) * 0.6, -math.sin(progress * math.pi * 2) * 0.6);
        final cursor = Path()..moveTo(6, 1.92)..lineTo(21.12, 13.92)..lineTo(14.16, 15.12)..lineTo(17.28, 21.6)..lineTo(13.44, 23.28)..lineTo(10.32, 16.8)..lineTo(5.76, 21.6)..close();
        canvas.drawPath(cursor, Paint()..color = Colors.white);
        final motionStrokes = Path()..moveTo(0.72, 10.08)..lineTo(3.12, 11.76)..moveTo(0.48, 15.36)..lineTo(2.88, 15.36);
        canvas.drawPath(motionStrokes, stroke..color = Colors.white70..strokeWidth = 1);
      case DemoPhase.approval:
        canvas.drawCircle(const Offset(12, 12), 10.5, Paint()..color = _yellow);
        stroke.color = Colors.black;
        stroke.strokeWidth = 2.3;
        canvas.drawLine(const Offset(12, 6), const Offset(12, 13), stroke);
        canvas.drawCircle(const Offset(12, 17.5), 1.25, Paint()..color = Colors.black);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlyphPainter oldDelegate) => phase != oldDelegate.phase || progress != oldDelegate.progress;
}

class InstinctReview extends StatelessWidget {
  const InstinctReview({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Instinct')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)), child: CustomPaint(size: const Size(30, 30), painter: GlyphPainter(DemoPhase.working, 0))),
                  const SizedBox(height: 24),
                  const Text('Instinct needs you.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1)),
                  const SizedBox(height: 14),
                  const Text('This is where you’ll review your agent’s request and give it instructions.', style: TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 18),
                  const Text('Demo destination · No real request is pending. Opening this screen does not approve or execute anything.', style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54)),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to demo')),
                ]),
              ),
            ),
          ),
        ),
      );
}
