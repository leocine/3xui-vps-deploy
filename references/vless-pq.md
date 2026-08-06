# VLESS 后量子与 Reality 组合

本文件区分 VLESS 协议层的 ML-KEM-768/VLESSENC 与 Reality 证书层的 ML-DSA-65。两者可以独立启用，也可以组合启用；不能因为其中一组字段存在就宣称另一组也已启用。

## 模式矩阵

| 模式 | 后量子层 | 服务端关键字段 | 客户端关键字段 | 是否要求 `mldsa65Seed/Verify` |
| --- | --- | --- | --- | --- |
| 普通 VLESS + Reality | 无 | `settings.decryption=none` | `users[].encryption=none` | 否 |
| VLESS ML-KEM-768 + Reality | VLESS 协议层 | `settings.decryption=mlkem768x25519plus...` | `users[].encryption=mlkem768x25519plus...` | 否 |
| VLESS + Reality ML-DSA-65 | Reality 证书签名层 | `realitySettings.mldsa65Seed` | Reality `mldsa65Verify` | 是 |
| VLESS ML-KEM-768 + Reality ML-DSA-65 | 两层同时启用 | 同时具备上面两组服务端字段 | 同时具备上面两组客户端字段 | 是 |

## ML-KEM-768 / VLESSENC

### 生成与字段归属

- 使用当前实际运行的 Xray Core 执行 `xray vlessenc`，选择 `Authentication: ML-KEM-768, Post-Quantum`；不要复制示例中的长字符串。
- 同一次生成得到的 `decryption` 和 `encryption` 必须成对使用，不能跨服务器、跨生成批次或手工拼接。
- 服务端入站使用 `settings.decryption`，通常形如 `mlkem768x25519plus.native.600s.<generated-value>`。
- 客户端 VLESS 出站用户使用 `settings.vnext[].users[].encryption`，通常形如 `mlkem768x25519plus.native.0rtt.<generated-value>`；`1rtt` 或 `0rtt` 必须以当前客户端支持情况和实际测试结果为准。
- `native`、`xorpub`、`random`、时间参数和可选 padding 都是生成值的一部分，保存完整字符串，不要截断、重排或替换其中一段。

Xray Core 的入站配置归属是 `decryption`，出站用户归属是 `encryption`；不要把客户端 `encryption` 写入入站 `clients`。3x-ui 面板导出或 API 结果可能在入站 `settings` 中同时展示面板字段，必须以 `/usr/local/x-ui/bin/config.json` 和实际下发的客户端订阅为准，不能把面板导出 JSON 原样当作 Xray Core 配置。

生成后执行配置测试并重启服务：

```bash
xray run -test -config /usr/local/x-ui/bin/config.json
systemctl restart x-ui
sleep 3
systemctl is-active x-ui
```

验收时只输出字段是否存在，不输出完整的 `decryption`、`encryption`、UUID 或订阅内容：

```bash
grep -Eq '"decryption"[[:space:]]*:[[:space:]]*"mlkem768x25519plus\.' /usr/local/x-ui/bin/config.json
```

服务端配置存在不等于客户端可用。必须使用支持 VLESSENC 的 Xray 客户端，从实际订阅或临时客户端配置读取对应的 `encryption`，完成代理 HTTPS 请求；不支持该字段的 Mihomo、订阅转换器或旧客户端只能使用普通兼容节点。

## Reality ML-DSA-65

- 服务端使用当前 Xray Core 的 `xray mldsa65` 生成 `mldsa65Seed`，客户端 Reality 使用同次输出的 `mldsa65Verify`。
- 这组字段用于 Reality 临时证书的额外后量子签名验证，不等于 VLESS 的 ML-KEM-768 加密。
- 只有选择这个模式时，才要求 `mldsa65Seed` 与 `mldsa65Verify` 非空且成对；ML-KEM-only 模式下两项可以为空。
- 目标站证书大小、`X25519MLKEM768` 支持等检查只在启用 ML-DSA-65 Reality 时执行；交付中不要仅凭其中一项写成“全链路后量子”。

## XHTTP + Reality + ML-KEM

你提供的实际配置属于这一组合：

- `network=xhttp`、`security=reality`。
- `xhttpSettings.path` 使用随机短路径，`host` 可留空，`mode=auto`。
- `xPaddingBytes=100-1000`、`scMaxBufferedPosts=30`、`scStreamUpServerSecs=20-80` 可作为默认值。
- `scMaxEachPostBytes` 是可选项；3x-ui 生成结果为空时不要强行补成 `1000000`。
- `spiderX` 可以是随机的非根路径；必须以 `/` 开头，并在客户端 Reality 参数中保持一致。
- XHTTP 默认不要自动写入 `xtls-rprx-vision`。如果面板或实际 Core 生成了该 flow，必须按当前 Core 版本执行 `xray run -test` 和外部代理测试；不要仅凭面板保存成功判定可用。

首次部署仍只创建一个逻辑客户端 `admin`，所有默认入站按现有规则共享 `admin` 的 UUID 和 `subId`；启用 ML-KEM 不增加按协议拆分的客户端。

## 官方参考

- Xray Core VLESS 配置解析：<https://github.com/XTLS/Xray-core/blob/main/infra/conf/vless.go>
- REALITY ML-DSA-65 字段说明：<https://github.com/XTLS/REALITY/blob/main/README.en.md>
- XHTTP 与 Vision flow 的兼容性讨论：<https://github.com/XTLS/Xray-core/issues/5576>
