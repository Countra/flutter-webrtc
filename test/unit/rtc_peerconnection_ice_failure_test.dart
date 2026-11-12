import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/src/native/rtc_peerconnection_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('FlutterWebRTC.Method');
  const events = MethodChannel('FlutterWebRTC/peerConnectionEventice-test');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });
  for (final rejected in [false, true]) {
    test('原生候选结果传递到 Dart：拒绝=$rejected', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(methods, (call) async {
        if (call.method == 'addCandidate') {
          calls++;
          if (rejected) throw PlatformException(code: 'peerConnectionAddICECandidate', message: 'candidate rejected');
        }
        return null;
      });
      final peer = RTCPeerConnectionNative('ice-test', {});
      try {
        final result = peer.addCandidate(RTCIceCandidate('candidate:1 1 udp 100 192.0.2.1 4000 typ host', '0', 0));
        if (rejected) { await expectLater(result, throwsA(contains('candidate rejected'))); }
        else { await result; }
        expect(calls, 1);
      } finally { await peer.dispose(); }
    });
  }
}
