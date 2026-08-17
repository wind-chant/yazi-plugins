--- @since 26.5.6
-- 电子书分页预览:1 封面 / 2 元信息(标题/作者等) / 3 正文开头
-- 支持 epub / mobi / azw3 / fb2(纯 Python 标准库,零外部依赖)
-- 按需加载:每页只跑对应子命令;封面/meta/正文结果缓存在 yazi 缓存目录
-- 依赖外部命令 epub-preview(见本插件 scripts/ 目录,需安装到 PATH)
local M = {}

local MISSING_MSG = "[epub-preview] 未找到 epub-preview 命令,请先把本插件 scripts/epub-preview 安装到 PATH(如 ~/.local/bin)"

local get_page = ya.sync(function(st, url)
	return (st.pages and st.pages[url]) or 1
end)

local set_page = ya.sync(function(st, url, page)
	st.pages = st.pages or {}
	st.pages[url] = page
end)

local function run_text(job, sub, cache)
	local args = { sub, tostring(job.file.url), tostring(job.area.w) }
	if cache and cache ~= "" then
		args[#args + 1] = cache
	end
	local child = Command("epub-preview")
		:args(args)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()
	if not child then
		ya.preview_widget(job, ui.Text(MISSING_MSG):area(job.area))
		return
	end

	local output, err = child:wait_with_output()
	if not output then
		ya.preview_widget(job, {})
		return
	end

	local lines = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		lines[#lines + 1] = line
	end
	ya.preview_widget(job, ui.Text(lines):area(job.area))
end

local function cache_path(job, suffix)
	local cache = ya.file_cache { file = job.file }
	if not cache then
		return nil
	end
	return tostring(cache) .. suffix
end

local function peek_meta(job)
	run_text(job, "meta", cache_path(job, ".meta.txt"))
end

local function peek_text(job)
	run_text(job, "text", cache_path(job, ".text.txt"))
end

local function peek_cover(job)
	local cache = ya.file_cache { file = job.file }
	if not cache then
		return peek_meta(job)
	end

	local cover = tostring(cache) .. ".cover.png"
	if not fs.cha(cover) then
		local child = Command("epub-preview")
			:args({ "cover", tostring(job.file.url), cover })
			:spawn()
		if not child then
			set_page(tostring(job.file.url), 2)
			return peek_meta(job)
		end
		child:wait()
		if not fs.cha(cover) then
			-- 无封面:校正到元信息页
			set_page(tostring(job.file.url), 2)
			return peek_meta(job)
		end
	end

	if not ya.image_show(cover, job.area) then
		set_page(tostring(job.file.url), 2)
		return peek_meta(job)
	end
	-- 清掉可能残留的文本层
	ya.preview_widget(job, {})
end

function M:peek(job)
	local page = get_page(tostring(job.file.url))
	if page == 1 then
		peek_cover(job)
	elseif page == 2 then
		peek_meta(job)
	else
		peek_text(job)
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local url = tostring(job.file.url)
	local page = get_page(url)
	local next_page = page + (job.units > 0 and 1 or -1)
	if next_page < 1 or next_page > 3 then
		return
	end

	set_page(url, next_page)
	-- 触发重新 peek 渲染新页面(参照内置 code 预览器的 seek 模式)
	ya.emit("peek", { 0, only_if = job.file.url })
end

return M
