---
name: 3xui-vps-deploy
description: 用于在全新 Debian/Ubuntu VPS 上部署 3x-ui 面板，或在已安装 3x-ui 的 VPS 上配置每月自动重置流量。部署场景会先确认域名和 Cloudflare DNS，再通过临时 SSH 密码接入，安装面板、配置 HTTPS、开启 Clash/Mihomo 订阅、可选创建 VLESS Reality/XHTTP/HY2 入站、配置 HY2 端口跳跃和系统网络调优。自动重置场景会只配置 3x-ui inbound/client 流量统计重置脚本、日志和 cron，不修改节点配置。
---

# 3x-ui VPS Deploy

## 自动流量重置请求

用户要求“每月自动重置流量 / VPS 流量周期重置 / 3x-ui 重置 inbound 和 client 流量统计”时，不走新 VPS 部署的域名门禁，也不要安装或升级 3x-ui。读取 `references/reset-traffic.md`，只完成该文档中的只读检查、重置日询问、API Token 配置、脚本安装、cron 配置和测试验证。

自动重置任务的硬限制：

- 只允许重置流量统计。
- 不得重装、升级或重配 3x-ui。
- 不得修改入站、客户端、节点参数、Xray、证书、防火墙、SSH 或系统网络。
- 不得保存或输出 VPS root 密码、SSH 私钥、面板密码、API Token。

## 必须先做的门禁

用户要部署 3x-ui 新 VPS 时，第一步只做域名门禁，不要问 SSH 信息：

```text
先确认域名准备情况：

1. 你已经买好域名了吗？
2. 域名是否已经接入 Cloudflare 做 DNS 解析？
3. 面板子域名是否已经添加 A 记录并指向 VPS IPv4？
4. 这条 A 记录是否是 DNS only / 灰云？
5. 同名 AAAA 记录是否已删除？
```

- 如果用户还没有域名，读取 `references/cloudflare-dns.md` 的买域名部分，建议先买一个域名，优先建议 NameSilo：`https://www.namesilo.com/`，并说明通常无需实名；便宜后缀常见约 1-2 美元/年，具体以页面实时价格为准，停在这里。
- 如果用户有域名但没接入 Cloudflare，读取 `references/cloudflare-dns.md` 的 Cloudflare 托管部分，指导注册 Cloudflare、添加域名、去注册商修改 nameserver，停在这里。
- 如果用户已接入 Cloudflare，但没有 A 记录、开着橙云、或还有同名 AAAA，读取 `references/cloudflare-dns.md` 的对应部分指导修正。必须单独展示“添加面板子域名 A 记录”和“代理状态改成 DNS only / 灰云”这两个步骤，不要合并成一句提醒。
- 优先从 Codex 当前执行环境自动查询公网 DNS，核验面板域名 A 记录等于 VPS IPv4 且不存在同名 AAAA；这一步只需面板域名和 VPS IPv4，不需要 SSH 密码。
- 只有当前环境无法查询公网 DNS 时，才让用户提供 `nslookup <面板域名>` 或 `dig <面板域名>` 的结果；在 DNS 验证通过前不要继续 SSH 或部署。

## 部署前收集信息

DNS 确认后再问：

```text
IP:
SSH 端口:
SSH 用户名，默认 root:
系统，Debian 或 Ubuntu:
面板域名:
每月流量重置日，例如 17 或 22:
```

默认在流量重置日的北京时间 `08:05` 执行 3x-ui 流量统计重置。若用户不确定重置日，先让用户查看 VPS 商家流量周期；不要自行假设日期。

在 macOS 上，读取 `references/local-credentials.md`：自动创建并打开本机凭据文件，让用户只填写临时 root 密码、保存并回复“已保存”。优先读取这个文件，不要在聊天中索取密码。

非 macOS、无法打开 TextEdit、或用户明确要求时，才补问临时 root 密码。临时密码只用于当前 SSH 部署，不写入日志或最终报告。部署完成后必须提醒用户立刻在 VPS 商家后台修改 root 密码，并更新或删除本机凭据文件。

## 执行流程

用户要求“模拟一下 / dry-run / 先看看会怎么做”时，不连接 VPS，只按下面流程输出将执行的步骤、需要的信息、风险点和预期结果。模拟里必须包含 Cloudflare Active 后添加 A 记录、设置 DNS only / 灰云、删除同名 AAAA、`nslookup` 返回 VPS IPv4 的完整 DNS 阶段。

真实部署时，尽量一键执行，不做无意义的中间确认。只有遇到会导致覆盖、失败或锁死 SSH 的风险时才停下询问。

复杂远程操作优先使用“本地生成脚本、上传到 VPS、再执行脚本”的方式，尤其是 SQLite 写入、jq JSON payload、cron 写入、多行验收查询和带多层引号的命令。不要把复杂 SQL 或 JSON 直接塞进单条 SSH 命令；远端 shell 容易吞掉引号，导致配置写入或验收失败。

1. 按 `references/preflight-recovery.md` 做自动预检。预检失败时先给出明确修复动作，不继续部署。
2. 按 `references/deploy-panel.md` 安装 3x-ui、配置 HTTPS、开启 Clash/Mihomo 订阅、处理本机防火墙、关闭 IPv6。配置 HTTPS 和订阅开关时优先上传并执行 `scripts/configure-panel-https.sh`。安装相关命令必须以官方最新文档 `https://docs.sanaei.dev/docs/` 为准，不使用旧教程。
3. 面板安装完成后只询问一次是否一键创建入站：
   - 是：按 `references/inbounds.md` 创建 4 个入站。
   - 否：跳过入站，直接调优。
4. 无论是否创建入站，都按 `references/tuning.md` 执行网络调优。
5. 默认读取 `references/reset-traffic.md`，按部署前收集的每月流量重置日配置 3x-ui 自动重置 inbound/client 流量统计。新部署场景优先复用 `/etc/x-ui/install-result.env` 中的 `XUI_API_TOKEN`，不要要求用户在聊天中提供面板密码或 API Token。
6. 如果创建了入站，读取 `references/connectivity-test.md`，完成服务器侧验收和 VPS 外独立环境的真实代理访问测试。没有外部执行环境时，明确标记“待外部实测”，并以一次用户连接动作配合抓包诊断；不得把端口监听写成节点已通。
7. 按 `references/validation-delivery.md` 做安装后验证并汇总测试结论。基础验收优先上传并执行 `scripts/validate-deployment.sh`，再补做 VPS 外部的真实代理连通性测试。
8. 最后按 `references/subscription.md` 输出订阅获取方式，重点强调 Clash Verge 的复制方式。
9. 在最终回复前读取 `references/version-check.md`，做一次非阻塞版本检查；如果 GitHub 最新 Release/Tag 高于当前 skill 版本，提醒用户用 `skill-installer` 升级。

## 每次使用后的版本检查

无论是新 VPS 部署、每月流量重置配置、节点故障排查，还是 dry-run 模拟，任务结束前都要执行 `references/version-check.md` 中的版本检查。

- 版本检查是非阻塞步骤，不得因为 GitHub、网络或 `gh` 不可用而影响本次任务结论。
- 只提示升级，不自动升级 skill；除非用户明确要求“帮我升级 skill”。
- 如果检测到新版，在最终报告里说明当前版本、GitHub 最新版本和升级建议。
- 如果无法检测，在最终报告里简短说明“本次无法确认 GitHub 最新版本”。

## GitHub Release 记录规则

每次发布新版本时，GitHub Release 的标题和更新内容必须固定使用中文。不要出现一版中文、一版英文的混用。

- Release 标题使用版本号，例如 `vX.Y.Z`。
- Release notes 用中文项目符号说明本次更新了什么。
- README 不记录每个版本的具体变更；具体变更只写在 GitHub Releases 和 `CHANGELOG.md`。

## 安全规则

- 改 3x-ui 数据库前必须备份 `/etc/x-ui/x-ui.db`。
- 优先使用 3x-ui API；API 不方便时才直接改 SQLite。
- 不照抄示例 UUID、Reality key、shortId、HY2 auth，全部现场随机生成。
- 443 端口被占用时先停止并询问，不要强行覆盖。
- VPS 商家后台安全组通常不能通过 SSH 修改；只自动处理 VPS 本机防火墙。若端口监听正常但外部不通，提示用户去商家后台放行端口。
- 不保存用户 SSH 密码，不把密码写入文件、日志或最终报告。
- 不在 DNS 未验证返回 VPS IPv4 前部署。
- 不承诺自动修改 VPS 商家安全组。
- 不得只因端口监听或 x-ui 为 active 就宣称入站可用；只有按 `references/connectivity-test.md` 完成真实代理 HTTPS 请求才算通过。
- HY2 端口跳跃规则必须持久化并通过规则重载验收；不得交付只存在于当前运行内存的 nftables/iptables NAT 规则。
