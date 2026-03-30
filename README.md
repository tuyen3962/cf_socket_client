# cf_socket_client

A Flutter/Dart wrapper around [centrifuge](https://pub.dev/packages/centrifuge) for connecting to **Centrifugo** over WebSocket: connection state, channel subscribe/publish, and **emit with ACK** (request/response on a channel).

**Requirements:** a Centrifugo-compatible backend that issues **connection JWTs**; the WebSocket URL is usually `wss://<host>/connection/websocket`.

## Installation

In `pubspec.yaml`:

```yaml
dependencies:
  cf_socket_client: ^1.0.0
```

## Quick usage

```dart
import 'package:cf_socket_client/cf_socket_client.dart';

final socket = CentrifugalSocket(
  config: CentrifugeSocketConfig(
    url: 'wss://your-host/connection/websocket',
    onSubscribe: (channel) async {
      // Optional: call your HTTP API so the server authorizes the channel
    },
  ),
);

socket.initCentrifugalClient();

socket.connectStatus.listen((status) {
  // ConnectStatus: none | connecting | connected | disconnected
});

await socket.connect('<JWT_CONNECTION_TOKEN>');

socket.subscribe('channel_name', (data) {
  // data: decoded JSON from the publication (often a Map)
});

await socket.emit('channel_name', {'text': 'hello'});

final reply = await socket.emitWithAck(
  'channel_name',
  {'action': 'ping'},
  timeout: const Duration(seconds: 10),
);

await socket.disconnect();
socket.dispose();
```

- **`connect(token)`** — token must not be empty.
- **`subscribe`** — publications are JSON-decoded; the callback receives `dynamic` (often a `Map`).
- **`emit`** — publishes JSON to the channel.
- **`emitWithAck`** — sends a payload including a `requestId` (UUID); your server should reply on the same channel to complete the `Future`.

Use `socket.client` for the full [centrifuge](https://pub.dev/packages/centrifuge) `Client` API.

## Example app

```bash
cd example/cf_socket_client_example
flutter pub get
flutter run
```

Enter the WebSocket URL, JWT, and channel name in the app; try Connect, Subscribe, Emit, and Emit + ACK. You need a real Centrifugo server and a valid token.

## Dependencies

| Package | Notes |
|---------|--------|
| [centrifuge](https://pub.dev/packages/centrifuge) | Centrifugo client protocol |
| [uuid](https://pub.dev/packages/uuid) | `requestId` for `emitWithAck` |

## Further reading

- [Centrifugo — WebSocket](https://centrifugal.dev/docs/transports/websocket)
- [Client JWT authentication](https://centrifugal.dev/docs/server/authentication)
