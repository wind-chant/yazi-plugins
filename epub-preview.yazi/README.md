# epub-preview.yazi

Yazi 电子书分页预览插件:**封面 → 元信息(标题/作者/出版社等) → 完整正文**。鼠标滚轮逐显示行滚动，`J`/`K` 整页翻动。

支持格式:

| 格式 | 解析方式 | 元信息 | 封面 | 正文 |
|---|---|---|---|---|
| epub | Python 标准库(zip + OPF) | Dublin Core | OPF cover | 完整 spine；支持普通 `<img>` 正文插图 |
| mobi | 标准库(PalmDB + MOBI header + EXTH) | EXTH 100/101/503/524 等 | EXTH 201 + 图像记录 | 无压缩 / PalmDoc / HUFF-CDIC |
| azw3 | 同 mobi(KF8 分片) | 同上 | 同上 | 无压缩 / PalmDoc / HUFF-CDIC |
| fb2 | 标准库(FictionBook XML) | description/title-info | binary base64 | body 段落 |

**零第三方依赖、零外部命令**(不需要 calibre / pandoc / epr)。

## 安装

```sh
# 1. 插件本体
ya pkg add wind-chant/yazi-plugins:epub-preview

# 2. 把解析脚本安装到 PATH
install -Dm755 ~/.config/yazi/plugins/epub-preview.yazi/scripts/epub-preview ~/.local/bin/epub-preview
```

## 注册预览器

`~/.config/yazi/yazi.toml` 的 `[plugin]` 段添加:

```toml
[plugin]
prepend_previewers = [
  { mime = "application/epub+zip", run = "epub-preview" },
  { mime = "application/mobipocket-ebook", run = "epub-preview" },
  { url = "*.epub", run = "epub-preview" },
  { url = "*.mobi", run = "epub-preview" },
  { url = "*.azw",  run = "epub-preview" },
  { url = "*.azw3", run = "epub-preview" },
  { url = "*.fb2",  run = "epub-preview" },
]
```

> 注意:yazi 内置 mime 检测会把 `x-` / `vnd.` 前缀剥掉(见 `mime-local.lua`),
> 所以 mobi 的 mime 要写 `application/mobipocket-ebook` 而不是
> `application/x-mobipocket-ebook`;url 扩展名匹配是最保险的兜底。

## 使用

重启 yazi 后,光标移到电子书上:

1. **封面**(自动提取,缓存到 yazi 缓存目录;无封面自动跳到元信息页)
2. 按 `J` → **元信息**:标题 / 作者 / 出版社 / 标签 / 语言 / 日期
3. 按 `J` → **完整正文**(自动跳过短封面/版权页)
4. 正文中鼠标滚轮逐显示行滚动，`J`/`K` 整页翻动
5. EPUB 普通 `<img>` 插图滚到顶部时整页显示；SVG 口絵/扉页暂不处理

## 实现说明

- `main.lua`:分页状态编码在 Yazi 管理的 `job.skip` 中；`seek` 后通过 `ya.emit("peek", ...)` 重绘，不依赖跨 Lua state 的 `ya.sync`
- `scripts/epub-preview`:单文件 Python 脚本，提供 `cover` / `meta` / `text` / `img` 子命令并按格式自动分发
- 正文先按终端显示宽度完整折行，再按 `job.skip` 切片；Lua 保留空行，保证滚轮偏移与可视行一一对应
- 封面、元信息和完整正文缓存在 Yazi 临时缓存目录；解析失败结果不写缓存
- mobi 解析要点(均对照 calibre 官方源码 `palmdoc.c` / `headers.py` 验证):
  - `compression=2` 是 **PalmDoc 压缩**；`17480` 是 **HUFF/CDIC**，两者均已支持
  - PalmDoc 的 mobi 变体:`0x80-0xBF` 为 2 字节重复码,`0xC0-0xFF` 为「空格+大写字母」编码
  - record 0 存在有无 `BOOKMOBI` magic 两种布局,MOBI 标识位于 0x10
  - 正文范围来自 PalmDOC 的 `text_record_count`；HUFF/CDIC 解压前按 `extra_flags` 去除尾部附加数据
  - EXTH 不能依赖 flags 判断;封面 = EXTH 201 偏移 + 第一条图像记录

## License

MIT
