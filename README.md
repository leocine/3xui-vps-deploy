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

这是私有仓库。首次安装前，把你的 GitHub 用户名发给 Skill 的提供者，请他邀请你访问仓库；在 GitHub 的通知或邮件里接受邀请后，再继续下面的安装步骤。

然后，新开一个 Codex 任务，把这段话直接发给 Codex：

```text
请使用 skill-installer 从 GitHub 私有仓库 leocine/3xui-vps-deploy 安装根目录的 3xui-vps-deploy Skill，使用最新版。若需要 GitHub 权限，请先引导我完成 GitHub 授权。安装完成后提醒我开启一个新任务再使用。
```

也可以在已具备 GitHub 私有仓库访问权限的终端中执行：

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo leocine/3xui-vps-deploy \
  --path . \
  --name 3xui-vps-deploy \
  --ref v1.0.3
```

安装完成后，开启一个新的 Codex 任务，然后说：

```text
帮我部署一台新的 3x-ui VPS。
```

Skill 会从域名、Cloudflare DNS 和 SSH 信息开始收集，按顺序完成部署。macOS 环境会优先使用本机临时凭据文件，避免在对话中输入 VPS 密码。

## 版本

- 推荐使用固定标签 `v1.0.3`，以便每次安装得到可复现版本。
- 需要获取后续更新时，将上面命令中的 `--ref` 替换为新的版本标签，并先移除旧的本地 Skill 目录后重新安装。
