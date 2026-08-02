# Yotsuba Gantt Flutter 演示

这是 `yotsuba_gantt` 的完整 Android 演示应用，启动后直接展示 10,000 条任务、六档时间维度、日期范围选择、密集数据聚焦、任务拖动、边界跳转和详情事件。

演示应用使用 pub.dev 的真实依赖，不使用仓库内 `lib/` 的 path link：

```yaml
dependencies:
  yotsuba_gantt: 0.1.0-alpha.1
```

```bash
flutter pub get
flutter run
```

构建可安装 APK：

```bash
flutter build apk --release
```

预构建 APK 可从 [GitHub Releases](https://github.com/isla4ever/yotsuba-gantt-flutter/releases) 下载。Release 工作流会在构建前等待同版本 pub.dev 包可用，并验证演示应用解析到的版本。每个 APK 同时提供 `.sha256` 校验文件；Alpha APK 使用演示签名，仅用于安装体验和包集成验证。

包 API 和组件实现见仓库根目录，接入方应优先按照 [pub.dev 安装说明](https://pub.dev/packages/yotsuba_gantt) 使用发布包。
