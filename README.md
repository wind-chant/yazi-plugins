# yazi-plugins

个人 Yazi 插件集合(monorepo),结构与官方 [yazi-rs/plugins](https://github.com/yazi-rs/plugins) 一致:每个插件一个 `<name>.yazi/` 目录,可用 `ya pkg` 单独安装。

## 插件列表

| 插件 | 说明 | 安装 |
|---|---|---|
| [epub-preview.yazi](epub-preview.yazi/README.md) | 电子书分页预览:封面 / 元信息(标题、作者等)/ 正文开头。支持 epub / mobi / azw3 / fb2,**纯 Python 标准库,零第三方依赖** | `ya pkg add wind-chant/yazi-plugins:epub-preview` |

## 安装方式

```sh
# 1. 安装插件本体
ya pkg add wind-chant/yazi-plugins:epub-preview

# 2. 安装依赖命令(具体见各插件 README)
install -Dm755 ~/.config/yazi/plugins/epub-preview.yazi/scripts/epub-preview ~/.local/bin/epub-preview

# 3. 在 ~/.config/yazi/yazi.toml 注册预览器
```

手动安装(不依赖 GitHub):

```sh
git clone https://github.com/wind-chant/yazi-plugins.git ~/.config/yazi/plugins/yazi-plugins
ln -s ~/.config/yazi/plugins/yazi-plugins/epub-preview.yazi ~/.config/yazi/plugins/epub-preview.yazi
```

## 开发约定

- 每个插件目录名以 `.yazi` 结尾,内含 `main.lua` + `README.md` + `LICENSE`
- 需要外部命令的插件,脚本放 `<name>.yazi/scripts/` 下,README 说明安装到 PATH
- 许可证 MIT
