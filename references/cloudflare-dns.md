# Cloudflare DNS 配置

先帮助用户完成域名解析，不要 SSH 到 VPS，不要开始部署。

参考 Cloudflare 官方 Full setup、Proxy status 文档，以及新手教程的表达方式：先买域名，再注册 Cloudflare，把域名托管到 Cloudflare，最后添加 A 记录并保持灰云。

## 0. 先判断用户处在哪一步

先问用户：

```text
你现在做到哪一步了？

1. 还没有域名
2. 已买域名，但还没有 Cloudflare 账号
3. 已买域名和 Cloudflare 账号，但域名还没添加到 Cloudflare
4. 域名已添加到 Cloudflare，但还没去注册商改 nameserver
5. nameserver 已改，但 Cloudflare 还没 Active 或不确定
6. Cloudflare 已 Active，但还没添加面板域名 A 记录
7. A 记录已添加，但不确定是不是灰云/DNS only，或不确定有没有同名 AAAA
8. 都配好了，需要检查
```

根据用户选择继续。不要一次性甩长文。

## 1. 先买域名

如果用户还没有域名，先停在这里，让用户去买一个域名。

推荐表达：

```text
你需要先买一个根域名，例如 example.com。建议用 NameSilo，通常无需实名；便宜后缀常见约 1-2 美元/年，具体以页面实时价格为准：
https://www.namesilo.com/

买的是根域名，不是子域名。比如买 example.com，后面我们可以免费创建 panel.example.com 或 byte.example.com 这种子域名。
买好域名后再继续下一步，把域名接入 Cloudflare。
```

提醒：

- 不需要额外购买 `panel.example.com` 这种子域名。
- 域名价格按后缀不同差异很大；如果只是给 3x-ui 面板和节点使用，选便宜后缀即可。
- 购买前确认注册商支持修改 nameserver，大多数正规注册商都支持。
- 优先建议 NameSilo，因为对新手足够简单，且通常无需实名。用户也可以用 Namecheap、Spaceship、GoDaddy、阿里云等其他注册商。

## 2. 准备工作

继续部署 DNS 前，用户需要：

1. 一个已购买的根域名，例如 `example.com`。
2. 一个 Cloudflare 账号。
3. 一台 VPS 的 IPv4 地址。
4. 想用作面板的子域名，例如 `panel.example.com` 或 `byte.example.com`。

给小白解释：

- DNS 就是“把域名指向服务器 IP”的系统。
- A 记录用于把域名指向 IPv4。
- AAAA 记录用于 IPv6，这套部署里先不要用。
- CNAME 是把一个域名指向另一个域名，本次面板域名优先不用 CNAME。

## 3. 注册 Cloudflare 账号

如果用户还没有 Cloudflare 账号：

1. 打开 `https://dash.cloudflare.com/sign-up`。
2. 用邮箱注册并登录。
3. 登录后准备添加已经买好的根域名。

## 4. 把域名添加到 Cloudflare

指导用户：

1. 登录 Cloudflare 控制台。
2. 进入 Websites / Domains。
3. 点击添加域名。
4. 输入根域名，不要输入子域名。
   - 正确：`example.com`
   - 错误：`panel.example.com`
5. 选择 Free 套餐。
6. Cloudflare 可能会扫描已有 DNS 记录。对 3x-ui 部署来说，不重要的记录可以先不管，后面手动添加面板 A 记录。

## 5. 修改注册商 nameserver

这是最容易搞混的一步。必须强调：

```text
改 nameserver 是在“买域名的网站”里做，不是在 Cloudflare 里做。
```

流程：

1. Cloudflare 会给出 2 条 nameserver，例如：

```text
xxx.ns.cloudflare.com
yyy.ns.cloudflare.com
```

2. 打开域名注册商后台，例如 NameSilo、Namecheap、Spaceship、GoDaddy、阿里云等。
3. 找到域名管理。
4. 找到 Nameservers / DNS Servers / 自定义 DNS。
5. 删除原来的 nameserver。
6. 填入 Cloudflare 给出的 2 条 nameserver。
7. 保存。
8. 回到 Cloudflare，点击类似“完成，检查域名服务器”的按钮。

注意：

- 两条 nameserver 都要填，不能只填一条。
- 不要自己编 nameserver。
- 如果注册商提示 DNSSEC，先关闭 DNSSEC，等 Cloudflare Active 后再按需开启。

## 6. 等待 Cloudflare Active

让用户回到 Cloudflare 等待域名状态变成 Active。

说明：

- 通常几分钟到几十分钟。
- 慢的时候可能几个小时。
- 如果超过 24 小时仍不生效，优先检查注册商 nameserver 是否填错。
- 没 Active 前不要继续部署证书和面板。

## 7. 添加面板域名 A 记录

Cloudflare Active 后，进入 Cloudflare 的 DNS -> Records，添加：

```text
类型: A
名称: <面板子域名前缀>
内容: <VPS_IP>
代理状态: DNS only / 灰云 / 仅 DNS
TTL: Auto
```

这一步必须单独向用户展示，不要只说“确认 A 记录已指向 VPS”。小白最容易漏的是：A 记录没加、名称填错、或代理状态还是橙云。

示例 1：面板域名是 `byte.example.com`

```text
类型: A
名称: byte
内容: 203.0.113.10
代理状态: DNS only / 灰云 / 仅 DNS
TTL: Auto
```

示例 2：面板域名就是根域名 `example.com`

```text
类型: A
名称: @
内容: 203.0.113.10
代理状态: DNS only / 灰云 / 仅 DNS
TTL: Auto
```

## 8. 必须关闭橙云

给用户明确解释：

- 橙云 / Proxied：流量先经过 Cloudflare，适合普通网站。
- 灰云 / DNS only / 仅 DNS：Cloudflare 只做解析，直接返回 VPS IP。

3x-ui 面板、Reality、HY2 必须用灰云。

必须是：

```text
DNS only / 灰云 / 仅 DNS
```

不能是：

```text
Proxied / 橙云
```

原因：

- Reality、HY2、非标准端口不是普通网页 CDN 场景。
- 开橙云可能导致证书申请、面板访问、节点连接异常。
- 如果开启橙云，`nslookup` 往往会返回 Cloudflare IP，而不是 VPS IP。

## 9. 删除同名 AAAA 记录

在 DNS 记录里搜索面板子域名。

如果有同名 `AAAA` 记录，删除它，只保留 IPv4 `A` 记录。

这一步也必须单独展示。不要只说“检查 IPv6”，要明确告诉用户在 Cloudflare DNS 记录里搜索同一个面板子域名并删除同名 `AAAA`。

原因：

- 很多客户端会优先走 IPv6。
- 如果 AAAA 指向错误地址，可能出现“域名看起来对，但就是连不上”。

## 10. 验证与排错

让用户在本机终端执行：

```bash
nslookup <PANEL_DOMAIN>
```

或：

```bash
dig <PANEL_DOMAIN>
```

正确结果：

```text
Address: <VPS_IP>
```

也可以让用户用 DNS Checker 这类在线工具检查全球解析。

常见错误：

- 返回 Cloudflare IP：还开着橙云。
- 返回 IPv6：还有 AAAA 记录。
- 返回旧 IP：A 记录没改对，或 DNS 缓存未刷新。
- 查不到：Cloudflare 未 Active，或 A 记录没添加。
- 超过 24 小时仍不生效：检查注册商 nameserver 是否已经换成 Cloudflare 的两条。

只有用户确认 `nslookup` 或 `dig` 返回 VPS IPv4 后，才能回到主流程继续部署。
