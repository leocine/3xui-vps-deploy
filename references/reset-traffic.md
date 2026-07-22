# 3x-ui 每月流量自动重置

用于配置 3x-ui 每月自动重置所有入站和客户端的流量统计。新 VPS 部署时默认配置；已安装 3x-ui 的 VPS 也可以单独执行。只处理重置脚本、API Token 配置、日志和 cron；不得修改节点配置、Xray 配置、证书、防火墙、SSH、网络调优或系统服务结构。

## 先做只读检查

登录 VPS 后先执行只读检查：

```bash
cat /etc/os-release
uname -m
date '+%F %T %Z %z'
timedatectl 2>/dev/null || true
systemctl is-active x-ui 2>/dev/null || true
systemctl status x-ui --no-pager -l 2>/dev/null | sed -n '1,25p' || true
x-ui version 2>/dev/null || /usr/local/x-ui/x-ui version 2>/dev/null || true
command -v curl || true
command -v python3 || true
command -v crontab || true
```

确认：

- 系统是 Debian 或 Ubuntu。
- 3x-ui 正在运行。
- 能读取 3x-ui 版本、安装路径和面板端口信息。
- `curl`、`python3`、`crontab` 可用；缺失时只安装缺失的必要工具，不做系统升级。

## 修改前询问

执行任何写入前，必须确认重置日。新 VPS 部署场景使用部署前已收集的重置日；如果尚未收集，必须询问：

```text
这台 VPS 每月流量重置日是几号？例如 17 或 22。
执行时间是否使用默认北京时间 08:05？如果不是，请告诉我时间和时区。
```

默认时间是 `Asia/Shanghai 08:05`。不要固定日期；每台 VPS 按用户给出的流量周期配置。

## 新部署默认配置

新 VPS 部署时必须默认配置本流程，不要等用户额外提出。使用部署阶段生成的信息：

- 面板 URL、端口和 web base path：优先读取 `/etc/x-ui/install-result.env` 或 `x-ui settings`。
- API Token：优先读取 `/etc/x-ui/install-result.env` 中的 `XUI_API_TOKEN`。
- 重置日：使用部署前向用户收集的每月流量重置日。
- 执行时间：默认北京时间 `08:05`，按 VPS 当前系统时区换算成 cron。

如果 `/etc/x-ui/install-result.env` 没有 `XUI_API_TOKEN`，不要把面板密码写入脚本。先尝试从当前 3x-ui 版本支持的面板/API Token 管理方式创建或读取专用 token；无法自动完成时，停下让用户在面板中创建 API Token，再继续写入 `/etc/3xui-reset-traffic.env`。

## API 兼容确认

执行前必须确认当前 3x-ui API。优先查官方文档：

```text
https://docs.sanaei.dev/docs/
```

当前 3x-ui 3.5.x 推荐使用 Panel Settings 中创建的 API Token 访问 `/panel/api/*`。不要在脚本里保存面板用户名、面板密码、VPS root 密码或 SSH 私钥。

如果官方文档不可访问，必须从当前安装版本的源码、路由或面板网络请求确认接口。不要直接套旧版本接口。至少确认：

- 认证方式：优先 `Authorization: Bearer <API_TOKEN>`。
- 获取入站列表：`GET /panel/api/inbounds/list`。
- 重置所有入站流量：`POST /panel/api/inbounds/resetAllTraffics`。
- 重置所有客户端流量：优先 `POST /panel/api/clients/resetAllTraffics`。
- 兼容回退：如果当前安装版本没有全局客户端重置接口，再对入站列表中的每个 inbound id 调用 `POST /panel/api/inbounds/resetAllClientTraffics/<inbound_id>`。

如果当前版本接口不同，以当前版本实际接口为准，并把差异写入最终报告。

## 配置 API Token

已安装 VPS 单独配置时，让用户在 3x-ui 面板中创建一个只用于自动重置的 API Token。新部署场景优先复用安装结果里的 `XUI_API_TOKEN`。不要让用户把面板密码发到聊天里。

在 VPS 上创建独立配置文件：

```bash
install -m 600 -o root -g root /dev/null /etc/3xui-reset-traffic.env
nano /etc/3xui-reset-traffic.env
```

配置内容：

```bash
XUI_BASE_URL="https://127.0.0.1:<面板端口>/<web base path>"
XUI_API_TOKEN="<面板中创建的 API Token>"
CURL_INSECURE="true"
```

要求：

- `/etc/3xui-reset-traffic.env` 权限必须是 `600`。
- 不把 API Token 写入日志、Git 仓库、web 目录或公共目录。
- 如果面板本机 HTTPS 证书不被 `curl` 信任，允许 `CURL_INSECURE=true`，但不得关闭面板 HTTPS。

验证配置文件：

```bash
stat -c '%a %U %G %n' /etc/3xui-reset-traffic.env
```

## 安装重置脚本

把 skill 中的 `scripts/3xui-reset-traffic.sh` 上传或写入 VPS：

```bash
install -m 755 -o root -g root 3xui-reset-traffic.sh /usr/local/bin/3xui-reset-traffic.sh
```

脚本行为：

- 读取 `/etc/3xui-reset-traffic.env`。
- 日志写入 `/var/log/3xui-reset-traffic.log`。
- 执行前记录 3x-ui 版本、入站数量、客户端数量。
- 调用当前版本 API 重置所有 inbound 流量。
- 优先调用全局 clients API 重置所有 client 流量；必要时回退为按 inbound id 逐个重置 client 流量。
- API Token 只进入临时 `curl` config 文件，退出时删除；不在命令参数、日志或最终报告中输出。

## 配置 cron

根据用户给出的重置日生成 cron。默认目标时间是北京时间 `08:05`。

如果 VPS 系统时区是 `Asia/Shanghai`：

```cron
5 8 <重置日> * * /usr/local/bin/3xui-reset-traffic.sh
```

如果 VPS 系统时区是 `UTC`，北京时间 `08:05` 转为 UTC `00:05`：

```cron
5 0 <重置日> * * /usr/local/bin/3xui-reset-traffic.sh
```

如果 VPS 是其他时区，用当前系统时区换算。若该时区有夏令时，cron 不能稳定表达固定北京时间；先向用户说明风险，再选择改用系统时区时间或用户确认的本地执行时间。不要擅自修改 VPS 时区。

安全写入 root crontab，保留已有任务：

```bash
tmp_cron="$(mktemp)"
crontab -l 2>/dev/null >"$tmp_cron" || true
grep -v '/usr/local/bin/3xui-reset-traffic.sh' "$tmp_cron" >"${tmp_cron}.new" || true
printf '5 0 <重置日> * * /usr/local/bin/3xui-reset-traffic.sh\n' >>"${tmp_cron}.new"
crontab "${tmp_cron}.new"
rm -f "$tmp_cron" "${tmp_cron}.new"
crontab -l
```

上面的示例是 UTC。实际写入前必须替换为换算后的 cron。

## 测试验证

配置完成后手动执行一次：

```bash
bash /usr/local/bin/3xui-reset-traffic.sh
tail -n 50 /var/log/3xui-reset-traffic.log
crontab -l
```

确认：

- API 调用成功。
- inbound 流量重置成功。
- client 流量重置成功。
- 日志正常生成。
- cron 日期和时间正确。

如果测试时用户不希望立刻清零当前流量，不要执行脚本；只完成配置并把状态标记为“待用户手动触发测试”。

## 最终输出

完成后输出：

```text
3x-ui 每月流量自动重置已配置。

VPS 系统:
系统时间/时区:
3x-ui 版本:
流量重置日:
执行时间:
API 接口:
脚本路径: /usr/local/bin/3xui-reset-traffic.sh
配置文件: /etc/3xui-reset-traffic.env
cron 配置:
测试结果:
日志路径: /var/log/3xui-reset-traffic.log

Skill 版本检查:
- 当前版本:
- GitHub 最新版本:
- 是否建议升级:

安全说明:
- 未保存 VPS root 密码或 SSH 私钥
- 未输出面板密码或 API Token
- 未修改节点配置、Xray 配置、防火墙、SSH 或系统网络
```
