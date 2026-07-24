# Ark 面试通

项目名称：ArkInterview  
展示名：Ark 面试通  
包名：com.lgq.arkinterview

Ark 面试通是面向鸿蒙开发者的原生刷题与面试训练 App。第一版只聚焦鸿蒙开发者，目标是稳定支持远程题库、分类练习、答案解析、错题本、收藏、练习记录和基础模拟面试。

## 当前仓库内容

- `backend/`：Node.js REST API 和 SQLite 数据层，提供题库、答题、收藏、错题和管理接口。
- `admin/`：静态管理后台，可通过后端服务访问 `/admin/`，支持题目浏览、新增、发布/下架和难度调整。
- `data/question-bank/modules/`：按模块维护的题库源数据。
- `data/seed/`：由题库构建脚本生成的服务端聚合数据。
- `entry/`、`AppScope/`、`build-profile.json5`：HarmonyOS ArkTS + ArkUI + Stage 原生 App 工程。
- `apps/harmony/`：HarmonyOS App 打开和调试说明。
- `docs/`：产品范围、API 契约、数据模型和路线图。
- `docs/question-authoring-guidelines.md`：题库编写与官方文档核验规范。

## 本地启动

需要 Node.js 20.17 或更高版本。

```powershell
$env:ADMIN_TOKEN = (node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))")
npm run dev
```

默认服务地址：

- API: `http://127.0.0.1:8787/api`
- 管理后台: `http://127.0.0.1:8787/admin/`

进入管理后台时输入当前 shell 中的 `ADMIN_TOKEN`。令牌只保存在当前浏览器标签页的 `sessionStorage`，关闭标签页后需要重新输入。服务端要求令牌至少 32 个字符；未配置时公开刷题 API 仍可用，但所有 `/api/admin/*` 管理接口会关闭。

服务首次启动会从 `data/seed/` 生成 SQLite 运行库 `backend/storage/arkinterview.sqlite`。该文件是本地运行状态，不纳入版本控制。若检测到旧版 `backend/storage/db.json`，服务会自动导入分类、题目、匿名用户、收藏、错题和答题记录，且不会修改或删除旧 JSON。

题库新增后，使用以下命令增量同步本地数据库；该命令会保留用户、收藏、错题和练习记录：

```powershell
npm run questions:sync-db:dry
npm run questions:sync-db
```

不要把真实 `ADMIN_TOKEN` 写进仓库、截图或日志。

## 可选华为账号登录

后端已经支持华为 Authorization Code 验证、匿名学习记录合并、ArkInterview 访问/刷新令牌轮换、退出登录和排行榜参与授权。HarmonyOS 客户端已增加 Account Kit 官方登录按钮、“我的”页面、AssetStore 加密会话保存、Token 自动刷新及默认关闭的排行榜参与开关；匿名刷题始终可用。

启用登录前，在服务端同时配置以下三个变量，缺少任意一个时服务会拒绝以不完整配置启动：

```bash
export HUAWEI_CLIENT_ID="<AGC OAuth client id>"
export HUAWEI_CLIENT_SECRET="<server-only client secret>"
export HUAWEI_REDIRECT_URI="<registered redirect uri>"
```

可选令牌有效期变量为 `AUTH_ACCESS_TTL_SECONDS` 和 `AUTH_REFRESH_TTL_SECONDS`，默认分别为 `900` 秒和 `2592000` 秒。`HUAWEI_CLIENT_SECRET`、华为授权码和所有明文令牌都不能写入仓库或日志，公网登录接口必须使用 HTTPS。

客户端还需要填写 AGC OAuth Client ID，并把 API 地址切换为 HTTPS。完整步骤和验收项见 [`docs/huawei-account-setup.md`](docs/huawei-account-setup.md)。当前仓库使用 `HUAWEI_CLIENT_ID_PENDING` 占位符且公网 API 仍是 HTTP，因此登录入口会安全禁用，不影响匿名使用。

## 发布远程题库

远程服务部署最新后端并配置相同的 `ADMIN_TOKEN` 后，可以从本仓库按题目 ID 增量发布：

```powershell
$env:ADMIN_API_URL = 'https://your-domain.example/api'
$env:ADMIN_TOKEN = '<服务器配置的管理员令牌>'
npm run questions:publish:dry
npm run questions:publish
```

`questions:publish:dry` 只比较差异；正式命令只新增或更新发生变化的分类和题目，默认保留服务器额外数据。公网管理操作必须使用 HTTPS，当前 HTTP 地址只适合迁移过渡，避免管理员令牌被明文截获。

## 生产部署

服务器代码更新到已审核提交后，在服务器上生成令牌并执行部署脚本：

```bash
cd /opt/arkinterview
export ADMIN_TOKEN="$(openssl rand -hex 32)"
bash scripts/deploy-production.sh
```

脚本会拒绝脏 Git 工作区，使用锁文件安装生产依赖，在线备份 SQLite，运行 `npm test`，通过 PM2 重载服务，并验证公开 API、登录能力状态、未授权 `401` 和授权 `200`。首次迁移时如果 SQLite 尚不存在，脚本会先备份旧版 `db.json`。脚本不会自动执行 `git pull` 或覆盖题库。若服务端使用自定义目录、端口或数据库路径，可通过 `APP_DIR`、`API_URL`、`PORT`、`DB_FILE` 和 `LEGACY_DB_FILE` 环境变量覆盖。

部署成功后应妥善保存令牌并立即配置 HTTPS。需要回滚代码时，先切回上一条已验证提交并重新执行部署脚本；若确实需要恢复数据，再停止服务后使用脚本输出的 `.deploy-backups/*.sqlite` 或首次迁移产生的旧 JSON 备份。

## 验证

```powershell
npm test
```

测试会创建临时 SQLite 数据库，验证旧 JSON 迁移、Schema 升级、数据重启恢复和数据库完整性，并覆盖管理员鉴权、可选登录、会话轮换、匿名记录合并、账户数据隔离、分类、题目、随机练习、错题练习、收藏练习、答题提交和基础模拟面试接口。

## DevEco Studio

直接用 DevEco Studio 打开仓库根目录：

```text
E:\Codex-AI-Coding\ArkInterview
```

真机调试时，把 `entry/src/main/ets/app/AppConfig.ets` 中的 `API_BASE_URL` 改成后端服务可访问的局域网 IP 或 HTTPS 域名，并确保后端使用 `npm run dev` 启动。默认后端监听 `0.0.0.0:8787`，便于同一局域网设备访问。

当前 HarmonyOS 工程不显式指定 `compileSdkVersion`，使用 DevEco 当前安装并支持的缺省编译 SDK；`compatibleSdkVersion` 和 `targetSdkVersion` 以字符串形式配置为当前已安装 SDK 对应的 `6.1.0(23)`。

## MVP 原则

第一版以“能稳定刷题”为目标：

- 题库和后台放服务端。
- App 本地只做缓存、收藏、错题和练习记录。
- MVP 可以使用匿名设备 ID 保存记录。
- AI 简答题评分和模拟面试追问后续接入，API Key 必须只放服务端。
- 题目允许参考公开知识点，但不能直接搬运 CSDN、掘金、公众号等平台的题库和答案。
- 题目发布必须绑定官方文档来源，且人工核验后才能发布。
