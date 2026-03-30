import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart';
import 'package:cf_socket_client/client/logger_helper.dart';

import 'centrifuge_ack_subscription.dart';
import 'centrifuge_socket_config.dart';
import 'centrifuge_subscription.dart';
import 'package:uuid/uuid.dart';

enum ConnectStatus {
  connected,
  connecting,
  disconnected,
  none,
}

class CentrifugalSocket {
  final CentrifugeSocketConfig config;

  CentrifugalSocket({required this.config});

  late Client _client;

  StreamSubscription<ConnectedEvent>? _connectedSub;
  StreamSubscription<ConnectingEvent>? _connectingSub;
  StreamSubscription<DisconnectedEvent>? _discSub;
  StreamSubscription<ErrorEvent>? _errorSub;
  StreamSubscription<ServerUnsubscribedEvent>? _unsubscribedSub;
  StreamSubscription<ServerSubscribedEvent>? _subscribedSub;

  StreamSubscription<MessageEvent>? _msgSub;

  final StreamController<ConnectStatus> _connectStatusController =
      StreamController<ConnectStatus>.broadcast();

  // The centrifuge client
  // You can trigger any centrifuge client method here
  Client get client => _client;

  // The stream of the connect status
  Stream<ConnectStatus> get connectStatus => _connectStatusController.stream;

  bool _isDisconnect = false;
  bool isConnected = false;
  String clientId = '';
  String token = '';

  bool isReconnecting = false;

  Map<String, CentrifugalSubscription> _subscriptions = {};

  Map<String, CentrifugalAckSubscription> _ackCompleters = {};

  void dispose() {
    _connectStatusController.close();
    _connectedSub?.cancel();
    _connectingSub?.cancel();
    _discSub?.cancel();
    _errorSub?.cancel();
    _msgSub?.cancel();
    _unsubscribedSub?.cancel();
    _subscribedSub?.cancel();
  }

  void initCentrifugalClient() {
    _client = createClient(config.url, config.config ?? ClientConfig());

    _connectedSub = _client.connected.listen((event) {
      loggerHelper.success("CentrifugalSocket: Connected: $event");
      clientId = event.client;
      isConnected = true;
      _connectStatusController.add(ConnectStatus.connected);
    });
    _discSub = _client.disconnected.listen((event) {
      loggerHelper.error("CentrifugalSocket: Disconnected: $event");
      isConnected = false;
      if (event.code == 3505) {
        for (final subscription in _subscriptions.values) {
          subscription.stopTimer();
        }
      }
      clientId = '';
      _connectStatusController.add(ConnectStatus.disconnected);
    });
    _msgSub = _client.message.listen((event) {
      loggerHelper.success("CentrifugalSocket: Msg: $event");
    });
    _errorSub = _client.error.listen((event) {
      loggerHelper.error("CentrifugalSocket: Error: $event");
      if (_isDisconnect || isReconnecting) return;
      // if (event.error is ClientDisconnectedError) {
      loggerHelper.error('error: ${event.error}');
      isConnected = false;
      _connectStatusController.add(ConnectStatus.disconnected);
      // _reconnectSocket();
      // }
    });
    _connectingSub = _client.connecting.listen((event) {
      loggerHelper.success("CentrifugalSocket: Connecting: $event");
      _connectStatusController.add(ConnectStatus.connecting);
    });
    _unsubscribedSub = _client.unsubscribed.listen((event) {
      loggerHelper.success("CentrifugalSocket: Unsubscribed: $event");
    });

    _subscribedSub = _client.subscribed.listen(_handleSubscribedEvent);
  }

  // Logging the subscription event
  void _handleSubscribedEvent(ServerSubscribedEvent event) {
    loggerHelper.success("CentrifugalSocket: Subscribed: $event");
    final channel = event.channel;
    if (_subscriptions.containsKey(channel)) {
      final subscription = _subscriptions[channel];
      if (subscription != null) {
        subscription.stopTimer();
      }
    }
  }

  void _setToken(String token) {
    this.token = token;
    _client.setToken(token);
  }

  List<String> getSubscribedChannels() {
    final subscriptions = _client.subscriptions();
    return subscriptions.keys.toList();
  }

  Future<HistoryResult> history(
    String channel, {
    int limit = 0,
    StreamPosition? since,
    bool reverse = false,
  }) async {
    return await _client.history(channel,
        limit: limit, since: since, reverse: reverse);
  }

  Future<void> connect(String token) async {
    if (isConnected || isReconnecting) {
      loggerHelper.success(
          "CentrifugalSocket: ${isConnected ? "Already connected" : "Already reconnecting"}");
      return;
    }
    isReconnecting = true;
    loggerHelper.logWhite('Connect with token: $token');

    try {
      if (token.isEmpty) {
        isReconnecting = false;
        loggerHelper.error("CentrifugalSocket: Token is empty");
        return;
      }
      _setToken(token);
      await _client.connect();
      await _client.ready();
      _isDisconnect = true;
    } catch (e) {
      loggerHelper.error("CentrifugalSocket: Connect Error: $e");
    }
    isReconnecting = false;
  }

  Future<void> disconnect() async {
    for (final subscription in _subscriptions.values) {
      await subscription.close();
    }
    for (final ackSubscription in _ackCompleters.values) {
      await ackSubscription.close();
    }
    _subscriptions = {};
    _ackCompleters = {};
    token = '';
    _client.setToken('');
    _client.disconnect();
    _isDisconnect = true;
  }

  void subscribe(String channel, Function(dynamic data) onMessage) async {
    if (channel.endsWith('null')) return;
    if (!isConnected && token.isEmpty) {
      loggerHelper.error("CentrifugalSocket: Token is empty");
      return;
    }
    if (!isConnected && token.isNotEmpty) {
      await connect(token);
    }
    try {
      final result =
          _client.getSubscription(channel) ?? _client.newSubscription(channel);
      final subscription =
          CentrifugalSubscription(subscription: result, onMessage: onMessage);
      _subscriptions.putIfAbsent(channel, () => subscription);
      if (config.onSubscribe != null) {
        await config.onSubscribe!(channel);
      }
      loggerHelper.success("CentrifugalSocket: Subscribe Success: $channel");
    } catch (e) {
      loggerHelper
          .error("CentrifugalSocket: Subscribe Error: $e event: $channel");
    }
  }

  void unsubscribe(String channel) async {
    if (!_subscriptions.containsKey(channel)) return;

    try {
      final subscription = _subscriptions[channel];
      if (subscription == null) return;
      await subscription.close();
      await _client.removeSubscription(subscription.subscription);
      _subscriptions.remove(channel);
    } catch (e) {
      loggerHelper
          .error("CentrifugalSocket: Unsubscribe Error: $e event: $channel");
    }
  }

  // Emit a message with ack
  // Returns the response data with request id
  Future<Map<String, dynamic>> emitWithAck(
    String channel,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final requestId = Uuid().v4();
    final payload = {...data, 'requestId': requestId};

    final completer = Completer<Map<String, dynamic>>();
    final subscription = _client.newSubscription(channel);
    final centrifugalSubscription = CentrifugalAckSubscription(
        subscription: subscription,
        channel: channel,
        client: _client,
        payload: payload,
        completer: completer);
    _ackCompleters.putIfAbsent(channel, () => centrifugalSubscription);

    return completer.future.timeout(timeout, onTimeout: () {
      if (_ackCompleters.containsKey(channel)) {
        final centrifugalSubscription = _ackCompleters[channel];
        if (centrifugalSubscription != null) {
          centrifugalSubscription.close();
          _ackCompleters.remove(channel);
        }
      }
      return Future.value({});
    });
  }

  Future<void> emit(String channel, Map<String, dynamic> data) async {
    try {
      await _client.publish(channel, utf8.encode(jsonEncode(data)));
      loggerHelper.success('Message emitted successfully');
    } catch (e) {
      loggerHelper.error('Emit failed: $e');
    }
  }
}
