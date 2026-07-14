# 3x-ui VPS Deploy Skill

这是一个给 Codex 使用的 Skill，用于在全新的 Debian 或 Ubuntu VPS 上部署和验收 3x-ui。

它会先检查域名和 Cloudflare DNS 是否准备正确，再安装最新版 3x-ui、配置 HTTPS 与 Clash/Mihomo 订阅；可选创建 4 个常用入站（VLESS Reality、VLESS XHTTP Reality、Hysteria2），完成 HY2 端口跳跃、本机防火墙、网络调优和真实连通性验收。

## 部署流程

启动部署后，Skill 会按下面顺序工作：

1. **确认域名**：先问是否已有域名。没有时，会引导购买域名，优先建议 NameSilo；便宜后缀通常约 1 到 2 美元/年，价格以购买页为准。买好域名后再继续。
2. **接入 Cloudflare**：确认是否已有 Cloudflare 账号。没有时先引导注册；随后将域名添加到 Cloudflare，并把 Cloudflare 提供的两条 nameserver 填回域名注册商，等待域名变为 Active。
3. **配置并核验 DNS**：引导创建面板子域名的 A 记录，指向 VPS IPv4；将代理状态设为 `DNS only` / 灰云，并删除同名 AAAA 记录。Skill 会查询公网 DNS，确认解析已生效后才继续。
4. **连接 VPS**：收集 VPS IPv4、SSH 端口、root 用户名、系统和面板域名。macOS 会优先创建仅保存在本机的临时凭据文件，用来填写临时 root 密码。
5. **安装面板**：先做系统与端口预检，再按 3x-ui 官方最新文档安装面板，申请 HTTPS 证书，开启 Clash/Mihomo 订阅，处理本机防火墙并关闭 IPv6。
6. **选择是否一键创建入站**：可以自己在面板配置，也可以由 Skill 自动创建 4 个入站：443 VLESS TCP Reality、随机高端口 VLESS TCP Reality、随机高端口 VLESS XHTTP Reality，以及带 `48000-50000` UDP 端口跳跃的 HY2。自动模式只创建一个逻辑客户端 `admin`，并关联到全部入站。
7. **网络调优**：无论是否创建入站，都会自动运行 `tcp.vpsing.de` 调优脚本并依次执行步骤 1、2、3、4。
8. **真实验收**：检查 3x-ui、证书、端口、端口跳跃与订阅；创建入站时，还会用真实代理 HTTPS 请求验收，端口仅监听不算通过。若 VPS 商家安全组拦截端口，会明确提示到商家后台处理。
9. **交付使用方式**：返回面板地址和安全登录信息，并说明如何从 `客户端 -> admin` 获取订阅；Clash Verge 会特别提示先在浏览器打开订阅链接，再复制页面中的 Clash 订阅内容。

## 使用前准备

- 一台全新的 Debian 或 Ubuntu VPS。
- 可以登录 VPS 的 IP、SSH 端口和临时 root 密码。
- 域名和 Cloudflare 不需要预先配置好；Skill 会从这两项开始一步步引导。

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

当前稳定版本：`v1.0.6`。
