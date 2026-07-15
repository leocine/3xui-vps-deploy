# 一键创建 4 个入站

如果用户选择“是”，不要追问客户端信息，默认：

```text
email: admin
流量: 不限制
到期: 长期有效
IP Limit: 不填
```

优先用 3x-ui API；不方便时改 SQLite。改库前：

```bash
cp /etc/x-ui/x-ui.db /etc/x-ui/x-ui.db.bak
```

3x-ui 3.5.0 自动化优先调用本机面板 API：

```bash
. /etc/x-ui/install-result.env
curl -k -H "Authorization: Bearer ${XUI_API_TOKEN}" \
  "https://127.0.0.1:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH%/}/panel/api/inbounds/list"
```

不要用脚本直接 POST `/login` 获取 cookie；当前登录接口启用 CSRF，容易返回 `403`。调用 API 前先用 `/panel/api/inbounds/list` 验证 Bearer Token 可用。

## 入站列表

1. `US-TCP-Reality-443`: VLESS + TCP + Reality，端口 443
2. `US-TCP-Reality-Random`: VLESS + TCP + Reality，随机 5 位端口
3. `US-XHTTP-Reality-Random`: VLESS + XHTTP + Reality，随机 5 位端口
4. `US-HY2-TLS-Hop`: Hysteria2 + UDP + TLS，随机 5 位 UDP 主端口，端口跳跃 `48000-50000`

随机主端口范围 `10000-59999`，避开 `48000-50000`。443 被占用时先询问。

## 客户端

- 只创建一个逻辑客户端，名称/email 固定为 `admin`。
- 不要创建 `admin-xhttp`、`admin-vless`、`admin-hy2`、`admin01` 或任何按协议拆分的客户端。
- 4 个入站都必须关联到 `admin` 这个客户端；在 3x-ui 支持的情况下，所有入站里的 `admin` 使用同一个 `subId`，保证订阅里聚合到同一个 `admin` 客户端。
- 3 个 VLESS 入站共用同一个随机 UUID，email `admin`。
- HY2 因协议需要使用随机 `auth`，但 email 仍使用 `admin`；如果 3x-ui 支持 `subId`，也使用同一个 `admin` subId。
- `totalGB=0`、`expiryTime=0`、`limitIp=0`。
- TCP Reality flow: `xtls-rprx-vision`
- XHTTP Reality flow: 空
- HY2 无 flow

### 3x-ui 3.5.0 客户端表结构

3x-ui 3.5.0 会维护独立的 `clients` 和 `client_inbounds` 表：

```bash
sqlite3 /etc/x-ui/x-ui.db ".schema clients"
sqlite3 /etc/x-ui/x-ui.db ".schema client_inbounds"
```

同一个 email 只能在同一个 `subId` 下跨入站复用；否则 API 会报 `Duplicate email`。创建 4 个入站时必须：

- 预先生成一个随机 `subId`，四个入站里的 `admin` 都使用同一个值。
- 3 个 VLESS 入站使用同一个 UUID，HY2 使用独立随机 `auth`，但仍使用同一个 `subId`。
- 通过 API 新增入站时让 3x-ui 自己同步 `clients`、`client_inbounds` 和运行时配置；直接改 SQLite 时必须同时维护这些表和入站 `settings`，否则订阅、客户端页和 Xray 实际配置可能不一致。
- 创建后检查 `clients` 只有一个逻辑 `admin`，`client_inbounds` 关联到 4 个入站，且 `flow_override` 在两个 TCP Reality 入站为 `xtls-rprx-vision`、XHTTP/HY2 为空。

## VLESS 通用

- `decryption=none`
- `encryption=none`
- `sniffing.enabled=false`
- `fingerprint=chrome`

## TCP Reality

- `network=tcp`
- `security=reality`
- `tcpSettings.acceptProxyProtocol=false`
- `tcpSettings.header.type=none`
- `target=www.nvidia.com:443`
- `serverNames=["www.nvidia.com"]`
- 每个 Reality 入站单独生成 `privateKey/publicKey`
- `shortIds` 生成 8 个随机短 ID

`xray x25519` 输出格式要兼容：

```text
PrivateKey: <private>
Password (PublicKey): <public>
```

## XHTTP Reality

- `network=xhttp`
- `security=reality`
- `xhttpSettings.path` 随机短路径，例如 `/f9c2`
- `host` 留空
- `mode=auto`
- `xPaddingBytes=100-1000`
- `scMaxEachPostBytes=1000000`
- `scMaxBufferedPosts=30`
- `scStreamUpServerSecs=20-80`
- `target=www.intel.com:443`
- `serverNames=["www.intel.com"]`

## Reality 通用

- `spiderX=/`
- `show=false`
- `xver=0`
- `minClientVer`、`maxClientVer` 留空
- `maxTimediff=0`

## HY2

- `protocol=hysteria`
- `network=hysteria`
- `settings.version=2`
- `hysteriaSettings.version=2`
- `hysteriaSettings.udpIdleTimeout=60`
- `security=tls`
- `tlsSettings.serverName=<面板域名>`
- `tlsSettings.minVersion=1.2`
- `tlsSettings.maxVersion=1.3`
- `tlsSettings.alpn=["h3","h2","http/1.1"]`
- `tlsSettings.certificates` 使用面板域名证书
- `finalmask.quicParams.congestion=bbr`
- `udpHop.ports=48000-50000`
- `udpHop.interval=5-10`
- `initStreamReceiveWindow=8388608`
- `maxStreamReceiveWindow=8388608`
- `initConnectionReceiveWindow=20971520`
- `maxConnectionReceiveWindow=20971520`
- `maxIdleTimeout=30`
- `keepAlivePeriod=10`
- `disablePathMTUDiscovery=false`
- `maxIncomingStreams=1024`

3x-ui 3.5.0 / Xray 26.6.27 的 Hysteria stream schema 只稳定支持 `version`、`auth`、`udpIdleTimeout` 和 TLS 证书等核心字段。窗口、拥塞、`udpHop` 等扩展项如果不是当前面板/Xray wire shape 明确支持，不要硬塞进 `streamSettings`；端口跳跃用 nftables 单独实现并验收。

## HY2 端口跳跃转发

必须在 VPS 上配置 UDP `48000-50000` 转发到 HY2 主端口。优先 nftables：

```text
table ip xui_hy2_nat {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    udp dport 48000-50000 redirect to :<HY2主端口>
  }
}
```

执行：

```bash
cp /etc/nftables.conf /etc/nftables.conf.bak.hy2 2>/dev/null || true
systemctl enable --now nftables
nft -f /etc/nftables.conf
nft list ruleset
```

不要使用 `flush ruleset`，不要覆盖用户已有防火墙规则。若 `/etc/nftables.conf` 已有内容，把 `table ip xui_hy2_nat` 合并进去；若文件不存在或为空，只写入 `table ip xui_hy2_nat` 这张表的最小配置。

最后重启 x-ui，检查端口监听、nftables 规则和 x-ui 状态。

创建后必须对比数据库与实际运行配置：

```bash
sqlite3 /etc/x-ui/x-ui.db "select id,remark,protocol,port,enable from inbounds order by id;"
sqlite3 /etc/x-ui/x-ui.db "select c.email,i.remark,ci.flow_override from clients c join client_inbounds ci on ci.client_id=c.id join inbounds i on i.id=ci.inbound_id order by i.id;"
for p in 443 <随机TCP端口> <XHTTP端口> <HY2端口>; do grep -q "\"port\": $p" /usr/local/x-ui/bin/config.json && echo "config_port_$p=present"; done
```
