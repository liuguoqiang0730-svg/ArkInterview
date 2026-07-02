# HarmonyOS App 目录

这里预留 ArkTS + ArkUI + Stage 原生应用工程。

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
