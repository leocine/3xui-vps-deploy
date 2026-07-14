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

## 配置 HTTPS

优先参考官方文档和 `x-ui` 菜单的 SSL 管理功能申请/设置证书。失败时再安装 `certbot`，用 standalone 方式申请 Let's Encrypt。

常见证书路径：

```text
/etc/letsencrypt/live/<面板域名>/fullchain.pem
/etc/letsencrypt/live/<面板域名>/privkey.pem
```

## 开启 Clash/Mihomo 订阅

3x-ui 的 Clash/Mihomo 开关是 `settings.subClashEnable`，默认 `false`。不开启时 `/clash/:subid` 不返回 Clash/Mihomo YAML。

通过 SSH 自动开启：

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
