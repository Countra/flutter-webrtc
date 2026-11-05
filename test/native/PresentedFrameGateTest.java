package com.cloudwebrtc.webrtc;

public final class PresentedFrameGateTest {
    public static void main(String[] args) {
        PresentedFrameGate gate = new PresentedFrameGate();
        check(gate.presented(99) == null, "未登记边界不得发送回执");
        check(gate.arm("1", 100) == null, "旧帧不得确认新画面");
        check(gate.presented(99) == null, "重复旧帧不得恢复控制");
        PresentedFrameGate.Receipt first = gate.presented(100);
        check(first != null && first.revision.equals("1") && first.timestamp == 100,
                "新帧必须确认正确版本");
        check(gate.presented(101) == null, "稳态不得逐帧发送回执");
        check(gate.arm("2", 101).revision.equals("2"), "视频先于状态到达也能确认");
        check(gate.arm("3", 103) == null, "边界必须等待匹配帧");
        gate.arm("4", 104);
        check(gate.presented(103) == null, "过时边界不得覆盖新边界");
        check(gate.presented(104).revision.equals("4"), "最新边界丢失");
        gate.reset();
        check(gate.arm("5", 0xfffffff0L) == null, "新 Track 不得复用旧呈现");
        check(gate.presented(0xfffffff1L) != null, "回绕前帧无法确认");
        check(gate.arm("6", 0) == null, "回绕前旧帧确认了回绕后边界");
        check(gate.presented(0).timestamp == 0, "零 RTP 时间戳必须合法");
        gate.arm("7", 2);
        check(gate.presented(0xfffffffeL) == null, "迟到旧周期帧无法识别");
        check(gate.presented(2).revision.equals("7"), "回绕后的新帧无法确认");
        gate.close();
        check(gate.presented(3) == null, "关闭后仍在回调");
        try {
            gate.arm("8", 3);
            throw new AssertionError("关闭后重新登记边界");
        } catch (IllegalArgumentException expected) {
            // 关闭后不可复活；新播放器必须创建自己的门禁。
        }
    }

    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
}
