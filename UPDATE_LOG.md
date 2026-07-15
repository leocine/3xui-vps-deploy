# 更新记录

## 2026-07-15

- 补充 VLESS Reality 节点异常排查：当面板或订阅显示新配置，但 Loon/Mihomo 新导入超时、旧客户端或 v2rayN 仍可用时，优先检查 3x-ui 数据库与 Xray 实际运行配置是否一致。
- 在安装后验证中新增“运行配置一致性验证”：对比 `/etc/x-ui/x-ui.db` 与 `/usr/local/x-ui/bin/config.json` 的 UUID、flow、Reality serverNames、publicKey、shortId 等关键字段。
- 明确若数据库已更新但 Xray 仍加载旧配置，应先 `systemctl restart x-ui`，确认 `config.json` 重新生成后再做客户端连通性测试。
