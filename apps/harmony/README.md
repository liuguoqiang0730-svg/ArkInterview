# HarmonyOS App 目录

这里预留 ArkTS + ArkUI + Stage 原生应用工程，并已提供一套可迁入 DevEco 工程的 MVP 源码骨架。

建议在 DevEco Studio 中创建 HarmonyOS 工程后，把工程放在本目录，关键配置使用：

- App name: `Ark 面试通`
- Bundle name: `com.lgq.arkinterview`
- Model: Stage
- Language: ArkTS
- UI: ArkUI

首版 App 页面建议：

1. 首页：分类、随机练习、错题练习、收藏练习入口。
2. 分类题目列表：按分类分页加载远程题库。
3. 答题页：支持单选、多选、判断、简答。
4. 反馈页：展示正确答案、解析、知识点、收藏入口。
5. 错题本：重新练习和标记掌握。
6. 练习记录：分类完成度、正确率、最近练习时间。

客户端只保存匿名设备 ID、本地缓存、收藏、错题和练习记录。服务端 API Key、AI 评分和题库维护逻辑必须放在服务端。

## 已提供源码骨架

- `src/main/ets/app/AppConfig.ets`：应用名、API 地址和匿名设备 ID 默认值。
- `src/main/ets/models/QuestionModels.ets`：分类、题目、练习会话、答题反馈和统计模型。
- `src/main/ets/services/ApiClient.ets`：后端 REST API 客户端。
- `src/main/ets/viewmodels/PracticeStore.ets`：首页、练习、答题、收藏和错题状态入口。
- `src/main/ets/pages/HomePage.ets`：首页分类和练习入口。
- `src/main/ets/pages/PracticePage.ets`：练习题列表。
- `src/main/ets/pages/QuestionPage.ets`：答题、反馈、解析和收藏。

## 接入 DevEco 工程

在 DevEco Studio 创建 Stage 模型工程后，把 `src/main/ets/` 下的源码迁入 `entry/src/main/ets/`，并在页面配置中加入：

```json
{
  "src": [
    "pages/HomePage",
    "pages/PracticePage",
    "pages/QuestionPage"
  ]
}
```

真机调试时，`AppConfig.ets` 里的 `API_BASE_URL` 不能使用 `127.0.0.1`，需要改成电脑局域网 IP 或部署后的 HTTPS 域名。
