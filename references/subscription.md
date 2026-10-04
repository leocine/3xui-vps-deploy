# 最终输出与订阅获取

最后输出：

以下面板登录信息仅用于新部署的首次交付；已有节点诊断或客户端维护只输出本次业务摘要，不重复输出密码、秘密面板路径或订阅凭据。

- 面板 URL
- 面板用户名
- 面板密码
- 证书路径
- IPv6 是否关闭
- IPv4 优先状态
- BBR 状态
- Clash/Mihomo 订阅是否开启，路径 `/clash/`
- 实际面板与 Xray Core 版本；用户要求周期配额时附指定客户端的重置/续期摘要
- 如果创建了入站，列出 5 个入站端口和客户端信息

## 获取订阅

告诉用户：

1. 访问 3x-ui 面板 URL 并登录。
2. 进入“客户端”菜单。
3. 在列表里找到 `admin`。
4. 点击 `admin` 的二维码。
5. 复制订阅信息。
6. 按客户端支持的格式导入。直接使用 Clash Verge/OpenClash 时，推荐先在浏览器打开订阅页面，复制专用“Clash / Mihomo”订阅链接再导入；不要把订阅网页当作 YAML 文件。
7. 已使用 Sub-Store 的用户可以继续用同一个通用订阅源，分别输出给 v2rayN、Loon 和 Mihomo，不要求拆成两套源或重新创建客户端；按下面的转换链路核验最终参数。

新部署最后提醒用户立刻修改 root 密码；仅做客户端维护时，不要求重新更改或提供 SSH 密码。

## 通用订阅 → Sub-Store → 多客户端

3x-ui v3.9.0 修复了通用 VLESS Reality 分享链接的 ML-KEM 提示遗漏。原始 URI 应包含：

```text
support-x25519mlkem768=true
```

Sub-Store **后端**从 2.39.2 起支持解析和保留这个参数。使用兼容该字段的 Mihomo Core 时，转换后的对应节点应包含：

```yaml
type: vless
client-fingerprint: chrome
reality-opts:
  public-key: <该节点的公钥>
  short-id: <该节点的shortId>
  support-x25519mlkem768: true
```

这只是 Reality 节点的字段片段，不是完整订阅。只检查原节点中该选项是否正确，不给非 Reality 节点批量添加 `reality-opts`，不打印真实 UUID、订阅标识或密钥。

按顺序核验：

1. 记录 3x-ui 与实际服务端 Core 版本；刷新源订阅，确认相关 VLESS URI 已携带提示。旧面板或外部附加链接可能仍缺参数，不能只看页面的版本号。
2. 查看 Sub-Store 后端版本，确认至少 2.39.2；网页前端版本、Docker 的 `latest` 标签或“镜像已是最新”提示不能代替后端版本核对。
3. 重新拉取源、刷新 Sub-Store 缓存/输出，核对**最终下发给 Mihomo 的 YAML** 中选项仍在，且公钥、shortId、SNI、fingerprint 与该节点一致；中间脚本、其他转换服务也可能丢字段。
4. 更新 OpenClash/Clash Verge 的订阅并核对其实际加载配置和 Mihomo Core 版本，再做真实代理 HTTPS 请求。v2rayN/Loon 能用不代表 Mihomo 已收到同样参数。

所有环节支持且参数保留时，不需要永久维护补字段脚本。如果仍缺失，先定位到生成或转换环节；临时使用专用 Clash 源或仅为受影响 Reality 节点补字段须经用户选择，不能直接更换所有设备的订阅。

该提示是 **Reality TLS 的 X25519 + ML-KEM-768 混合密钥协商**，不是启用 VLESSENC，也不是启用 ML-DSA-65。不要把 `supportX25519Mlkem768` 写到 Xray 服务端或出站的 `realitySettings`：这不是 Xray 的有效配置字段。三个层次见 `vless-pq.md`。

## Sub-Store 更新后 CORS 403

`403 CORS origin not allowed` 是 Sub-Store 后端拒绝网页来源，不是 VPS 节点握手失败，也不是 3x-ui 的自动续期问题。仅在用户使用自建 Sub-Store 且出现此报错时走本节，不在新 VPS 部署中额外安装或改造 Sub-Store。

较新的 Node/Docker 后端默认启用来源白名单。自定义域名访问前端时，按官方说明配置 Docker 环境变量 `SUB_STORE_CORS_ALLOWED_ORIGINS`，逗号分隔允许的来源，例如：

```text
SUB_STORE_CORS_ALLOWED_ORIGINS=https://sub-store.vercel.app,http://substore.stash,https://substore.stash,https://sub.example.com:16688
```

来源只含**协议、主机、端口**，没有 `/edit/...` 等路径；以当前浏览器地址的 origin 为准。保留实际需要的官方来源，不默认放开 `*`，不以关闭鉴权作为解决办法。

Docker 环境变量通常需要重新创建容器才能生效，单纯重启不改变创建时变量。用户要求处理时先保存现有环境变量、数据卷、端口、Token 路径和代理设置，再按其 Docker/Compose/路由器管理方式只追加白名单；不移除数据目录，不创建一个空数据卷替代原卷。修改后回读运行环境并重试原操作。用户只问原因时，不自行改动容器。

## 官方依据

- [3x-ui 通用 VLESS Reality 链接修复（最终合并代码为准）](https://github.com/MHSanaei/3x-ui/pull/6712)
- [Sub-Store 2.39.2](https://github.com/sub-store-org/Sub-Store/releases/tag/2.39.2)
- [Mihomo Reality TLS 参数](https://wiki.metacubex.one/config/proxies/tls/)
- [Sub-Store 配置与 CORS 白名单](https://github.com/sub-store-org/Sub-Store/blob/master/config/README.md)
