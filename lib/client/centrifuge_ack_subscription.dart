import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart';
import 'package:cf_socket_client/client/logger_helper.dart';

class CentrifugalAckSubscription {
  final Subscription subscription;
  final String channel;
  final Client client;
  final Map<String, dynamic> payload;
  final Completer<Map<String, dynamic>> completer;

  late StreamSubscription<PublicationEvent>? publicationSub;
  late StreamSubscription<SubscribedEvent>? subscribedSub;

  CentrifugalAckSubscription(
      {required this.subscription,
      required this.channel,
      required this.client,
      required this.payload,
      required this.completer}) {
    initListeners();
  }

  void initListeners() {
    publicationSub = subscription.publication.listen((PublicationEvent event) {
      loggerHelper.success("CentrifugalSocket: Publication: $channel");
      try {
        final msg = jsonDecode(utf8.decode(event.data));
        completer.complete(msg);
        close();
      } catch (_) {}
    });
    subscribedSub = subscription.subscribed.listen((SubscribedEvent event) {
      loggerHelper.success("CentrifugalSocket: Subscribed: $channel");
      client.publish(channel, utf8.encode(jsonEncode(payload)));
    });

    subscription.subscribe();
  }

  Future<void> close() async {
    publicationSub?.cancel();
    subscribedSub?.cancel();
    await subscription.unsubscribe();
  }
}
