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

### 3x-ui 3.5.0 实测注意

- `XUI_NONINTERACTIVE=1` 会自动生成随机端口、用户名、密码、web base path，并写入 `/etc/x-ui/install-result.env`，但当前版本可能默认跳过 SSL。不要因此交付 HTTP 面板；安装后必须单独申请证书并写入面板 HTTPS 配置。
- 3x-ui 3.5.0 登录接口带 CSRF，直接脚本 POST `/login` 很容易返回 `403`。自动化调用 `/panel/api/*` 时优先使用 `/etc/x-ui/install-result.env` 里的 `XUI_API_TOKEN`，请求头使用 `Authorization: Bearer <token>`。
- 避免直接通过单条 SSH 命令执行复杂 SQLite SQL；远端 shell 可能吞掉 SQL 字符串中的引号。配置 HTTPS、Clash/Mihomo 订阅等数据库写入时，优先上传 `scripts/configure-panel-https.sh` 到 VPS 后执行。
- 不要用可能进入交互菜单或返回 `Invalid subcommands` 的 `x-ui version` 作为自动脚本中的版本探测。需要记录 3x-ui 版本时，优先从 `systemctl status x-ui --no-pager -l` 中解析 `Starting x-ui <version>`；读不到就跳过版本日志，不得阻塞 cron 或部署流程。
- 用本机或外部环境验证面板时，以 `GET https://<面板域名>:<端口>/<webBasePath>/` 返回 `200` 为准。`HEAD` 请求可能返回 `404`；在 VPS 自己访问公网域名也可能受发夹 NAT/回环影响出现 TLS 错误，不能单独判定面板不可用。

## 固定 Xray Core 版本

3x-ui `3.5.0` 默认或更新后可能使用 Xray Core `26.7.11`。已知该版本可能导致配置正确的 VLESS Reality 节点在部分客户端不通。安装 3x-ui 后，必须把 Xray Core 固定到 `26.6.27`。

优先在 3x-ui 面板中操作：

1. 打开面板的 Xray / Core 版本管理。
2. 将 Xray Core 版本选择为 `26.6.27`。
3. 应用后重启 `x-ui`。

如果通过 CLI 或脚本切换，执行前先确认当前 `x-ui` 版本支持对应命令；不要盲目覆盖二进制。切换后验证：

```bash
/usr/local/x-ui/bin/xray-linux-amd64 version | head -1
systemctl restart x-ui
sleep 3
systemctl is-active x-ui
```

期望第一行包含 `Xray 26.6.27`。如果仍是 `26.7.11`，不要继续创建或交付 VLESS Reality 入站，先回到面板切换核心版本。

如果面板没有可用的 Core 版本切换入口，可从 Xray-core 官方 Release 下载 `v26.6.27` 对应架构包，先备份现有 `/usr/local/x-ui/bin/xray-linux-amd64`，再仅替换该二进制。`xray x25519` 在 `26.6.27` 的输出字段是 `PrivateKey:` 和 `Password (PublicKey):`，脚本解析 Reality 密钥时要兼容这个格式。

## 配置 HTTPS

优先参考官方文档和 `x-ui` 菜单的 SSL 管理功能申请/设置证书。失败时再安装 `certbot`，用 standalone 方式申请 Let's Encrypt。

常见证书路径：

```text
/etc/letsencrypt/live/<面板域名>/fullchain.pem
/etc/letsencrypt/live/<面板域名>/privkey.pem
```

写入 3x-ui 3.5.0 面板 HTTPS 配置时，settings 表使用：

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
