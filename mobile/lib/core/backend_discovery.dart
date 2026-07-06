import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Finds the MeetingMind backend on the local network by UDP broadcast, so
/// the app never needs a hardcoded IP or port. Best-effort: returns null on
/// timeout or on networks that block broadcast (e.g. client-isolated wifi).
abstract final class BackendDiscovery {
  static const _port = 41234;
  static const _probe = 'MEETINGMIND_DISCOVER';
  static const _replyPrefix = 'MEETINGMIND:';

  static Future<String?> find({Duration timeout = const Duration(seconds: 2)}) async {
    RawDatagramSocket? socket;
    StreamSubscription? sub;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(utf8.encode(_probe), InternetAddress('255.255.255.255'), _port);

      final completer = Completer<String?>();
      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        final message = utf8.decode(datagram.data);
        if (!message.startsWith(_replyPrefix) || completer.isCompleted) return;
        final port = message.substring(_replyPrefix.length);
        completer.complete('http://${datagram.address.address}:$port');
      });

      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }
}
