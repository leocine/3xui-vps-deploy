# Skill 版本检查

用于每次使用 3x-ui VPS Deploy Skill 后，确认 GitHub 上是否已有新版。此检查只读、非阻塞；失败时不得影响本次部署、排障或流量重置结论。

## 检查时机

在最终回复前执行，适用于：

- 新 VPS 部署。
- 已有 VPS 每月流量重置配置。
- VLESS/HY2/XHTTP 连通性排障。
- dry-run / 模拟部署说明。
- 仅更新订阅、脚本或说明的维护任务。

## 当前版本

优先从当前 skill 目录的 `README.md` 读取：

```bash
grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' README.md | head -1
```

如果当前执行目录不是 skill 根目录，先定位 `3xui-vps-deploy` skill 安装目录，再读取该目录的 `README.md`。不要把无法读取当前版本当作任务失败；最终说明“当前版本无法自动确认”即可。

## GitHub 最新版本

优先使用 GitHub Release：

```bash
gh release view --repo leocine/3xui-vps-deploy --json tagName --jq .tagName
```

如果 `gh` 不可用，回退到 Git 标签：

```bash
git ls-remote --tags --sort='v:refname' https://github.com/leocine/3xui-vps-deploy.git 'refs/tags/v*' \
  | awk -F/ '{print $NF}' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | tail -1
```

如果 GitHub 或网络不可用，最终报告只写：

```text
Skill 版本检查: 本次无法确认 GitHub 最新版本，不影响本次配置结果。
```

## 比较规则

只比较 `v主版本.次版本.修订号`。如果最新版本号大于当前版本号，最终报告中提示：

```text
Skill 版本检查:
- 当前版本: vX.Y.Z
- GitHub 最新版本: vA.B.C
- 建议: 发现新版，建议使用 skill-installer 从 GitHub 仓库 leocine/3xui-vps-deploy 安装最新版。
```

如果当前版本已经是最新：

```text
Skill 版本检查:
- 当前版本: vX.Y.Z
- GitHub 最新版本: vX.Y.Z
- 结果: 已是最新版本
```

不要自动执行安装或覆盖本地 skill，除非用户明确要求升级。
