# Termous Flutter WebRTC 补丁

Fork：https://github.com/Countra/flutter-webrtc

上游：https://github.com/flutter-webrtc/flutter-webrtc

基线：上游 `1.6.3` 之后的提交 `5ee7ac5eb5ad049b1ef847244c566ce2d7fe235e`。从此前基于 `1.6.2+hotfix.4` 的本地补丁迁入呈现回执，保留基线已有修复和许可证。

## 修改范围

- `FlutterRTCVideoRenderer`：接收原生 EGL 提交后的真实 RTP 帧标识，每个 Track 独立管理回执生命周期。
- `PresentedFrameGate`：登记待确认版本及 RTP 边界，处理视频／消息乱序、重复、32 位回绕与关闭；不保存画面。
- `MethodCallHandlerImpl`、`rtc_video_renderer_impl.dart`：提供 `armPresentation` 和 `onFramePresented` 桥接，仅在满足边界时发送一次回执。
- `android/webrtc-sdk.gradle`：从宿主配置取得配套 AAR，不依赖 Termous 仓库、相对目录或 Pub 缓存位置。

这份 fork 的 Android 代码必须与 `rtp-presented-frame-v1` 原生补丁 SDK 配套，不能回退到普通 Maven WebRTC。其他平台保留上游实现，不声明 Android 呈现能力。

## 宿主接入

在宿主 Android 根项目配置阶段，校验 SDK 的来源、版本、补丁、摘要和 ABI 后设置扩展属性：

```kotlin
extra["flutterWebrtcAndroidAar"] = file("/absolute/path/to/verified-sdk.aar")
```

也可通过 Gradle 项目属性提供路径；相对路径以宿主 Android 根目录解析。属性缺失或文件不存在时明确停止构建，不自动下载或替换 SDK。Termous mobile 在自己的 `native/webrtc/dependency.gradle` 中完成配套清单校验后注入该属性。

消费方通过 Git 依赖固定本 fork 的完整提交 SHA，并提交锁文件。先发布 fork 提交，再发布引用它的消费方提交，保证全新环境可以解析依赖；不要依赖可移动分支或修改全局 Pub 缓存。

## 验证与维护

`test/native/PresentedFrameGateTest.java` 可以直接用 JDK 编译执行，不需要 Android SDK 或 AAR。Dart 单元测试覆盖呈现桥接、迟到回执和生命周期；Android 实际 JNI／渲染必须在配套 AAR 生成后由宿主执行集成验证，纯 Java／Dart 测试不能代替该验收。

Fork 的 CI 保留 Dart 检查并执行纯 Java 门禁；上游 Android 示例没有宿主的配套 AAR，Android 示例构建只在上游仓库运行，fork 的原生集成由宿主负责。升级上游时审查上述文件的差异，合并后重新执行配套测试，再更新消费方固定 SHA。
