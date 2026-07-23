# Changelog

## v1.0.18

- 新增 `scripts/configure-panel-https.sh`，用于在 VPS 端申请或复用证书、备份数据库、写入面板 HTTPS 配置，并开启 Clash/Mihomo 订阅。
- 新增 `scripts/validate-deployment.sh`，用于服务器侧统一验收面板、证书、入站、端口监听、HY2 NAT、调优和每月流量自动重置状态。
- 明确复杂远程操作应优先“上传脚本后执行”，避免 SQLite、JSON、cron 等多层引号在 SSH 命令中被远端 shell 吞掉。
- 修复 `3xui-reset-traffic.sh` 的 3x-ui 版本识别逻辑，避免 3x-ui 3.5.0 下调用交互命令导致自动重置任务卡住。
- 补充 3x-ui 3.5.0 非交互安装跳过 SSL 的标准处理方式：安装后必须单独配置 HTTPS，不交付 HTTP 面板。

## v1.0.17

- 新增每次任务结束前的非阻塞版本检查，覆盖部署、流量重置、故障排查和 dry-run 场景。
- 新增 `references/version-check.md`，说明 GitHub Release/Tag 查询、版本比较和升级提示规则。
- 部署交付和流量重置交付结果中加入 Skill 版本检查状态。

## v1.0.16

- HY2 端口跳跃 NAT 规则必须通过 nftables 或 iptables-persistent 持久化，明确禁止只写入当前运行内存的一次性规则。
- 验收时同时检查当前运行规则和持久化配置，要求持久化服务已启用，并确认规则经过安全重载后仍然存在。
- 增加 VPS 异常重启后 HY2 端口跳跃失效的排查说明。
- 增加 Sub-Store 缓存诊断，用于处理直接导出的 HY2 节点正常、但转换订阅仍保留旧 `mport` 或地址配置的情况。

## v1.0.15

- 新 VPS 部署会收集每月流量重置日，并默认配置 3x-ui 流量重置脚本。
- 部署验收会检查重置脚本、`600` 权限配置文件、cron 任务和日志路径。
- README 不再记录每个版本的具体更新内容，详细更新说明统一放到 GitHub Releases。

## v1.0.14

- 新增已安装 3x-ui VPS 的每月流量自动重置流程。
- 新增 `scripts/3xui-reset-traffic.sh`，作为 VPS 端脚本模板，从 `600` 权限配置文件读取 API Token，并通过当前 3x-ui API 重置 inbound/client 流量。
- 新增 `references/reset-traffic.md`，覆盖只读预检、重置日收集、API 兼容确认、cron 设置、日志、测试和安全限制。
- 更新 README 的使用说明和目录结构，加入流量重置流程。

## v1.0.13

- README 新增目录结构说明，解释 `SKILL.md`、`agents/`、`scripts/` 和 `references/` 的作用。
- 文档中的稳定版本更新为 `v1.0.13`。

## v1.0.12

- 根据一次真实 VMISS 部署补充 3x-ui 3.5.0 自动化注意事项。
- 记录 `/panel/api/*` 的 Bearer API Token 用法，以及脚本直接 POST `/login` 时可能遇到的 CSRF 失败模式。
- 明确非交互安装时的 HTTPS 配置方式，包括 `webCertFile` 和 `webKeyFile`。
- 扩展 Xray Core 固定说明，覆盖从 `26.7.11` 替换为 `26.6.27`，以及解析 `xray x25519` 输出。
- 补充 3x-ui 3.5.0 的 `clients` / `client_inbounds` 说明，确保 4 个入站通过共享 `subId` 使用同一个逻辑 `admin` 客户端。
- 收紧 HY2 规则：不向 3x-ui/Xray 配置写入不支持的调优字段，端口跳跃只使用 nftables 实现。
- 明确面板 HTTPS、`config.json` 一致性，以及外部客户端下载失败时的验收规则。

## v1.0.11

- VMISS 部署说明补充前的稳定版本。
