# 侧边栏顶部展示图

把 GIF 或 PNG 丢进这个目录，命名成下面之一即可自动生效（无需改代码）：

| 文件名 | 说明 |
| --- | --- |
| `lobby_art.gif` | 动图，推荐 |
| `lobby_art.png` | 静态图 |

查找顺序写死在 `code/title_screen_html.dm` 的 `TG_LOBBY_ART_CANDIDATES` 里，
两个都不存在时回退到上游的 `modular_nova/modules/title_screen/icons/loading_screen.gif`。

## 放图要注意

- **尺寸建议 440×182 上下（约 2.4:1 横向）**。图片按 `cover` 居中裁切，不会被压扁，
  但太大会让 IE 内核吃内存。
- **必须由 `<img>` 标签引用** —— BYOND 的 webview 是 IE 内核，**不播放 CSS 动画背景图**
  （只会显示第一帧），所以代码里用的是 `<img>`，别改成 `background-image`。
- **换图后要重启服务器**。页面用 `browse_rsc` 按**文件名**投递资源，BYOND 对同一
  客户端的同名资源有缓存；重启最省事，否则老客户端可能还看到旧图。
