# 安装后验证与交付

部署完成后必须验证，不要只报告“命令已执行”。

## 基础验证

```bash
systemctl is-active x-ui
x-ui settings
ss -lntup
/usr/local/x-ui/bin/xray-linux-amd64 version | head -1
```

确认：

- `x-ui` 是 `active`。
- 面板端口正在监听。
- 面板 URL、用户名、密码、端口、web base path 可从安装结果或配置中读取。
- HTTPS 证书文件存在。
- Clash/Mihomo 订阅已开启。
- Xray Core 版本是 `26.6.27`，不要交付仍使用 `26.7.11` 的 VLESS Reality 配置。
- 每月流量自动重置已配置：脚本存在、配置文件权限为 `600`、日志路径可写、root crontab 中有 `/usr/local/bin/3xui-reset-traffic.sh`。
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

## 流量自动重置验证

新 VPS 部署默认必须配置每月流量自动重置。检查：

```bash
test -x /usr/local/bin/3xui-reset-traffic.sh
stat -c '%a %U %G %n' /etc/3xui-reset-traffic.env
crontab -l | grep '/usr/local/bin/3xui-reset-traffic.sh'
tail -n 20 /var/log/3xui-reset-traffic.log 2>/dev/null || true
```

确认：

- `/usr/local/bin/3xui-reset-traffic.sh` 存在且可执行。
- `/etc/3xui-reset-traffic.env` 权限是 `600`。
- cron 日期等于用户提供的 VPS 每月流量重置日。
- cron 时间已按 VPS 当前系统时区从北京时间 `08:05` 换算。
- 最终报告不得输出 API Token。

## 入站验证

如果创建了入站，确认：

- 4 个入站都启用。
- 只有一个逻辑客户端 `admin`，没有 `admin-xhttp`、`admin-vless`、`admin-hy2`、`admin01` 这类拆分客户端。
- 4 个入站都关联到 `admin`；3 个 VLESS 入站使用同一个 `admin` 客户端 UUID。
- HY2 有随机 auth。
- 3x-ui 3.5.0 还要确认 `clients` 表里只有一个逻辑 `admin`，并通过 `client_inbounds` 关联到 4 个入站；4 个关联使用同一个 `sub_id`。
- 443 入站监听 `443/tcp`。
- 随机 VLESS 入站监听对应 TCP 端口。
- HY2 主端口监听 UDP。
- HY2 端口跳跃 `48000-50000` 已写入 nftables。

检查示例：

```bash
ss -lntup | grep -E ':(443|<随机TCP端口>|<XHTTP端口>)'
ss -lunp | grep '<HY2主端口>'
nft list ruleset
```

## 运行配置一致性验证

3x-ui 面板数据库和 Xray 实际运行配置必须一致。尤其在修改 UUID、flow、Reality 密钥、SNI/serverNames、shortId 后，不能只看面板或订阅。

检查对应入站的关键字段是否同时出现在数据库和实际配置中：

```bash
sqlite3 /etc/x-ui/x-ui.db "select settings,stream_settings from inbounds where port=<端口>;" | grep -oE '<客户端email>|<UUID前缀>|xtls-rprx-vision|<serverName>|<shortId>'
grep -oE '<客户端email>|<UUID前缀>|xtls-rprx-vision|<serverName>|<shortId>' /usr/local/x-ui/bin/config.json
```

如果数据库是新配置，但 `/usr/local/x-ui/bin/config.json` 仍是旧 UUID、旧 Reality 目标或旧 flow，执行：

```bash
systemctl restart x-ui
sleep 3
systemctl is-active x-ui
ss -lntup | grep -E ':<端口>\b'
```

然后再次对比 `config.json`。只有确认 Xray 实际运行配置已加载最新字段，才继续做客户端连通性测试。

对 3x-ui 3.5.0，还要直接确认 4 个端口都进入实际配置：

```bash
for p in 443 <随机TCP端口> <XHTTP端口> <HY2端口>; do
  grep -q "\"port\": $p" /usr/local/x-ui/bin/config.json && echo "config_port_$p=present"
done
```

面板 HTTPS 可访问性用外部 `GET https://<面板域名>:<面板端口>/<webBasePath>/` 返回 `200` 判断。不要用 VPS 自己访问公网域名的 TLS 结果作为唯一依据；这类访问可能受发夹 NAT/回环路径影响。

## 真实连通性验收

入站服务器侧检查通过后，必须读取并执行 `connectivity-test.md`。

最终逐项列出以下状态，不能合并成笼统的“节点正常”：

- VLESS TCP Reality 443：通过 / 失败 / 待外部实测。
- VLESS TCP Reality 随机端口：通过 / 失败 / 待外部实测。
- VLESS XHTTP Reality：通过 / 失败 / 待外部实测。
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
证书状态:
Clash/Mihomo 订阅:
IPv6 状态:
BBR/调优状态:
本机防火墙:
流量自动重置:
- 重置日:
- 执行时间:
- 脚本路径:
- cron:
- 日志路径:

入站创建:
- 是否创建 4 个入站
- 如已创建，列出每个入站名称、协议、端口、用途、客户端 email
- 如已创建，逐项列出真实连通性测试结果；HY2 必须分别列出主端口和两个跳跃端口结果

订阅获取:
- 按 subscription.md 输出，重点标记 Clash Verge 的特殊复制方式

安全提醒:
- 立刻修改 VPS root 密码
- 保存面板地址、用户名、密码
- 如果端口外部不通，去 VPS 商家安全组放行端口
```

不要在最终报告里重复输出 SSH 临时密码。
