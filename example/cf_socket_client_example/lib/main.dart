import 'package:cf_socket_client/cf_socket_client.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CfSocketClientDemoApp());
}

class CfSocketClientDemoApp extends StatelessWidget {
  const CfSocketClientDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cf_socket_client demo',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final _urlCtrl = TextEditingController(
    text: 'wss://localhost:8000/connection/websocket',
  );
  final _tokenCtrl = TextEditingController();
  final _channelCtrl = TextEditingController(text: 'chat');

  CentrifugalSocket? _socket;
  ConnectStatus _status = ConnectStatus.none;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _rebuildSocket();
  }

  void _rebuildSocket() {
    _socket?.dispose();
    _socket = CentrifugalSocket(
      config: CentrifugeSocketConfig(
        url: _urlCtrl.text.trim(),
        onSubscribe: (channel) async {
          _addLog('onSubscribe: $channel (gọi API backend nếu cần)');
        },
      ),
    );
    _socket!.initCentrifugalClient();
    _socket!.connectStatus.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
  }

  void _addLog(String line) {
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String()}  $line');
      if (_log.length > 200) _log.removeLast();
    });
  }

  Future<void> _connect() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _addLog('Thiếu JWT — dán connection token từ Centrifugo/backend.');
      return;
    }
    _rebuildSocket();
    await _socket!.connect(token);
    _addLog('connect() đã gọi xong.');
  }

  Future<void> _disconnect() async {
    await _socket?.disconnect();
    _addLog('disconnect()');
  }

  void _subscribe() {
    final ch = _channelCtrl.text.trim();
    if (ch.isEmpty) return;
    _socket?.subscribe(ch, (data) {
      _addLog('[$ch] $data');
    });
  }

  void _unsubscribe() {
    final ch = _channelCtrl.text.trim();
    if (ch.isEmpty) return;
    _socket?.unsubscribe(ch);
    _addLog('unsubscribe("$ch")');
  }

  Future<void> _emit() async {
    final ch = _channelCtrl.text.trim();
    if (ch.isEmpty) return;
    await _socket?.emit(ch, {
      'text': 'hello from Flutter',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _addLog('emit("$ch")');
  }

  Future<void> _emitWithAck() async {
    final ch = _channelCtrl.text.trim();
    if (ch.isEmpty) return;
    final result = await _socket!.emitWithAck(
      ch,
      {'action': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch},
    );
    _addLog('emitWithAck → $result');
  }

  @override
  void dispose() {
    _socket?.dispose();
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('cf_socket_client demo')),
      body: ListView(
        physics: ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Trạng thái: $_status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'WebSocket URL',
              border: OutlineInputBorder(),
              helperText: 'Ví dụ: wss://host/connection/websocket',
            ),
            onSubmitted: (_) => setState(_rebuildSocket),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenCtrl,
            decoration: const InputDecoration(
              labelText: 'Connection JWT',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _channelCtrl,
            decoration: const InputDecoration(
              labelText: 'Kênh (channel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _connect, child: const Text('Connect')),
              OutlinedButton(
                onPressed: _disconnect,
                child: const Text('Disconnect'),
              ),
              FilledButton.tonal(
                onPressed: _subscribe,
                child: const Text('Subscribe'),
              ),
              OutlinedButton(
                onPressed: _unsubscribe,
                child: const Text('Unsubscribe'),
              ),
              FilledButton.tonal(
                onPressed: _emit,
                child: const Text('Emit'),
              ),
              OutlinedButton(
                onPressed: _emitWithAck,
                child: const Text('Emit + ACK'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Log', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._log.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText(l, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
