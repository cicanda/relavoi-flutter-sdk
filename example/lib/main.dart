import 'package:flutter/material.dart';
import 'package:relavoi_flutter/relavoi_flutter.dart';

void main() => runApp(const RelavoiSampleApp());

class RelavoiSampleApp extends StatelessWidget {
  const RelavoiSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relavoi Flutter Sample',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Credentials are NOT hardcoded — paste the Bolt Nigeria test key/secret here
  // at runtime. Tenant ID is not a secret, so it is pre-filled.
  final _apiKey = TextEditingController();
  final _apiSecret = TextEditingController();
  final _tenantId =
      TextEditingController(text: 'f656ac1b-3b5d-4af0-8ff1-c4cbc1076144');
  final _agentPhone = TextEditingController(text: '+2347067379297');
  final _customerPhone = TextEditingController(text: '+2348162662319');
  final _userPhone = TextEditingController(text: '+2347067379297');

  final _log = <String>[];
  final _scroll = ScrollController();

  String? _sessionId;
  String? _proxyNumber;
  bool _eventsWired = false;

  void log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    setState(() => _log.add('[$ts] $msg'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  bool _requireInit() {
    if (!Relavoi.isInitialized) {
      log('Tap "Initialize SDK" first');
      return false;
    }
    return true;
  }

  Future<void> _initialize() async {
    if (Relavoi.isInitialized) {
      log('Already initialized');
      return;
    }
    if (_apiKey.text.trim().isEmpty || _apiSecret.text.trim().isEmpty) {
      log('ERROR: paste API key and secret first');
      return;
    }
    try {
      log('Initializing (authenticating against api.relavoi.com)…');
      await Relavoi.initialize(
        apiKey: _apiKey.text.trim(),
        apiSecret: _apiSecret.text.trim(),
        tenantId: _tenantId.text.trim(),
        config: const RelavoiConfig(enableLogging: true),
      );
      log('SDK initialized');
    } catch (e) {
      log('ERROR initialize: $e');
    }
  }

  Future<void> _createSession() async {
    if (!_requireInit()) return;
    try {
      log('Creating session (${_agentPhone.text} → ${_customerPhone.text})…');
      final s = await Relavoi.instance.sessions.create(
        agentPhone: _agentPhone.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        metadata: {'orderId': 'SDK-TEST-001', 'type': 'delivery'},
      );
      _sessionId = s.id;
      _proxyNumber = s.proxyNumber;
      log('Session created: ${s.id}');
      log('  proxy=${s.proxyNumber} state=${s.state.name}');
    } catch (e) {
      log('ERROR create: $e');
    }
  }

  Future<void> _getSession() async {
    if (!_requireInit()) return;
    final id = _sessionId;
    if (id == null) return log('No session — Create Session first');
    try {
      final s = await Relavoi.instance.sessions.get(id);
      log('Session $id: state=${s.state.name} proxy=${s.proxyNumber} calls=${s.callCount}');
    } catch (e) {
      log('ERROR get: $e');
    }
  }

  Future<void> _initiateCall() async {
    if (!_requireInit()) return;
    final proxy = _proxyNumber;
    if (proxy == null) return log('No session — Create Session first');
    try {
      await Relavoi.instance.sessions.initiateCall(proxy);
      log('initiateCall($proxy) → native dialer opened');
    } catch (e) {
      log('ERROR initiateCall: $e');
    }
  }

  Future<void> _verify() async {
    if (!_requireInit()) return;
    try {
      final active = await Relavoi.instance.verification.isCallActive();
      log('callActive=$active');
      final r = await Relavoi.instance.verification.verify(_userPhone.text.trim());
      log('verified=${r.verified} context=${r.context ?? "—"} session=${r.sessionId ?? "—"}');
    } catch (e) {
      log('ERROR verify: $e');
    }
  }

  Future<void> _checkCallActive() async {
    if (!_requireInit()) return;
    final active = await Relavoi.instance.verification.isCallActive();
    final phonePerm =
        await Relavoi.instance.verification.hasPhoneStatePermission();
    log('isCallActive=$active  hasPhoneStatePermission=$phonePerm');
  }

  Future<void> _connectEvents() async {
    if (!_requireInit()) return;
    if (!_eventsWired) {
      Relavoi.instance.events.onAny((e) => log('EVENT ${e.rawType} ${e.payload}'));
      _eventsWired = true;
      log('Event listener attached');
    }
    await Relavoi.instance.events.connect();
    log('events.connect() called — connected=${Relavoi.instance.events.isConnected}');
  }

  void _updatePresence() {
    if (!_requireInit()) return;
    Relavoi.instance.presence.start(_userPhone.text.trim());
    log('Presence started for ${_userPhone.text} — auto online/background/offline');
  }

  Future<void> _endSession() async {
    if (!_requireInit()) return;
    final id = _sessionId;
    if (id == null) return log('No session — Create Session first');
    try {
      await Relavoi.instance.sessions.end(id);
      log('Session ended: $id');
      _sessionId = null;
      _proxyNumber = null;
    } catch (e) {
      log('ERROR end: $e');
    }
  }

  Future<void> _listSessions() async {
    if (!_requireInit()) return;
    try {
      final resp = await Relavoi.instance.sessions.list();
      log('Sessions: ${resp.count} returned');
      for (final s in resp.data) {
        log('  ${s.id.substring(0, 8)}… ${s.state.name} proxy=${s.proxyNumber}');
      }
    } catch (e) {
      log('ERROR list: $e');
    }
  }

  Widget _field(String label, TextEditingController c, {bool secret = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: c,
        obscureText: secret,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: onTap, child: Text(label)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relavoi Flutter — Test Harness')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ListView(
                children: [
                  _field('API Key (paste)', _apiKey),
                  _field('API Secret (paste)', _apiSecret, secret: true),
                  _field('Tenant ID', _tenantId),
                  _field('Agent phone', _agentPhone),
                  _field('Customer phone', _customerPhone),
                  _field('User phone (verify/presence)', _userPhone),
                  const SizedBox(height: 6),
                  _btn('Initialize SDK', _initialize),
                  _btn('Create Session', _createSession),
                  _btn('Get Session', _getSession),
                  _btn('Initiate Call (dialer)', _initiateCall),
                  _btn('Verify Call', _verify),
                  _btn('Check Call Active', _checkCallActive),
                  _btn('Connect Events', _connectEvents),
                  _btn('Update Presence', _updatePresence),
                  _btn('End Session', _endSession),
                  _btn('List Sessions', _listSessions),
                  _btn('Clear Log', () => setState(() => _log.clear())),
                ],
              ),
            ),
            const Divider(),
            const Text('SDK log', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Text(
                    _log[i],
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
