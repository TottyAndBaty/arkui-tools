# ArkUI 拖放工具

按 [ArkUI拖放工具项目文档.md](file:///D:/work/arkui-tools/ArkUI%E6%8B%96%E6%94%BE%E5%B7%A5%E5%85%B7%E9%A1%B9%E7%9B%AE%E6%96%87%E6%A1%A3.md) 实现的可视化页面搭建工具，一次交付两种形态：

| 形态 | 位置 | 用途 |
|------|------|------|
| HarmonyOS ArkUI 工程 | `arkui-drag-drop-tool/entry` | 在 DevEco Studio 中编译、运行到模拟器/真机 |
| 浏览器可直接运行的 Web 版 | `arkui-drag-drop-tool/web` | 无需模拟器即可拖拽、看代码、导出 `.ets`；部署形态见 §7.3 |
| AI 生成服务（Node，零依赖） | `arkui-drag-drop-tool/server` | 自然语言 → 组件树；OpenAI 兼容接口 + 内置中文规则回退 |
| 共享逻辑（UMD，Node/浏览器通用） | `arkui-drag-drop-tool/shared` | 组件注册表、规则引擎、代码生成器 |
| 部署资产 | `Dockerfile`、`scripts/`、`deploy/` | 容器镜像、静态包打包脚本、nginx 站点样例 |

---

## 一、快速开始

### 1. Web 版（建议先跑这个）

```bash
cd arkui-drag-drop-tool/server
node index.js            # 或 npm start
```

打开 <http://localhost:3000/> ，即可拖拽组件、编辑属性、实时看生成的 ArkTS 代码。

不想启动 Node：直接双击 `arkui-drag-drop-tool/web/index.html`。此时 AI 输入框走浏览器内置的本地规则引擎（勾选"调用本地服务"时会提示服务不可用并自动本地生成）。

### 2. ArkUI 工程

用 DevEco Studio 6.0.2+ 打开 `arkui-drag-drop-tool` 目录，等待 ohpm / hvigor 同步完成后运行 `entry`。
工程配置：HarmonyOS `6.0.2(22)`、stage 模型、deviceTypes `phone/tablet/2in1`、已声明 `ohos.permission.INTERNET`。

命令行构建（PowerShell / cmd）：

```bat
set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" ^
  "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --no-daemon assembleHap
```

产物：`arkui-drag-drop-tool/entry/build/default/outputs/default/entry-default-unsigned.hap`
（未签名；签名与安装到设备/模拟器的完整步骤见"七、部署"。）

### 3. 把 AI 服务接到 ArkUI 应用里

应用右上角"设置"里可以改服务地址（默认 `http://10.0.2.2:3000/api/generate`）：

- 模拟器 → 宿主机：`http://10.0.2.2:3000/api/generate`
- 真机（与电脑同网段）：`http://<电脑局域网IP>:3000/api/generate`

以上都是本机跑。要签 HAP 装到设备、把服务常驻（pm2 / systemd / Docker / nginx HTTPS）或纯静态托管 Web 版，见"七、部署"。

---

## 二、AI 生成：接口与回退

服务只依赖 Node 18+ 内置模块（`http` + 全局 `fetch`），无需 `npm install`。

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `OPENAI_API_KEY` / `ARKUI_LLM_API_KEY` | 空 | 不设置则只用内置规则引擎，完全离线可用 |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | 任何 OpenAI 兼容网关（DeepSeek、通义、本地 ollama 等） |
| `OPENAI_MODEL` | `gpt-4o-mini` | 模型名 |
| `PORT` / `HOST` | `3000` / `0.0.0.0` | 监听地址 |

```bash
set OPENAI_API_KEY=sk-xxx && set OPENAI_BASE_URL=https://api.deepseek.com/v1 && set OPENAI_MODEL=deepseek-chat
node index.js
```

- `GET /api/health` → `{"ok":true,"mode":"llm|rules","model":"..."}`
- `POST /api/generate` `{"prompt":"生成一个登录页面，包含用户名、密码输入框和登录按钮"}` → 组件树 JSON，响应头 `X-ArkUI-Source: llm | rules`
- 大模型调用失败、超时或返回非 JSON 时自动回退规则引擎，不阻塞界面。
- 所有外部来源（大模型、导入的 JSON）都先经 `shared/rules.js` 的 `sanitize()`：类型白名单、深度 ≤ 12、子节点 ≤ 40、颜色格式校验。

内置规则模板覆盖：登录、注册、搜索、表单、页签、列表、网格、卡片、视频、网页；未命中时给出通用页面骨架，并吸收剩余关键词（如"标题""提交按钮"）。

---

## 三、生成的代码放回 DevEco Studio

1. 点"导出 .ets"（或 ArkUI 应用里的"导出"）得到 `GeneratedPage.ets`；
2. 放入 `entry/src/main/ets/pages/`，在 `entry/src/main/resources/base/profile/main_pages.json` 的 `src` 数组里注册；
3. `Web` 组件会生成 `webview.WebviewController` 成员并 `import { webview } from '@kit.ArkWeb';`，`Canvas` 会生成 `CanvasRenderingContext2D` 成员——两者都已随代码一起输出，无需手写；
4. `Image` 输出为 `$r('app.media.<name>')`，需要把同名图片资源放进 `AppScope/resources/base/media/`。

---

## 四、功能与文档章节对照

| 文档章节 | 实现位置 |
|----------|----------|
| §3.1 组件面板（基础/布局/媒体/容器） | `pages/ComponentPanel.ets`、`web/js/app.js` + `shared/registry.js` |
| §3.2 拖放画布（自由摆放、层级、删除复制粘贴） | `components/DragDropEngine.ets`、`components/NodeRenderer.ets`、`pages/CanvasArea.ets`、`web/js/app.js` |
| §3.3 属性配置面板（通用/特有/事件绑定） | `pages/PropertyPanel.ets`、`shared/registry.js` 的 `PROP_SCHEMA`、`web/js/app.js` |
| §3.4 代码生成与预览、导出 | `utils/CodeGenerator.ets`、`shared/generator.js`、`pages/CodePreview.ets` |
| §3.5 AI 辅助生成 | `server/index.js`、`shared/rules.js`、`utils/AiClient.ets`、`pages/Index.ets` |
| §5.1 拖放引擎 | 长按 + `GestureGroup(GestureMode.Sequence, LongPressGesture, PanGesture)`，配合 `onAreaChange` 上报的全局坐标框注册表做命中检测 |
| §5.2 组件树数据结构 | `model/ComponentModel.ets`（`ComponentItem` / `ComponentStyle` / 树操作 / `treeFromJson`） |
| §5.3 代码生成器 | `utils/CodeGenerator.ets` 与 `shared/generator.js` 为同一规则的 ArkTS / JS 双实现 |
| §7 目录结构 | 见下方"目录"，差异见"与原文档的偏差" |

Web 版快捷键：`Delete` 删除 · `Ctrl/Cmd+C` 复制 · `Ctrl/Cmd+V` 粘贴 · `Ctrl/Cmd+D` 克隆。
画布工具条：删除 / 复制 / 粘贴 / 克隆 / 上移 / 下移 / 置顶 / 置底 / 清空。

---

## 五、与原文档的偏差（有意为之）

1. `props` 类型为 `Record<string, string>`，不是文档里的 `Record<string, any>`：ArkTS 禁止 `any`/`unknown`，对象字面量也需要显式类型。
2. `ComponentItem` 放在 `model/ComponentModel.ets`（与 `ComponentStyle`、树操作同文件），未单独建 `components/ComponentItem.ets`。
3. 拖拽用 **PanGesture + 全局坐标命中**（文档 §2 的"PanGesture + Drop"路线），而不是 ArkUI 的 `DragAndDrop`/UDF 通道，避免跨版本 API 差异和跨文件数据负载问题。
4. 服务端为 Node 原生 `http`，未引入 Express；目录里因此没有 `node_modules`。
5. 新增了文档未列出的文件：`components/NodeRenderer.ets`（递归渲染）、`pages/CodePreview.ets`、`utils/AiClient.ets`、`shared/`、`web/`（含部署期配置 `web/config.js`）、`Dockerfile`、`scripts/pack-web.js`、`deploy/nginx-web.conf`。
6. SDK 中该枚举成员实际是 `GestureMode.Sequence`（文档示例未涉及）。

---

## 六、验证状态（如实说明）

- **ArkUI 工程**：`hvigor assembleHap` **BUILD SUCCESSFUL**，产出未签名 HAP。⚠️ 未在模拟器或真机上运行过，长按拖拽、粘贴板、文件导出等运行时行为尚未实测。
- **Web 版**：在浏览器中端到端实测通过——
  - 组件面板拖入画布、容器嵌套、同级插入、画布末尾追加；
  - 已有节点跨层级移动（拖到容器内部 / 拖到叶子组件旁）；
  - 属性面板改动实时反映到代码预览（含 `onClick` 语句输出）；
  - 上移/下移/置顶/置底/克隆/复制/粘贴/删除/清空；
  - 快捷键 `Delete`、`Ctrl+C/V/D`；
  - AI 三条路径：服务端规则生成、勾选关闭时本地规则生成、服务不可达时自动本地回退（徽标显示错误原因）；
  - 导出 `GeneratedPage.ets`、导出 JSON → 清空 → 导入 JSON 往返一致；
  - 导入非法类型/损坏 JSON 时安全回退或提示，不破坏画布；
  - 控制台无报错。界面截图见 [screenshots/03-web-final.png](file:///D:/work/arkui-tools/screenshots/03-web-final.png)。
- **已知限制**：无撤销/重做；事件绑定只输出语句文本，不做语法校验；`Grid`/`List` 的滚动与虚拟化在 Web 预览里只是示意；真机拖拽体验需自行运行确认。
- **部署相关**：`hvigorw`/`hdc`/`hap-sign-tool.jar` 路径以及 `assembleHap`、`assembleApp`、`hdc install -r`、`aa start`、`sign-app` 参数取自本机 DevEco 6.0.2.670 工具链的实际帮助输出。Web 版三种形态都实测过：Node 服务同源托管（端点自动推导为 `<站点>/api/generate`，生成走服务端，控制台无报错）；`node scripts/pack-web.js` 产出的静态包用纯静态服务器发布，浏览器里 14 个组件正常渲染、拖入节点生效、`config.js` 里的远端服务地址被采用并跨源生成成功，取消勾选"调用本地服务"后纯本地生成 21 节点，无服务时徽标如实提示"服务返回 501"并回退本地；`file://` 双击页面调 `http://localhost:3000` 也实测通过。打包脚本的失败保护同样实测：输出目录被静态服务器占用时报 `EBUSY` 并退出码 1，旧包内容保持原样。服务的路径穿越防护实测 `/%2e%2e%2fserver/index.js` 返回 403。未实测的部分：`docker build`（本机无 Docker，只验证了它复刻的 `/app` 目录布局可用）、HAP 签名与真机安装（无设备、无证书）、pm2 / systemd / nginx 实机部署（配置按官方参数与本机实测布局书写，未在本机运行）。

---

## 七、部署

本机实测过的路径：DevEco Studio 6.0.2.670 自带 `node`/`hvigor`/`jbr`/`hdc`/`hap-sign-tool.jar`，构建产物是未签名 HAP，签名后才能安装。以下命令中的绝对路径按你的安装位置替换。

### 7.1 HarmonyOS 应用（.hap / .app）

**① 构建**

```bat
set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" ^
  "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --no-daemon assembleHap
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`（当前工程的 `build-profile.json5` 里 `signingConfigs` 为空，所以只有未签名包；未签名包安装会被设备拒绝）。

**② 签名（二选一）**

日常自测最省事：DevEco Studio → `File → Project Structure → Project → Signing Configs` → 勾选 `Automatically generate signature` 并登录开发者账号，IDE 会把签名配置写进 `build-profile.json5`，之后无论 IDE 还是命令行构建都会产出 `entry-default-signed.hap`。

CI / 无 IDE：准备好密钥库（.p12/.jks）、应用证书（.cer）、Provision Profile（.p7b），用 SDK 自带的签名工具（参数用 `-h` 打印）：

```bat
"C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe" -jar ^
  "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar" ^
  sign-app -mode localSign -keyAlias "<alias>" -keyPwd <密钥密码> ^
    -appCertFile app-release-cert.cer -profileFile signed-profile.p7b ^
    -inFile entry-default-unsigned.hap -signAlg SHA256withECDSA ^
    -keystoreFile app-keypair.jks -keystorePwd <库密码> -compatibleVersion 22 ^
    -outFile entry-default-signed.hap
```

**③ 安装 / 启动 / 日志 / 卸载**

```bat
set HDC=C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe
"%HDC%" list targets
"%HDC%" install -r entry-default-signed.hap
"%HDC%" shell aa start -a EntryAbility -b com.example.arkuibuilder
"%HDC%" hilog
"%HDC%" uninstall com.example.arkuibuilder
```

`list targets` 确认设备/模拟器已连接；`install -r` 覆盖安装；`hilog` 看运行日志；`uninstall -k` 保留数据。设备无线连接用 `"%HDC%" tconn <设备IP>:<端口>`。`.app` 上架包用 `hvigorw --no-daemon assembleApp`（hvigor 已确认支持该任务），证书 / Profile / 提审材料走 AppGallery Connect，本文件不覆盖 AGC 流程。

### 7.2 AI 服务 + Web 版（单进程，推荐）

`node server/index.js` 同时提供 `/api/generate`、`/api/health` 和 Web 静态页，零依赖、无需 `npm install`，Node 18+ 即可。

服务**不读取 `.env` 文件**，环境变量要交给进程管理器注入：

```bash
# 前台试跑
cd arkui-drag-drop-tool/server && PORT=3000 OPENAI_API_KEY=sk-xxx node index.js
curl http://127.0.0.1:3000/api/health    # {"ok":true,"mode":"llm","model":"..."}
```

**pm2**

```js
// ecosystem.config.js
module.exports = { apps: [{
  name: 'arkui-builder',
  script: 'server/index.js',
  cwd: '/opt/arkui/arkui-drag-drop-tool',
  env: { PORT: 3000, HOST: '127.0.0.1', OPENAI_API_KEY: 'sk-xxx', OPENAI_BASE_URL: 'https://api.deepseek.com/v1', OPENAI_MODEL: 'deepseek-chat' }
}] };
```

```bash
pm2 start ecosystem.config.js && pm2 save && pm2 startup   # 日志：pm2 logs arkui-builder
```

**systemd**（`/etc/systemd/system/arkui-builder.service`；密钥放 `EnvironmentFile=/etc/arkui/arkui.env` 并 `chmod 600`，别写进仓库）

```ini
[Unit]
Description=ArkUI Builder service
After=network.target

[Service]
WorkingDirectory=/opt/arkui/arkui-drag-drop-tool/server
ExecStart=/usr/bin/node index.js
Environment=PORT=3000
Environment=HOST=127.0.0.1
EnvironmentFile=/etc/arkui/arkui.env
Restart=always
RestartSec=3
User=www-data

[Install]
WantedBy=multi-user.target
```

**Docker**：工程根目录已提供 [arkui-drag-drop-tool/Dockerfile](file:///D:/work/arkui-tools/arkui-drag-drop-tool/Dockerfile)（`node:18-alpine`、非 root 运行、带 `/api/health` 健康检查，把 `server/ shared/ web/` 拷成同级目录，与容器内 `/app` 布局一致）。

```bash
cd arkui-drag-drop-tool
docker build -t arkui-builder .
docker run -d -p 3000:3000 -e OPENAI_API_KEY=sk-xxx -e OPENAI_MODEL=deepseek-chat \
  -e OPENAI_BASE_URL=https://api.deepseek.com/v1 --name arkui-builder arkui-builder
```

本机未安装 Docker，所以 `docker build` 未实测；但镜像内的目录布局已用等价的暂存目录跑通（见"验证状态"）。

**nginx 反代 + HTTPS**

```nginx
server {
  listen 443 ssl;
  server_name arkui.example.com;
  ssl_certificate     /etc/ssl/arkui/fullchain.pem;
  ssl_certificate_key /etc/ssl/arkui/privkey.pem;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

站点和 API 同源，浏览器不会拦混合内容；服务自身的 CORS 头会原样透传，ArkUI 应用也可以直连这个域名。更完整的站点配置（gzip、入口页不缓存、`/api/` 限流与超时对齐）见 [deploy/nginx-web.conf](file:///D:/work/arkui-tools/arkui-drag-drop-tool/deploy/nginx-web.conf)。

**公网暴露前必读**

- `/api/generate` 无鉴权，且响应头是 `Access-Control-Allow-Origin: *`：直接公网开放等于给所有人一个免费调用你大模型 Key 的代理。生产请让服务 `HOST=127.0.0.1`，在 nginx 侧加 Basic Auth / IP 白名单 / `limit_req` 限流。
- API Key 只在服务端环境变量里，不会下发到浏览器；未配置 Key 时自动退化为内置规则引擎，功能不中断。
- 只监听回环时，真机/模拟器无法直连；需要局域网访问就用 `HOST=0.0.0.0` 并放行防火墙（Windows，管理员）：
  `netsh advfirewall firewall add rule name="arkui-builder" dir=in action=allow protocol=TCP localport=3000`

### 7.3 Web 版部署

Web 版是不打包也能跑的普通脚本页面（无模块加载器、无构建步骤），但有两个部署约束必须先解决：

1. `web/index.html` 用 `../shared/*.js` 引入共享逻辑 → 静态主机必须能在**页面所在目录的上一级**取到 `shared/`；
2. AI 接口地址默认按同源推导 → 前端要能指定实际服务地址。

对应两个产物：打包脚本 [scripts/pack-web.js](file:///D:/work/arkui-tools/arkui-drag-drop-tool/scripts/pack-web.js)（把 `web/` 内容与 `shared/` 合成一个自包含静态包，顺带写死服务地址）和配置入口 [web/config.js](file:///D:/work/arkui-tools/arkui-drag-drop-tool/web/config.js)。

```bash
cd arkui-drag-drop-tool
node scripts/pack-web.js                                  # → dist/ ，端点走同源推导
node scripts/pack-web.js D:/www/arkui https://api.example.com/api/generate   # 指定输出目录 + AI 服务地址
```

脚本先写临时目录再整体替换目标，目标被静态服务器占用（Windows 会锁目录）而失败时，旧包保持原样并打印原因。包内文件：`index.html`、`css/`、`js/`、`config.js`、`shared/`（registry / rules / generator 三份）。

#### 形态一：页面与 AI 服务同源（推荐）

直接跑 7.2 的 Node 服务，静态页和 `/api/generate` 同一进程、同一域名，前端零配置——页面地址是 `https?://host` 时，AI 服务地址自动填成 `<站点根>/api/generate`。适合内网小团队；对外服务请套 nginx + 鉴权（见 7.2 的"公网暴露前必读"）。

#### 形态二：静态托管页面 + 独立部署的 AI 服务

```bash
node scripts/pack-web.js dist https://arkui-api.example.com/api/generate   # 地址已写进 dist/config.js
```

把 `dist/` 的内容传到任何静态主机（Nginx/Caddy、GitHub Pages、Vercel/Netlify、OSS/COS 对象存储、CDN），站点根就是 `dist/` 里的文件，`/shared/…` 与 `/config.js` 天然可取。

- GitHub Pages：把 `dist/` 内容放进仓库根或 `docs/` 目录推送即可（`index.html` 必须在站点根，否则 `../shared` 会跑到仓库外）。
- 想在子路径下发布（例如 `https://host/tools/arkui/`）：页面资源是相对引用，能正常加载；但同源推导会把端点算成 `https://host/api/generate`，所以必须用 `config.js`（或打包命令的第二个参数）写明确切地址。退路是让用户在页面输入框手填——它存 localStorage，优先级高于 `config.js`。
- 服务端已放开 `Access-Control-Allow-Origin: *` 并暴露 `X-ArkUI-Source`，跨源调用无需额外配置；站点是 HTTPS 时端点也必须 HTTPS，否则浏览器按混合内容拦截。
- 不想接大模型：取消勾选"调用本地服务"，AI 输入框纯走浏览器内置规则引擎，不发任何请求。留着勾选时，同源推导仍会填上 `<站点>/api/generate`，请求会失败（静态主机返回 404/501 或连接被拒），页面照常回退本地生成，但浏览器控制台会留下一次对应的资源加载报错——这是预期现象，不是页面坏了。

nginx 完整样例见 [deploy/nginx-web.conf](file:///D:/work/arkui-tools/arkui-drag-drop-tool/deploy/nginx-web.conf)（含 gzip、`index.html` 不缓存、`/api/` 反代 + 限流、超时对齐）；也可以不打包，直接把 `root` 指 `web`、`/shared/` alias 到工程的 `shared/`：

```nginx
location /shared/ { alias /opt/arkui/arkui-drag-drop-tool/shared/; types { } default_type text/javascript; }
location /        { root /opt/arkui/arkui-drag-drop-tool/web; index index.html; }
```

保留工程结构（`web/` 与 `shared/` 同级）也能跑：`https://host/web/` 下 `../shared/` 解析成站点根的 `/shared/`，前提是静态主机把工程根当 docroot。

#### 形态三：`file://` 双击（仅个人机器）

双击 `arkui-drag-drop-tool/web/index.html`，`../shared/` 走真实磁盘相邻关系，离线可用；此时端点保留 `http://localhost:3000/api/generate`，本机的 Node 服务能直接被跨源调用（实测通过）。不能对外提供服务。

#### AI 服务地址的优先级

页面输入框（localStorage，改过就长期生效）> `config.js` 的 `window.ARKUI_ENDPOINT` > http(s) 同源 `/api/generate` > `file://` 时的 `http://localhost:3000/api/generate`。代码位置：`web/js/app.js:857-876`。

#### 部署后自检

```bash
curl -s  https://host/                       # 200，含 <title>ArkUI 拖放工具 · Web 版</title>
curl -s  https://host/shared/rules.js        # 200（404 说明 shared 没落到站点根）
curl -s  https://host/api/health             # {"ok":true,"mode":"llm|rules",...}
curl -s -X POST https://host/api/generate -H 'Content-Type: application/json' \
     --data-binary @utf8prompt.json          # 返回组件树 JSON；中文提示词请用文件传，避免 shell 编码问题
```

浏览器侧确认：组件面板 14 个瓦片、拖入画布生成节点、"导出 .ets" 能下载、AI 徽标显示走的通路（大模型生成 / 服务端规则生成 / 本地规则生成 / 服务不可用回退）；服务可达时控制台应保持干净（形态二没有 `/api/health`，上面第三条 curl 404 属预期）。

本机实测结果：

- 形态一（Node 服务同源，`http://localhost:3000/`）：端点自动推导为 `http://localhost:3000/api/generate`，生成走服务端，控制台无报错。
- 形态二（`pack-web.js` 出的静态包交给纯静态服务器）：14 瓦片渲染正常；第二个参数写进 `config.js` 的地址被页面采用，跨源调用本机 3000 的服务成功生成 10 节点，拖入 `Image` 由 4 节点变 5 节点；把地址换成不可达的服务时徽标如实显示"服务不可用，本地生成（服务返回 501）"并照常出树，取消勾选后走纯本地生成 21 节点。
- 形态三（`file://` 双击）：跨源调用本机 3000 的服务生成 7 节点。

#### 常见故障

| 现象 | 原因与处理 |
|------|------------|
| 页面打开空白、控制台报 `registry.js` 404 | `shared/` 没在站点根；用 `node scripts/pack-web.js` 重出包，或按上面加 `/shared/` alias |
| 徽标显示"服务不可用，本地生成（服务返回 404 / 501 / Failed to fetch）" | 静态主机上没有 `/api/generate`，或端点写错、HTTPS 页面调 HTTP 端点被拦；功能不受影响（已回退本地规则），要接大模型就改 `config.js` 或输入框 |
| 生成结果徽标是"本地规则生成" | 只可能是没勾上"调用本地服务"——这条通路根本不发请求。勾上后端点为空或路径写错时徽标是"服务不可用，本地生成（服务返回 405 / Failed to fetch）"，属于另一种情况 |
| 生成结果徽标是"服务端规则生成"但你以为走了大模型 | 服务侧没配 `OPENAI_API_KEY`，服务端按设计回退内置规则引擎（`/api/health` 的 `mode` 会显示 `rules`） |
| 刷新后服务地址回到旧值 | localStorage 记住了手填值，优先级最高；在输入框里改成正确值再刷新，或清站点数据 |
| 大刷新后仍是旧页面 | 静态主机缓存了 `index.html`；按 nginx 样例给入口页加 `no-cache` |

### 7.4 ArkUI 应用侧的服务地址

应用内"设置"里改端点（默认 `http://10.0.2.2:3000/api/generate`），改完即时生效、无需重装；`AiClient` 连接超时 8s、读取超时 60s，失败时界面回退提示而不卡住。

| 场景 | 端点 |
|------|------|
| 模拟器（宿主机即本机） | `http://10.0.2.2:3000/api/generate` |
| 真机 + 同网段电脑 | `http://<电脑局域网IP>:3000/api/generate`，`HOST=0.0.0.0` 且放行防火墙 |
| 已部署的服务器 | `https://arkui.example.com/api/generate` |

系统若限制明文 HTTP，就给服务挂 HTTPS 证书后改用 `https://` 端点。

---

## 八、目录

```
arkui-drag-drop-tool/
├── .gitignore                      # 忽略构建产物 / 静态包 / 签名材料与密钥
├── Dockerfile                      # 七、部署：服务 + Web 静态页的容器镜像
├── AppScope/                       # bundleName: com.example.arkuibuilder
├── entry/src/main/
│   ├── ets/
│   │   ├── components/
│   │   │   ├── DragDropEngine.ets  # §5.1 拖放引擎：坐标框注册表 + 命中检测
│   │   │   └── NodeRenderer.ets    # 递归节点渲染 + 长按/平移手势
│   │   ├── model/
│   │   │   └── ComponentModel.ets  # §5.2 组件树数据结构与树操作
│   │   ├── pages/
│   │   │   ├── Index.ets           # 主页面：宽屏三栏 / 窄屏四页签 + AI 输入条
│   │   │   ├── CanvasArea.ets      # §3.2 画布与工具条
│   │   │   ├── ComponentPanel.ets  # §3.1 组件面板
│   │   │   ├── PropertyPanel.ets   # §3.3 属性配置
│   │   │   └── CodePreview.ets     # §3.4 代码预览/复制/导出
│   │   └── utils/
│   │       ├── AiClient.ets        # §3.5 调用 /api/generate
│   │       └── CodeGenerator.ets   # §5.3 代码生成器
│   └── resources/
├── server/
│   ├── index.js                    # AI 服务 + 静态资源托管（零依赖）
│   └── package.json
├── shared/
│   ├── registry.js                 # 组件注册表（与 ComponentModel.ets 对齐）
│   ├── rules.js                    # 离线自然语言规则引擎 + 外部树 sanitize
│   └── generator.js                # 代码生成器 JS 版（与 CodeGenerator.ets 对齐）
├── scripts/
│   └── pack-web.js                 # §7.3 静态包打包：web/ + shared/ 合成自包含目录
├── deploy/
│   └── nginx-web.conf              # §7.3 静态站 + 同源反代样例（gzip / 缓存 / 限流）
└── web/
    ├── index.html                  # 双击即可运行；也可由 server 或静态主机托管
    ├── config.js                   # §7.3 部署期可选：window.ARKUI_ENDPOINT 指定 AI 服务地址
    ├── css/app.css
    └── js/app.js
```

`node scripts/pack-web.js` 的默认产物 `dist/` 是生成物，已在 `.gitignore` 里（连同打包过程的临时目录 `*.tmp-*/`）；删除后随时可重出。指定别的输出目录名时，记得把那个名字也加进 `.gitignore`。
