# 3x-ui VPS Deploy Skill

这是一个给 Codex 使用的 Skill，用于在全新的 Debian 或 Ubuntu VPS 上部署和验收 3x-ui。

它会先检查域名和 Cloudflare DNS 是否准备正确，再安装最新版 3x-ui、配置 HTTPS 与 Clash/Mihomo 订阅；可选创建 4 个常用入站（VLESS Reality、VLESS XHTTP Reality、Hysteria2），完成 HY2 端口跳跃、本机防火墙、网络调优和真实连通性验收。

## 使用前准备

- 一台全新的 Debian 或 Ubuntu VPS。
- 可以登录 VPS 的 IP、SSH 端口和临时 root 密码。
- 域名和 Cloudflare 不需要预先配置好；Skill 会从这两项开始一步步引导。

不要把 VPS 密码、SSH 私钥、Reality 私钥或其他密钥提交到此仓库。

## 安装 Skill

新开一个 Codex 任务，把这段话直接发给 Codex：

```text
请使用 skill-installer 从 GitHub 仓库 leocine/3xui-vps-deploy 安装根目录的 3xui-vps-deploy Skill，使用最新版。安装完成后提醒我开启一个新任务再使用。
```

安装完成后，开启一个新的 Codex 任务。

## 使用 Skill

在新的 Codex 任务中说：

```text
帮我部署一台新的 3x-ui VPS。
```

Skill 会从域名、Cloudflare DNS 和 SSH 信息开始收集，按顺序完成部署。macOS 环境会优先使用本机临时凭据文件，避免在对话中输入 VPS 密码。

## 部署流程

开始后，Codex 会按下面的顺序带你完成。需要你自己在网站上操作的地方，它会停下来说明下一步；其余检查、安装和测试会自动完成。

1. **准备域名**：先确认你有没有域名。没有的话，会推荐购买渠道并带你完成购买；NameSilo 的便宜后缀通常约 1 到 2 美元/年，实际价格以网站显示为准。
2. **注册并接入 Cloudflare**：确认是否已有 Cloudflare 账号。没有就先注册；有域名后，把域名添加到 Cloudflare，再将 Cloudflare 给出的两条 nameserver 填到买域名的网站，等 Cloudflare 显示域名已接入。
3. **设置域名解析**：创建一个面板子域名的 A 记录，例如 `panel.example.com`，让它指向 VPS IP。代理状态必须设为 `DNS only` / 灰云；如果有同名 AAAA 记录，也会提示删除。Codex 会验证公网解析生效后再继续。
4. **连接 VPS**：收集 VPS IP、SSH 端口、系统和面板域名。macOS 上会优先打开一个只保存在本机的文件填写临时 root 密码，避免把密码发到对话里。
5. **安装 3x-ui 面板**：先检查系统和端口，再根据 3x-ui 官方最新文档安装面板、申请 HTTPS 证书、开启 Clash/Mihomo 订阅、处理 VPS 本机防火墙，并关闭 IPv6。
6. **可选的一键入站**：你可以自己在面板中创建入站，也可以让 Codex 自动创建 4 个常用节点：443 VLESS TCP Reality、随机端口 VLESS TCP Reality、随机端口 VLESS XHTTP Reality，以及带 `48000-50000` UDP 端口跳跃的 HY2。自动模式只建一个客户端 `admin`，四个节点都会归到它下面。
7. **自动调优**：无论你是否创建入站，都会使用 VPSing 的 TCP/BBR 调优脚本（`tcp.vpsing.de`），自动完成 IPv4 优先、BBR + FQ、内核调优和网卡多队列这 4 步。
8. **检查是否真的可用**：会检查面板、证书、端口、端口跳跃和订阅。创建节点时，还会用真实的代理访问测试来确认连接成功，不会只看端口是否打开；如果 VPS 商家安全组挡住了端口，会告诉你去商家后台放行。
9. **告诉你怎么使用**：最后会给出面板地址和登录信息，并说明如何在 3x-ui 的 `客户端 -> admin` 中取得订阅。使用 Clash Verge 时，会特别说明要先在浏览器打开订阅链接，再复制页面里的 Clash 订阅内容。

## 版本

当前稳定版本：`v1.0.9`。
