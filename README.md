# Ark 面试通

项目名称：ArkInterview  
展示名：Ark 面试通  
包名：com.lgq.arkinterview

Ark 面试通是面向鸿蒙开发者的原生刷题与面试训练 App。第一版只聚焦鸿蒙开发者，目标是稳定支持远程题库、分类练习、答案解析、错题本、收藏、练习记录和基础模拟面试。

## 当前仓库内容

- `backend/`：零依赖 Node.js REST API，提供题库、答题、收藏、错题和管理接口。
- `admin/`：静态管理后台，可通过后端服务访问 `/admin/`，支持题目浏览、新增、发布/下架和难度调整。
- `data/seed/`：MVP 分类种子数据；题库默认为空。
- `entry/`、`AppScope/`、`build-profile.json5`：HarmonyOS ArkTS + ArkUI + Stage 原生 App 工程。
- `apps/harmony/`：HarmonyOS App 打开和调试说明。
- `docs/`：产品范围、API 契约、数据模型和路线图。
- `docs/question-authoring-guidelines.md`：题库编写与官方文档核验规范。

## 本地启动

需要 Node.js 18 或更高版本。

```powershell
npm run dev
```

默认服务地址：

- API: `http://127.0.0.1:8787/api`
- 管理后台: `http://127.0.0.1:8787/admin/`

服务首次启动会从 `data/seed/` 生成本地运行库 `backend/storage/db.json`。该文件是本地运行状态，不纳入版本控制。当前不内置题目，确认合理、答案正确且完成官方来源核验后，题目才能入库。

## 验证

```powershell
npm test
```

测试会使用 `.tmp/smoke-db.json` 启动临时后端，覆盖分类、题目、随机练习、错题练习、收藏练习、答题提交和基础模拟面试接口。

## DevEco Studio

直接用 DevEco Studio 打开仓库根目录：

```text
E:\Codex-AI-Coding\ArkInterview
```

真机调试时，把 `entry/src/main/ets/app/AppConfig.ets` 中的 `API_BASE_URL` 改成后端服务可访问的局域网 IP 或 HTTPS 域名。

## MVP 原则

第一版以“能稳定刷题”为目标：

- 题库和后台放服务端。
- App 本地只做缓存、收藏、错题和练习记录。
- MVP 可以使用匿名设备 ID 保存记录。
- AI 简答题评分和模拟面试追问后续接入，API Key 必须只放服务端。
- 题目允许参考公开知识点，但不能直接搬运 CSDN、掘金、公众号等平台的题库和答案。
- 题目发布必须绑定官方文档来源，且人工核验后才能发布。
