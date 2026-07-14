# 3x-ui VPS Deploy Skill

这是一个给 Codex 使用的 Skill，用于在全新的 Debian 或 Ubuntu VPS 上部署和验收 3x-ui。

它会先检查域名和 Cloudflare DNS 是否准备正确，再安装最新版 3x-ui、配置 HTTPS 与 Clash/Mihomo 订阅；可选创建 4 个常用入站（VLESS Reality、VLESS XHTTP Reality、Hysteria2），完成 HY2 端口跳跃、本机防火墙、网络调优和真实连通性验收。

## 使用前准备

- 一台全新的 Debian 或 Ubuntu VPS。
- 一个已购买的域名。若没有，Skill 会先指导购买并接入 Cloudflare。
- 面板子域名的 A 记录已指向 VPS IPv4，且为 `DNS only` / 灰云；不要保留同名 AAAA 记录。
- VPS 的 IP、SSH 端口和临时 root 密码。

不要把 VPS 密码、SSH 私钥、Reality 私钥或其他密钥提交到此仓库。

## 安装

新开一个 Codex 任务，把这段话直接发给 Codex：

```text
请使用 skill-installer 从 GitHub 仓库 leocine/3xui-vps-deploy 安装根目录的 3xui-vps-deploy Skill，使用最新版。安装完成后提醒我开启一个新任务再使用。
```

安装完成后，开启一个新的 Codex 任务，然后说：

```text
帮我部署一台新的 3x-ui VPS。
```

Skill 会从域名、Cloudflare DNS 和 SSH 信息开始收集，按顺序完成部署。macOS 环境会优先使用本机临时凭据文件，避免在对话中输入 VPS 密码。

## 版本

当前稳定版本：`v1.0.5`。
