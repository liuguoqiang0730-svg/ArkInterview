# Ark 面试通

项目名称：ArkInterview  
展示名：Ark 面试通  
包名：com.lgq.arkinterview

Ark 面试通是面向鸿蒙开发者的原生刷题与面试训练 App。第一版只聚焦鸿蒙开发者，目标是稳定支持远程题库、分类练习、答案解析、错题本、收藏、练习记录和基础模拟面试。

## 当前仓库内容

- `backend/`：零依赖 Node.js REST API，提供题库、答题、收藏、错题和管理接口。
- `admin/`：静态管理后台，可通过后端服务访问 `/admin/`，支持题目浏览、新增、发布/下架和难度调整。
- `data/question-bank/modules/`：按模块维护的题库源数据。
- `data/seed/`：由题库构建脚本生成的服务端聚合数据。
- `entry/`、`AppScope/`、`build-profile.json5`：HarmonyOS ArkTS + ArkUI + Stage 原生 App 工程。
- `apps/harmony/`：HarmonyOS App 打开和调试说明。
- `docs/`：产品范围、API 契约、数据模型和路线图。
- `docs/question-authoring-guidelines.md`：题库编写与官方文档核验规范。

## 本地启动

需要 Node.js 18 或更高版本。

```powershell
$env:ADMIN_TOKEN = (node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))")
npm run dev
```

默认服务地址：

- API: `http://127.0.0.1:8787/api`
- 管理后台: `http://127.0.0.1:8787/admin/`

进入管理后台时输入当前 shell 中的 `ADMIN_TOKEN`。令牌只保存在当前浏览器标签页的 `sessionStorage`，关闭标签页后需要重新输入。服务端要求令牌至少 32 个字符；未配置时公开刷题 API 仍可用，但所有 `/api/admin/*` 管理接口会关闭。

服务首次启动会从 `data/seed/` 生成本地运行库 `backend/storage/db.json`。该文件是本地运行状态，不纳入版本控制。题库新增后，使用以下命令增量同步本地数据库；该命令会保留用户、收藏、错题和练习记录：

```powershell
npm run questions:sync-db:dry
npm run questions:sync-db
```

不要把真实 `ADMIN_TOKEN` 写进仓库、截图或日志。

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

脚本会拒绝脏 Git 工作区，备份 `backend/storage/db.json`，运行 `npm test`，通过 PM2 重载服务，并验证公开 API、未授权 `401` 和授权 `200`。脚本不会自动执行 `git pull` 或覆盖题库。若服务端使用自定义目录、端口或数据库路径，可通过 `APP_DIR`、`API_URL`、`PORT` 和 `DB_FILE` 环境变量覆盖。

部署成功后应妥善保存令牌并立即配置 HTTPS。需要回滚代码时，先切回上一条已验证提交并重新执行部署脚本；若确实需要恢复数据，再停止服务后使用脚本输出的 `.deploy-backups/db-*.json` 备份文件。

## 验证

```powershell
npm test
```

测试会使用 `.tmp/smoke-db.json` 启动临时后端，覆盖管理员鉴权、分类、题目、随机练习、错题练习、收藏练习、答题提交和基础模拟面试接口。

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
