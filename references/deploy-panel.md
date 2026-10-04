# 安装面板

安装 3x-ui 时必须以官方最新文档为准：

```text
https://docs.sanaei.dev/docs/
https://docs.sanaei.dev/docs/guide/installation/
```

不要依赖旧教程或过期脚本。必要时先查看官方 Installation 文档，确认当前推荐安装方式、脚本参数、安装输出位置和首登安全建议。官方文档目前推荐官方脚本安装 latest stable；脚本会安装服务、生成随机用户名/密码/access web base path、安装 `x-ui` 管理命令，并支持 `XUI_NONINTERACTIVE=1` 非交互安装。

## 安装 3x-ui

1. SSH 登录 VPS。
2. 检查 `curl`，缺少才安装。
3. 安装前如不确定当前最新方式，先查看官方 Installation 文档，不要使用旧教程。
4. 执行官方脚本：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

5. 如需要非交互安装，可按官方文档使用：

```bash
XUI_NONINTERACTIVE=1 bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

6. 从安装输出或 `/etc/x-ui/install-result.env` 读取面板 URL、用户名、密码、端口、web base path。
7. 确认随机端口、随机用户名、随机密码、随机路径已生效。

### 非交互安装与 API 注意

- `XUI_NONINTERACTIVE=1` 会自动生成随机端口、用户名、密码、web base path，并写入 `/etc/x-ui/install-result.env`，但当前版本可能默认跳过 SSL。不要因此交付 HTTP 面板；安装后必须单独申请证书并写入面板 HTTPS 配置。
- 登录接口带 CSRF，直接脚本 POST `/login` 很容易返回 `403`。自动化调用 `/panel/api/*` 时优先使用 `/etc/x-ui/install-result.env` 里的 `XUI_API_TOKEN`，请求头使用 `Authorization: Bearer <token>`。v3.9.0 重新生成命名 Token 会保留原作用域和到期限制；`403` 时先核对 Token 权限/有效期，不自动扩大成永久管理员权限。
- 避免直接通过单条 SSH 命令执行复杂 SQLite SQL；远端 shell 可能吞掉 SQL 字符串中的引号。配置 HTTPS、Clash/Mihomo 订阅等数据库写入时，优先上传 `scripts/configure-panel-https.sh` 到 VPS 后执行。
- 不要调用可能进入交互菜单的 `x-ui version`。v3.9.0 的面板二进制支持非交互 `/usr/local/x-ui/x-ui -v`；脚本优先用它记录面板版本，必要时从服务启动日志辅助确认。读不到则标记未知，不阻塞部署。
- 用本机或外部环境验证面板时，以 `GET https://<面板域名>:<端口>/<webBasePath>/` 返回 `200` 为准。`HEAD` 请求可能返回 `404`；在 VPS 自己访问公网域名也可能受发夹 NAT/回环影响出现 TLS 错误，不能单独判定面板不可用。

## Xray Core

使用 3x-ui 官方稳定版配套的 Xray Core，不再固定或降级到旧版本。本轮核对基线是 3x-ui `v3.9.0` / Xray Core `v26.9.30`；以后安装前仍查询官方最新稳定版及其配套 Core。面板版本、Core 版本和 Skill 版本分别记录。

- 不要手动覆盖 `/usr/local/x-ui/bin/xray-linux-*`。
- 按实际 CPU 架构和服务进程核对使用的 `/usr/local/x-ui/bin/xray-linux-*`，再执行 `<实际Core二进制> version`；不要在 ARM VPS 上硬编码 amd64。
- 只有官方后续发布明确要求、且用户同意时，才在面板的 Xray Core 管理界面切换版本；切换后重启 `x-ui` 并重新做真实连通性测试。

## v3.9.0 适配边界

- 新部署使用官方配套 Core；已有面板升级前备份数据库、记录现有面板/Core 版本、入站和客户端状态。面板版本号不代表正在运行的 Core 已同步更新。
- 入站保存不再覆盖已有客户端的配额、续期、到期、启用或实时计数；客户端维护用专用接口。入站启用使用 `/panel/api/inbounds/setEnable/{id}`，详见 `client-lifecycle.md`。
- REALITY 通用 VLESS 链接会携带 `support-x25519mlkem768=true`；导出后仍要核对转换器及终端配置，见 `subscription.md`。`minClientVer` 的新旧 Core 差异见 `inbounds.md`，不再无条件固定 1.0.0。
- 使用 maskXDNS 等新掩码格式时，相关客户端 Core 也需支持 v26.9.30 的格式；不能只升级服务端。未使用此功能的普通 Reality 节点不要因此增加新掩码设置。
- v3.9.0 新增原生 TUIC v5 与日历周续期等能力，不代表默认要额外创建 TUIC、改变现有节点协议或开启续期。本 Skill 仍按用户选择创建原来的 5 个入站。

## 配置 HTTPS

优先参考官方文档和 `x-ui` 菜单的 SSL 管理功能申请/设置证书。失败时再安装 `certbot`，用 standalone 方式申请 Let's Encrypt。

常见证书路径：

```text
/etc/letsencrypt/live/<面板域名>/fullchain.pem
/etc/letsencrypt/live/<面板域名>/privkey.pem
```

当前 SQLite 面板 HTTPS 配置的 settings 表使用：

```text
webCertFile=/etc/letsencrypt/live/<面板域名>/fullchain.pem
webKeyFile=/etc/letsencrypt/live/<面板域名>/privkey.pem
```

写入前备份 `/etc/x-ui/x-ui.db`，写入后重启 `x-ui` 并验证 `systemctl is-active x-ui` 与外部 `GET` 面板 URL。

推荐把仓库脚本上传到 VPS 后执行，避免手写多层引号：

```bash
scripts/configure-panel-https.sh <面板域名>
```

该脚本会：

- 使用 certbot standalone 申请或复用 Let's Encrypt 证书。
- 备份 `/etc/x-ui/x-ui.db`。
- 写入 `webCertFile`、`webKeyFile`、`subClashEnable=true` 和 `subClashPath=/clash/`。
- 重启 `x-ui`，并用 `https://127.0.0.1:<面板端口>/<webBasePath>/` 验证返回码。

## 开启 Clash/Mihomo 订阅

3x-ui 的 Clash/Mihomo 开关是 `settings.subClashEnable`，默认 `false`。不开启时 `/clash/:subid` 不返回 Clash/Mihomo YAML。

若未使用 `scripts/configure-panel-https.sh`，再通过 SSH 自动开启：

```bash
sqlite3 /etc/x-ui/x-ui.db ".schema settings"
cp /etc/x-ui/x-ui.db /etc/x-ui/x-ui.db.bak.subclash
sqlite3 /etc/x-ui/x-ui.db "INSERT INTO settings (key,value) SELECT 'subClashEnable','true' WHERE NOT EXISTS (SELECT 1 FROM settings WHERE key='subClashEnable'); UPDATE settings SET value='true' WHERE key='subClashEnable'; INSERT INTO settings (key,value) SELECT 'subClashPath','/clash/' WHERE NOT EXISTS (SELECT 1 FROM settings WHERE key='subClashPath'); UPDATE settings SET value='/clash/' WHERE key='subClashPath' AND (value='' OR value IS NULL);"
systemctl restart x-ui
sqlite3 /etc/x-ui/x-ui.db "SELECT key,value FROM settings WHERE key IN ('subClashEnable','subClashPath');"
```

如果没有 `sqlite3`，先安装。执行修改前必须确认 `settings` 表存在 `key`、`value` 字段；如果表结构不同，停止并说明当前 3x-ui 版本数据库结构不一致，不要盲改。

## 本机防火墙

自动按当前系统工具放行：

- SSH 端口
- `80/tcp`
- `443/tcp`
- 面板端口
- 后续入站主端口
- HY2: UDP 主端口和 UDP `48000-50000`

如果本机没启用防火墙，不要强行安装复杂防火墙。最终说明“本机防火墙未启用”。

## 关闭 IPv6

写入并应用：

```bash
cat >/etc/sysctl.d/99-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
sysctl --system
cat /proc/sys/net/ipv6/conf/all/disable_ipv6
```

最后检查：

```bash
systemctl is-active x-ui
x-ui settings
```

`x-ui settings` 含登录凭据，仅用于受控读取或用户要求的首次交付，不复制到诊断日志、GitHub 或公开报告。

依据：[v3.9.0 Release](https://github.com/MHSanaei/3x-ui/releases/tag/v3.9.0)、[该版本非交互版本参数](https://github.com/MHSanaei/3x-ui/blob/v3.9.0/main.go)。
