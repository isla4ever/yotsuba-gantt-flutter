## 0.1.0-alpha.2

- 新增可配置的双指时间维度缩放，并保持单指滚动和任务拖动互不抢占。
- 维度变化后复用密集数据自动定位；关闭自动定位时保留当前视口中心。
- Android 演示新增用户主动触发的横屏沉浸入口和竖屏紧凑控制布局。

## 0.1.0-alpha.1

- 将 `example/` 切换为 pub.dev hosted dependency，验证真实消费者安装路径。
- Android Release 从 hosted dependency 演示应用构建，并附带 APK 与 SHA-256 校验文件。
- README 与 Release 说明补充演示仓库、安装和下载入口。

## 0.1.0-alpha.0

- 首个 Flutter 原生 Alpha。
- 支持六档时间维度、行虚拟化、任务条拖动/缩放与进度展示。
- 支持依赖线、密集数据自动聚焦、行级视口外任务导航和可调整分栏。
- 提供任务条、行表头和入场过渡 Builder，以及公开控制器方法。
- 新增 `YgGanttLinkGroup` 多图实时联动和 `edgeIndicatorBuilder` 边界入口扩展。
- 依赖线任务索引改为数据变更时缓存，避免 10K 滚动期间重复全量构建。
