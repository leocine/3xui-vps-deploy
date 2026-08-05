# 一键创建 5 个入站

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

3x-ui 3.6.0 自动化优先调用本机面板 API：

```bash
. /etc/x-ui/install-result.env
curl -k -H "Authorization: Bearer ${XUI_API_TOKEN}" \
  "https://127.0.0.1:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH%/}/panel/api/inbounds/list"
```

不要用脚本直接 POST `/login` 获取 cookie；当前登录接口启用 CSRF，容易返回 `403`。调用 API 前先用 `/panel/api/inbounds/list` 验证 Bearer Token 可用。

## 入站列表

1. `US-VLESS-TCP`: VLESS + TCP + Reality，端口 443。
2. `US-VLESS-TCP-01`: VLESS + TCP + Reality，随机 5 位端口。
3. `US-VLESS-XHTTP`: VLESS + XHTTP + Reality，随机 5 位端口。
4. `US-VLESS-TCP-PQ`: VLESS + TCP + 后量子 Reality，随机 5 位端口。
5. `US-HY2-Hop`: Hysteria2 + UDP + TLS，随机 5 位 UDP 主端口，端口跳跃 `48000-50000`。

随机主端口范围 `10000-59999`，避开 `48000-50000`，且四个随机端口必须彼此不同。443 被占用时先询问。

## 节点备注命名

所有自动创建入站的 `remark`，以及导出时保留的节点名称，都必须按以下格式生成：

```text
地区-协议-传输-特性-编号
```

- 地区和协议必须保留；本 Skill 默认地区为 `US`，协议为 `VLESS` 或 `HY2`。
- VLESS 必须保留传输方式：`TCP`、`XHTTP` 或 `WS`。HY2 不写 `UDP`。
- 只允许两个特性：后量子写 `PQ`，HY2 端口跳跃写 `Hop`。
- 不得写入 `Reality`、`TLS`、`CDN`、`Argo`、`Brutal`、端口、客户端 email 或用途文案；CDN 与 Argo 由订阅转换层处理。
- 同一地区、协议、传输和特性完全相同的第一个节点不加编号，后续依次加 `-01`、`-02`。编号永远放在最后。
- 禁止使用 `Random`、`Test`、`Backup` 等临时名称。
- 本次自动创建固定使用：`US-VLESS-TCP`、`US-VLESS-TCP-01`、`US-VLESS-XHTTP`、`US-VLESS-TCP-PQ`、`US-HY2-Hop`。

## 客户端

- 只创建一个逻辑客户端，名称/email 固定为 `admin`。
- 不要创建 `admin-xhttp`、`admin-vless`、`admin-hy2`、`admin01` 或任何按协议拆分的客户端。
- 5 个入站都必须关联到 `admin` 这个客户端；在 3x-ui 支持的情况下，所有入站里的 `admin` 使用同一个 `subId`，保证订阅里聚合到同一个 `admin` 客户端。
- 4 个 VLESS 入站共用同一个随机 UUID，email `admin`。
- HY2 因协议需要使用随机 `auth`，但 email 仍使用 `admin`；如果 3x-ui 支持 `subId`，也使用同一个 `admin` subId。
- `totalGB=0`、`expiryTime=0`、`limitIp=0`。
- TCP Reality（含后量子入站）flow: `xtls-rprx-vision`
- XHTTP Reality flow: 空
- HY2 无 flow

### 3x-ui 3.6.0 客户端表结构

3x-ui 3.6.0 会维护独立的 `clients` 和 `client_inbounds` 表：

```bash
sqlite3 /etc/x-ui/x-ui.db ".schema clients"
sqlite3 /etc/x-ui/x-ui.db ".schema client_inbounds"
```

同一个 email 只能在同一个 `subId` 下跨入站复用；否则 API 会报 `Duplicate email`。创建 5 个入站时必须：

- 预先生成一个随机 `subId`，五个入站里的 `admin` 都使用同一个值。
- 4 个 VLESS 入站使用同一个 UUID，HY2 使用独立随机 `auth`，但仍使用同一个 `subId`。
- 通过 API 新增入站时让 3x-ui 自己同步 `clients`、`client_inbounds` 和运行时配置；直接改 SQLite 时必须同时维护这些表和入站 `settings`，否则订阅、客户端页和 Xray 实际配置可能不一致。
- 创建后检查 `clients` 只有一个逻辑 `admin`，`client_inbounds` 关联到 5 个入站，且 `flow_override` 在三个 TCP Reality 入站为 `xtls-rprx-vision`、XHTTP/HY2 为空。

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

## 后量子 VLESS TCP Reality

- 使用独立的随机 TCP 高位端口和独立的 Reality `privateKey/publicKey`、`shortIds`。
- `remark=US-VLESS-TCP-PQ`，并沿用 TCP Reality 的其余参数与 `xtls-rprx-vision`。
- 在服务端 `realitySettings.mldsa65Seed` 写入当前 Xray Core 执行 `xray mldsa65` 生成的 seed；在客户端 Reality 参数 `settings.mldsa65Verify` 写入同次命令输出的 verify。两项必须是一对，不能混用或手填示例值。
- 该入站的 `mldsa65Seed` 与 `mldsa65Verify` 都不得为空；生成或写入失败时停止创建这个入站并明确报错，不能以普通 Reality 入站冒充后量子节点。
- 先用当前 Xray Core 的 `xray tls ping <target域名>` 检查目标站。ML-DSA-65 会增大临时证书，目标站返回的证书必须大于 3500 bytes；不满足时换一个符合条件的目标与匹配 SNI 后再创建。另记录该目标是否支持 `X25519MLKEM768`：支持时才同时具备后量子密钥协商；仅 ML-DSA-65 时仍是后量子证书签名保护，不能在交付中写成“全链路后量子”。
- 该入站仅面向支持 ML-DSA-65 的新客户端。订阅中仍保留其他三个普通 VLESS 入站作为兼容选项。

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
- `minClientVer=1.0.0`：不要留空。留空会使用 Xray Core 的内置最低版本，可能拒绝 Mihomo、sing-box 等自报版本较低的客户端。
- `maxClientVer` 留空
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

新版 3x-ui 的 Hysteria stream schema 只写入面板明确支持的核心字段：`version`、`auth`、`udpIdleTimeout` 和 TLS 证书。窗口、拥塞、`udpHop` 等扩展项若没有当前面板的明确字段，不要硬塞进 `streamSettings`；端口跳跃继续用 nftables 单独实现并验收。

## HY2 端口跳跃转发

必须在 VPS 上配置 UDP `48000-50000` 转发到 HY2 主端口。优先 nftables：

端口跳跃必须同时满足“运行时生效”和“重启后可恢复”。严禁只执行一次性的 `nft add rule` 或 `iptables -t nat -A ...` 后就交付；这类规则会在 VPS 重启、宿主机维护或网络服务重载后消失，而订阅仍会继续下发 `mport`，表现为 HY2 主端口可用、跳跃节点全部超时。

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
nft -c -f /etc/nftables.conf
nft -f /etc/nftables.conf
nft list ruleset
systemctl is-enabled nftables
systemctl is-active nftables
```

不要使用 `flush ruleset`，不要覆盖用户已有防火墙规则。若 `/etc/nftables.conf` 已有内容，把 `table ip xui_hy2_nat` 合并进去；若文件不存在或为空，只写入 `table ip xui_hy2_nat` 这张表的最小配置。

如果现有系统已经使用 `iptables-persistent`，不要再混用另一套独立规则；使用幂等检查添加规则并保存：

```bash
iptables -t nat -C PREROUTING -p udp --dport 48000:50000 \
  -j REDIRECT --to-ports <HY2主端口> 2>/dev/null || \
iptables -t nat -A PREROUTING -p udp --dport 48000:50000 \
  -j REDIRECT --to-ports <HY2主端口>

systemctl enable netfilter-persistent
netfilter-persistent save
iptables -t nat -S PREROUTING | grep '48000:50000'
grep '48000:50000' /etc/iptables/rules.v4
systemctl is-enabled netfilter-persistent
```

持久化验收必须至少做一次规则重载测试：先确认 SSH 恢复通道和当前防火墙已完整保存，再 reload 对应服务，随后重新检查跳跃规则。不能只检查保存文件，也不能只检查当前内存规则。生产机不需要为了验收主动重启整台 VPS。

最终还要从 VPS 外向至少两个随机跳跃端口进行真实 HY2 握手和代理 HTTPS 请求；普通 UDP 探测包只能证明 NAT 计数命中，不能代替协议连通性测试。

最后重启 x-ui，检查端口监听、nftables 规则和 x-ui 状态。

创建后必须对比数据库与实际运行配置：

```bash
sqlite3 /etc/x-ui/x-ui.db "select id,remark,protocol,port,enable from inbounds order by id;"
sqlite3 /etc/x-ui/x-ui.db "select c.email,i.remark,ci.flow_override from clients c join client_inbounds ci on ci.client_id=c.id join inbounds i on i.id=ci.inbound_id order by i.id;"
for p in 443 <随机TCP端口> <XHTTP端口> <PQ_TCP端口> <HY2端口>; do grep -q "\"port\": $p" /usr/local/x-ui/bin/config.json && echo "config_port_$p=present"; done
```
