# 参与贡献

提交前请运行：

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze
flutter test
cd example && flutter test
```

新增公开 API 时请同时补充 Dart 文档、单元测试、README 和主站 API 文档。性能相关改动需要说明数据规模、可见 Widget 数量和前后测量结果。
