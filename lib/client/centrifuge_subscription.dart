import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart';
import 'package:cf_socket_client/client/logger_helper.dart';

class CentrifugalSubscription {
  final Subscription subscription;
  final Function(dynamic data) onMessage;

  StreamSubscription<PublicationEvent>? publicationSub = null;
  StreamSubscription<SubscriptionErrorEvent>? publicationErrorSub = null;
  StreamSubscription<SubscribedEvent>? publicationSubscribedSub = null;
  StreamSubscription<UnsubscribedEvent>? publicationUnsubscribedSub = null;

  Timer? _reconnectByAPITimer = null;

  CentrifugalSubscription(
      {required this.subscription, required this.onMessage}) {
    initListeners();
  }

  void initListeners() {
    publicationSub = subscription.publication.listen((PublicationEvent event) {
      loggerHelper.success("CentrifugalSocket: Publication: $event");
      final msg = jsonDecode(utf8.decode(event.data));
      onMessage(msg);
    });
    publicationErrorSub = subscription.error.listen((event) {
      loggerHelper.error("CentrifugalSocket: Publication Error: $event");
      stopTimer();
    });
    publicationSubscribedSub = subscription.subscribed.listen((event) {
      loggerHelper.success("CentrifugalSocket: Publication Subscribed: $event");
      stopTimer();
    });
    publicationUnsubscribedSub = subscription.unsubscribed.listen((event) {
      loggerHelper
          .success("CentrifugalSocket: Publication Unsubscribed: $event");
    });
    if (!subscription.channel.startsWith('personal:')) {
      startReconnectByAPITimer();
    }
  }

  void stopTimer() {
    if (_reconnectByAPITimer != null) {
      _reconnectByAPITimer?.cancel();
      _reconnectByAPITimer = null;
    }
  }

  void startReconnectByAPITimer() {
    stopTimer();
    _reconnectByAPITimer = Timer(const Duration(seconds: 5), () {
      stopTimer();
    });
  }

  Future<void> close() async {
    stopTimer();
    await subscription.unsubscribe();
    publicationSub?.cancel();
    publicationErrorSub?.cancel();
    publicationSubscribedSub?.cancel();
    publicationUnsubscribedSub?.cancel();
    loggerHelper.logWhite(
        "CentrifugalSocket: Subscription Closed: ${subscription.channel}");
  }
}
