# gmdl-theme-pack

给 [go-music-dl](https://github.com/guohuiyuan/go-music-dl) Web 界面用的**反代注入式主题/功能包**：深色模式、玻璃拟态、个性化面板（主题/风格/文字/强调色/背景/背景图/歌词样式）、每日推荐歌曲按钮。不改上游一行代码，容器更新也不丢。

## 包含什么

| 文件 | 说明 |
|---|---|
| `gmdl-dark.css` | 深色 + 玻璃拟态全部覆盖样式（含 APlayer 播放器、卡拉OK歌词、设置弹窗、下载记录表） |
| `gmdl-ui.js` | 个性化面板：主题 / 风格(曜石/玻璃) / 文字色 / 歌词字号 / 歌词发光 / 强调色×6 / 背景×4 / 背景图上传+模糊 / 玻璃强度，偏好存浏览器 localStorage |
| `gmdl-feat.js` | 功能扩展：首页「每日推荐歌曲」按钮、空格搜索结果页「再来十首」追加加载（自动去重） |
| `openresty-vhost-example.conf` | OpenResty 反代配置示例：HTTPS、`/music` 主站、`/player`（Navidrome）、注入逻辑 |

## 原理

在反向代理层用 `sub_filter` 给上游 HTML 注入 `<link>` + `<script>`，样式/脚本由反代直接 serve。更新时改文件 + 递增 `?v=N` 版本号即可绕过浏览器缓存。

## 安装（OpenResty 示例）

1. 把 `gmdl-dark.css`、`gmdl-ui.js`、`gmdl-feat.js` 放到反代 webroot（示例：`/usr/share/nginx/html`）。
2. 参考 `openresty-vhost-example.conf` 加三个 exact-match location + `location /` 里的 `sub_filter` 注入和 `Accept-Encoding` 置空（gzip 会让 sub_filter 失效）。
3. `nginx -t && nginx -s reload`，打开页面 Ctrl+F5。

## 版本约定

资源 URL 带 `?v=N`，每次改动递增 N，片段见 `openresty-vhost-example.conf`。

## 说明

- 本包所有文件为原创，MIT 协议。
- 上游项目 go-music-dl 为 AGPL-3.0，本包不包含、不修改其任何代码，仅在网络层叠加样式与脚本。
- 插件/歌词/下载产生的数据与版权与本包无关，请合法合规使用。
