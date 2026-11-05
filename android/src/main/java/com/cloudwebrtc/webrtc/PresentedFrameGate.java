package com.cloudwebrtc.webrtc;

// 仅记录帧身份，不保存像素；版本回执只由真实渲染回调或其最近结果产生。
final class PresentedFrameGate {
    static final class Receipt {
        final String revision;
        final long timestamp;

        Receipt(String revision, long timestamp) {
            this.revision = revision;
            this.timestamp = timestamp;
        }
    }

    private String revision;
    private long minimum;
    private Long latest;
    private boolean closed;

    synchronized Receipt arm(String revision, long minimum) {
        if (closed || revision == null || revision.isEmpty() || minimum < 0 || minimum > 0xffffffffL) {
            throw new IllegalArgumentException("无效的呈现边界");
        }
        this.revision = revision;
        this.minimum = minimum;
        return ready();
    }

    synchronized Receipt presented(long timestamp) {
        if (closed || timestamp < 0 || timestamp > 0xffffffffL) return null;
        if (latest == null || atOrAfter(timestamp, latest)) latest = timestamp;
        return ready();
    }

    private Receipt ready() {
        if (revision == null || latest == null || !atOrAfter(latest, minimum)) return null;
        Receipt value = new Receipt(revision, latest);
        revision = null;
        return value;
    }

    synchronized void reset() {
        revision = null;
        latest = null;
    }

    synchronized void close() {
        closed = true;
        reset();
    }

    private static boolean atOrAfter(long value, long minimum) {
        return ((value - minimum) & 0xffffffffL) < 0x80000000L;
    }
}
