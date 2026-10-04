# 安装后验证与交付

部署完成后必须验证，不要只报告“命令已执行”。

复杂验收查询优先上传并执行 `scripts/validate-deployment.sh`，不要把多段 SQLite 查询、grep 和端口列表拼进一条 SSH 命令。该脚本读取 `/etc/x-ui/install-result.env` 和可选部署状态文件，只读输出版本、证书、订阅、客户端生命周期、入站、端口、HY2 NAT 和调优摘要；不打印密码、Token、秘密面板路径或原始状态文件。执行示例：

```bash
scripts/validate-deployment.sh <面板域名> /root/3xui-deploy-state.env [目标客户端email]
```

如果自动入站脚本使用了自定义状态文件名，把第二个参数替换为实际路径。脚本输出可作为服务器侧验收依据；真实代理连通性仍必须继续按 `connectivity-test.md` 从 VPS 外部测试。

第三个参数默认 `admin`，生命周期摘要仅查询指定客户端。非默认安装可用 `XUI_INSTALL_ENV`、`XUI_DB_PATH`、`XUI_CONFIG_PATH`、`XUI_PANEL_BINARY`、`XUI_XRAY_BINARY` 指定受控文件/二进制路径；未指定时按正常安装目录及 CPU 架构定位。摘要中的 `timeLocation=Local` 仍需核对面板实际本地时区，不能直接当作北京时间。

## 基础验证

```bash
systemctl is-active x-ui
/usr/local/x-ui/x-ui -v
ss -lntup
<实际架构的Xray二进制> version
```

确认：

- `x-ui` 是 `active`。
- 面板端口正在监听。
- 面板 URL、用户名、密码、端口、web base path 可从安装结果或配置中读取。
- HTTPS 证书文件存在。
- Clash/Mihomo 订阅已开启。
- Xray Core 版本已记录，使用 3x-ui 官方稳定版随面板安装的版本，未手动替换二进制。
- 面板版本已单独记录；v3.9.0 的配套 Core 基线为 v26.9.30，不与 Skill 的 v1.x.x 混淆。
- IPv6 已关闭或至少系统优先 IPv4。
- 调优脚本 1、2、3、4 已执行。

## Clash/Mihomo 验证

```bash
sqlite3 /etc/x-ui/x-ui.db "SELECT key,value FROM settings WHERE key IN ('subClashEnable','subClashPath');"
```

期望：

```text
subClashEnable|true
subClashPath|/clash/
```

## 入站验证

如果创建了入站，确认：

- 5 个入站都启用，且名称严格为 `US-VLESS-TCP`、`US-VLESS-TCP-01`、`US-VLESS-XHTTP`、`US-VLESS-TCP-PQ`、`US-HY2-Hop`。
- 只有一个逻辑客户端 `admin`，没有 `admin-xhttp`、`admin-vless`、`admin-hy2`、`admin01` 这类拆分客户端。
- 5 个入站都关联到 `admin`；4 个 VLESS 入站使用同一个 `admin` 客户端 UUID。
- HY2 有随机 auth。
- 如果启用 Reality ML-DSA-65，数据库和实际运行配置中都有非空的 `mldsa65Seed`，订阅下发的该节点有配对的非空 `mldsa65Verify`；如果启用 VLESS ML-KEM-768，则服务端 `decryption` 和客户端/订阅 `encryption` 均存在；不得在验收输出中泄露任何完整值。
- 新版还要确认 `clients` 表里只有一个逻辑 `admin`，并通过 `client_inbounds` 关联到 5 个入站；5 个关联使用同一个 `sub_id`。仅针对首次部署验收，已有面板维护不能把其他合法客户端当作错误或删除。
- 443 入站监听 `443/tcp`。
- 随机 VLESS 入站监听对应 TCP 端口。
- HY2 主端口监听 UDP。
- HY2 端口跳跃 `48000-50000` 已写入 nftables 或 iptables-persistent，当前运行规则与持久化文件一致。
- 对应持久化服务为 `enabled`，规则在安全 reload 后仍存在；不得把仅存在于运行内存的 NAT 规则标记为通过。

检查示例：

```bash
ss -lntup | grep -E ':(443|<随机TCP端口>|<XHTTP端口>|<PQ_TCP端口>)'
ss -lunp | grep '<HY2主端口>'
nft list ruleset
```

若使用 iptables-persistent，改为检查：

```bash
iptables -t nat -S PREROUTING | grep '48000:50000'
grep '48000:50000' /etc/iptables/rules.v4
systemctl is-enabled netfilter-persistent
```

## 运行配置一致性验证

3x-ui 面板数据库和 Xray 实际运行配置必须一致。尤其在修改 UUID、flow、Reality 密钥、SNI/serverNames、shortId、`minClientVer` 后，不能只看面板或订阅。

对比同端口入站的 UUID、flow、Reality 目标和 shortId 时仅在受控环境比较，不打印秘密值。最低客户端版本可只读查看：

```bash
sqlite3 -readonly /etc/x-ui/x-ui.db "SELECT port,COALESCE(json_extract(stream_settings,'$.realitySettings.minClientVer'),'') FROM inbounds WHERE protocol='vless';"
jq -r '.inbounds[] | select(.streamSettings.security == "reality") | [.port, (.streamSettings.realitySettings.minClientVer // "")] | @tsv' /usr/local/x-ui/bin/config.json
```

空字段或运行配置省略字段在 Xray v26.9.8+ 不应判为错误；v26.7.11–v26.9.7 的兼容规则见 `inbounds.md`。不要用“必须出现 1.0.0”的 grep 验收所有 Core。

如果数据库是新配置，但 `/usr/local/x-ui/bin/config.json` 仍是旧 UUID、旧 Reality 目标、旧 flow 或与预期版本限制不一致，执行：

```bash
systemctl restart x-ui
sleep 3
systemctl is-active x-ui
ss -lntup | grep -E ':<端口>\b'
```

然后再次对比 `config.json`。只有确认 Xray 实际运行配置已加载最新字段，才继续做客户端连通性测试。

后量子入站还要验证 ML-DSA-65 字段已进入运行配置，但不得输出完整密钥：

```bash
sqlite3 /etc/x-ui/x-ui.db "select stream_settings from inbounds where remark='US-VLESS-TCP-PQ';" | grep -Eq '"mldsa65Seed"[[:space:]]*:[[:space:]]*"[^\"]+"'
grep -Eq '"mldsa65Seed"[[:space:]]*:[[:space:]]*"[^\"]+"' /usr/local/x-ui/bin/config.json
```

如果启用了 VLESS ML-KEM-768/VLESSENC，额外验证服务端运行配置只出现非空 `decryption` 前缀；客户端 `encryption` 必须从实际订阅或临时 Xray 出站配置验证，不能从服务端 `clients` 字段推断：

```bash
grep -Eq '"decryption"[[:space:]]*:[[:space:]]*"mlkem768x25519plus\.' /usr/local/x-ui/bin/config.json
xray run -test -config /usr/local/x-ui/bin/config.json
```

不要把 `mldsa65Seed/Verify` 为空判定为 ML-KEM 配置失败，也不要把面板导出的入站 `settings.encryption` 原样写入 Xray 入站客户端；以运行配置和实际下发客户端配置为准。

还要确认 5 个端口都进入实际配置（含独立 PQ 端口）：

```bash
for p in 443 <随机TCP端口> <XHTTP端口> <PQ_TCP端口> <HY2端口>; do
  grep -q "\"port\": $p" /usr/local/x-ui/bin/config.json && echo "config_port_$p=present"
done
```

面板 HTTPS 可访问性用外部 `GET https://<面板域名>:<面板端口>/<webBasePath>/` 返回 `200` 判断。不要用 VPS 自己访问公网域名的 TLS 结果作为唯一依据；这类访问可能受发夹 NAT/回环路径影响。

## 生命周期与订阅链路验收

用户要求流量配额/重置/续期时，按 `client-lifecycle.md` 回读**指定客户端**的计划、额度、到期、时区和节点同步状态；不点击即时重置进行测试。脚本中的客户端摘要是只读辅助，表结构不支持时标记 `unavailable`，继续通过当前 API 核对。

Mihomo Reality 按 `subscription.md` 核对最终 YAML 的 ML-KEM 提示，不在 Xray 运行配置中查找伪字段。使用 Sub-Store 通用源时，还要记录后端版本并确认刷新后的源、转换输出、终端加载配置一致。

## 真实连通性验收

入站服务器侧检查通过后，必须读取并执行 `connectivity-test.md`。

最终逐项列出以下状态，不能合并成笼统的“节点正常”：

- VLESS TCP Reality 443：通过 / 失败 / 待外部实测。
- VLESS TCP Reality 随机端口：通过 / 失败 / 待外部实测。
- VLESS XHTTP Reality：通过 / 失败 / 待外部实测。
- Reality ML-DSA-65：通过 / 失败 / 待外部实测（未启用则不列出）。
- VLESS ML-KEM-768/VLESSENC：通过 / 失败 / 待外部实测（未启用则不列出）。
- HY2 主端口：通过 / 失败 / 待外部实测。
- HY2 跳跃端口 A、B：通过 / 失败 / 待外部实测。

只有协议握手完成并通过该代理取得 HTTPS 测试响应才标记为“通过”。若没有 VPS 外独立测试环境，明确说明尚待一次客户端实测，不得宣称全部可用。

## 最终交付格式

最后必须用简洁清单输出：

```text
部署完成。

面板地址:
面板用户名:
面板密码:
面板端口:
面板路径:
3x-ui 面板版本:
Xray Core 版本:
证书状态:
Clash/Mihomo 订阅:
IPv6 状态:
BBR/调优状态:
本机防火墙:
流量周期重置:
- 未要求则保留默认无限流量；如已配置，列出目标客户端、每周期额度、重置日和面板时区。
到期与自动续期:
- 长期有效 / 首次截止时间、续期模式、最大次数；说明保存后回读结果，不冒充未来计划已实测。

入站创建:
- 是否创建 5 个入站
- 如已创建，列出每个入站名称、协议、端口、用途、客户端 email
- 如已创建，逐项列出真实连通性测试结果；HY2 必须分别列出主端口和两个跳跃端口结果

订阅获取:
- 按 subscription.md 输出，区分专用 Clash 链接与通用订阅经 Sub-Store 转换的用法

Skill 版本检查:
- 当前版本:
- GitHub 最新版本:
- 是否建议升级:

安全提醒:
- 立刻修改 VPS root 密码
- 保存面板地址、用户名、密码
- 如果端口外部不通，去 VPS 商家安全组放行端口
```

不要在最终报告里重复输出 SSH 临时密码。
