import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_webrtc/src/native/rtc_video_renderer_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('FlutterWebRTC.Method');
  const events = MethodChannel('FlutterWebRTC/Texture11');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late RTCVideoRenderer renderer;
  late List<(String, int)> presented;
  late List<MethodCall> calls;

  setUp(() async {
    calls = [];
    presented = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'createVideoRenderer') return {'textureId': 11};
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    renderer = RTCVideoRenderer();
    renderer.onFramePresented = (revision, timestamp) {
      presented.add((revision, timestamp));
    };
    await renderer.initialize();
  });

  tearDown(() async {
    await renderer.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  void frame(String revision, int timestamp) {
    renderer.eventListener({
      'event': 'didFramePresented',
      'revision': revision,
      'rtpTimestamp': '$timestamp',
    });
  }

  test('只接受当前边界的真实 RTP 回执，首次渲染事件不代替确认', () async {
    await renderer.armPresentation('first', 100);
    final request = calls.last;
    expect(request.method, 'videoRendererArmPresentation');
    expect(request.arguments, {
      'textureId': 11,
      'revision': 'first',
      'rtpTimestamp': '100',
    });
    renderer.eventListener({'event': 'didFirstFrameRendered'});
    frame('first', 99);
    await renderer.armPresentation('second', 102);
    frame('first', 102);
    expect(presented, isEmpty);
    frame('second', 102);
    frame('second', 103);
    expect(presented, [('second', 102)]);
  });

  test('零值与 RTP 回绕有效，旧周期回执不能确认新内容', () async {
    await renderer.armPresentation('wrap', 0);
    frame('wrap', 0xffffffff);
    expect(presented, isEmpty);
    frame('wrap', 0);
    expect(presented, [('wrap', 0)]);
  });

  test('解绑来源后迟到回执失效', () async {
    await renderer.armPresentation('source', 5);
    await renderer.setSrcObject(stream: null);
    frame('source', 5);
    expect(presented, isEmpty);
  });

  test('销毁后回执与新登记均不得生效', () async {
    await renderer.armPresentation('closed', 8);
    await renderer.dispose();
    frame('closed', 8);
    expect(presented, isEmpty);
    await expectLater(renderer.armPresentation('new', 9), throwsStateError);
  });

  test('登记失败清除该次等待，不能接收迟到成功回执', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'videoRendererArmPresentation') {
        throw PlatformException(code: 'invalid_boundary');
      }
      return null;
    });
    await expectLater(renderer.armPresentation('failed', 20),
        throwsA(isA<PlatformException>()));
    frame('failed', 20);
    expect(presented, isEmpty);
  });
}
