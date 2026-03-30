import 'package:centrifuge/centrifuge.dart';

class CentrifugeSocketConfig {
  // The websocket url
  final String url;

  // The client config for centrifuge socket
  final ClientConfig? config;

  // The function to be called when a subscription is made
  // When you try to subscribe to a channel in a client side, but this don't work so you can use this to call api to subscribe to the channel
  final Future<void> Function(String chanel)? onSubscribe;

  CentrifugeSocketConfig({
    required this.url,
    this.config,
    this.onSubscribe,
  });
}
