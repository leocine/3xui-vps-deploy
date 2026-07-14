# 预检与失败恢复

目标是一键部署，但先自动做低打扰预检。除非发现硬风险，不要频繁询问用户。

## 自动预检

拿到 VPS 信息后先执行：

```bash
whoami
cat /etc/os-release
uname -a
ip -4 addr
ip -6 addr
ss -lntup
systemctl is-active x-ui 2>/dev/null || true
command -v curl || true
command -v sqlite3 || true
command -v nft || true
command -v ufw || true
command -v firewall-cmd || true
```

本机或 VPS 上验证 DNS：

```bash
getent ahostsv4 <PANEL_DOMAIN>
```

必要时从用户本机角度提醒用户执行：

```bash
nslookup <PANEL_DOMAIN>
```

必须确认：

- 系统是 Debian 或 Ubuntu。
- 当前用户是 `root`。
- VPS 有公网 IPv4。
- 面板域名解析到 VPS IPv4。
- Cloudflare 同名 AAAA 记录已经删除；如果解析仍返回 IPv6，停止部署，先回到 `cloudflare-dns.md` 修正。
- SSH 端口正在监听，不要改坏 SSH。
- `80/tcp` 可用于申请证书，或能临时停掉占用进程。
- `443/tcp` 如果要创建 443 入站，必须未被其他服务占用；占用时停下询问。

## 预检失败处理

- DNS 不对：停止部署，回到 `cloudflare-dns.md`。
- 仍返回 IPv6：停止部署，删除 Cloudflare 同名 AAAA 记录后再继续。
- 非 Debian/Ubuntu：停止部署，说明不支持自动部署。
- 不是 root：要求换 root 或提供 sudo 能力。
- 没有公网 IPv4：停止部署，说明 Reality/HY2 面板域名方案不适合。
- 80 被占用：先识别进程；如果是旧 web 服务或旧 x-ui，停下询问是否临时停止。
- 443 被占用：如果用户选择创建 443 入站，必须停下询问；不要强行覆盖。

## 失败恢复

3x-ui 安装中断：

```bash
systemctl status x-ui --no-pager
journalctl -u x-ui -n 100 --no-pager
x-ui status 2>/dev/null || true
```

证书申请失败：

- 检查域名是否灰云、是否返回 VPS IPv4。
- 检查 `80/tcp` 是否被占用。
- 检查本机防火墙是否放行 `80/tcp`。
- 修复后重试证书申请。

数据库修改失败：

- 不继续叠加修改。
- 使用最近的备份恢复，例如：

```bash
cp /etc/x-ui/x-ui.db.bak.subclash /etc/x-ui/x-ui.db
systemctl restart x-ui
```

面板打不开：

- 检查 x-ui 是否 active。
- 检查面板端口是否监听。
- 检查本机防火墙。
- 如果本机监听正常但外部不通，提示用户检查 VPS 商家安全组。

HY2 不通：

- 检查 UDP 主端口监听。
- 检查 UDP `48000-50000` 是否放行。
- 检查 nftables 跳跃转发是否存在。
- 用 tcpdump 判断外部 UDP 是否到达 VPS；如果完全不到达，提示可能是商家限制 UDP 或安全组未放行。
