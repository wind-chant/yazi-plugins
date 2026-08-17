# epub-preview.yazi

Yazi 电子书分页预览插件:**封面 → 元信息(标题/作者/出版社等)→ 正文开头**,滚动(`J`/`K`)切换页面,按需加载。

支持格式:

| 格式 | 解析方式 | 元信息 | 封面 | 正文 |
|---|---|---|---|---|
| epub | Python 标准库(zip + OPF) | Dublin Core | OPF cover | 按 spine 取第一章 |
| mobi | 标准库(PalmDB + MOBI header + EXTH) | EXTH 100/101/503/524 等 | EXTH 201 + 图像记录 | PalmDoc(mobi 变体)解压 |
| azw3 | 同 mobi(KF8 分片) | 同上 | 同上 | 同上 |
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
3. 按 `J` → **正文开头**(自动跳过封面/版权页,取第一章)
4. 按 `K` 往回翻页

## 实现说明

- `main.lua`:分页状态用 `ya.sync` 持久表按文件 URL 记录;seek 换页后 `ya.emit("peek", ...)` 触发重绘(参照内置 `code` 预览器模式)
- `scripts/epub-preview`:单文件 Python 脚本,三个子命令 `cover` / `meta` / `text`,按格式自动分发
- 性能:epub ~30ms / mobi ~37ms 每次;封面、元信息、正文转换结果均缓存在 `ya.file_cache` 目录
- mobi 解析要点(均对照 calibre 官方源码 `palmdoc.c` / `headers.py` 验证):
  - `compression=2` 是 **PalmDoc 压缩**(17480 才是 HUFF/CDIC)
  - PalmDoc 的 mobi 变体:`0x80-0xBF` 为 2 字节重复码,`0xC0-0xFF` 为「空格+大写字母」编码
  - record 0 存在有无 `BOOKMOBI` magic 两种布局,MOBI 标识位于 0x10
  - EXTH 不能依赖 flags 判断;封面 = EXTH 201 偏移 + 第一条图像记录

## License

MIT
