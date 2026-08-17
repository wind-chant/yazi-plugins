--- @since 26.5.6
-- 电子书分页预览:1 封面 / 2 元信息(标题/作者等) / 3+ 正文(每页 TEXT_CHARS,可一直往下翻)
-- 支持 epub / mobi / azw3 / fb2(纯 Python 标准库,零外部依赖,解析 ~30ms 无需缓存)
-- 分页状态编码在 job.skip 里(参照内置 code 预览器):0=封面 1=元信息 >=2=正文第 N 页
-- 文本页渲染前用 ui.Clear 擦除残留封面图像(图像/文本是两个独立层)
-- 依赖外部命令 epub-preview(见本插件 scripts/ 目录,需安装到 PATH)
local M = {}

local TEXT_CHARS = 3000
local MISSING_MSG = "[epub-preview] 未找到 epub-preview 命令,请先把本插件 scripts/epub-preview 安装到 PATH(如 ~/.local/bin)"

local function run_text(job, sub, offset)
	-- 文本层渲染前先擦掉残留的封面图像(ui.Clear 会 image_erase 重叠区域)
	local widgets = { ui.Clear(job.area) }

	local cmd = Command("epub-preview")
		:arg(sub)
		:arg(tostring(job.file.url))
		:arg(tostring(job.area.w))
	if sub == "text" then
		cmd = cmd:arg(tostring(TEXT_CHARS)):arg(tostring(offset or 0))
	end
	local child = cmd:stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		widgets[#widgets + 1] = ui.Text(MISSING_MSG):area(job.area)
		ya.preview_widget(job, widgets)
		return
	end

	local output, err = child:wait_with_output()
	if not output then
		widgets[#widgets + 1] = ui.Text("epub-preview 执行失败: " .. tostring(err)):area(job.area)
		ya.preview_widget(job, widgets)
		return
	end

	local lines = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		lines[#lines + 1] = line
	end
	widgets[#widgets + 1] = ui.Text(lines):area(job.area)
	ya.preview_widget(job, widgets)
end

local function peek_meta(job)
	run_text(job, "meta", 0)
end

local function peek_cover(job)
	local cache = ya.file_cache { file = job.file }
	if not cache then
		return peek_meta(job)
	end

	local cover = tostring(cache) .. ".cover.png"
	if not fs.cha(Url(cover)) then
		-- 首次看封面页才提取(按需加载),成功后缓存
		local child = Command("epub-preview")
			:arg("cover")
			:arg(tostring(job.file.url))
			:arg(cover)
			:spawn()
		if child then
			child:wait()
		end
		if not fs.cha(Url(cover)) then
			-- 无封面或提取失败:回退显示元信息
			return peek_meta(job)
		end
	end

	local area, err = ya.image_show(Url(cover), job.area)
	if not area then
		-- 图像显示失败:回退元信息
		peek_meta(job)
		return
	end
	-- 清掉可能残留的文本层(不带 Clear,保留图像)
	ya.preview_widget(job, {})
end

function M:peek(job)
	local skip = job.skip or 0
	if skip == 0 then
		peek_cover(job)
	elseif skip == 1 then
		peek_meta(job)
	else
		-- 正文页:每页 TEXT_CHARS,offset = (skip-2) * TEXT_CHARS
		run_text(job, "text", (skip - 2) * TEXT_CHARS)
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local skip = cx.active.preview.skip or 0
	local next_skip = skip + (job.units > 0 and 1 or -1)
	if next_skip < 0 then
		return
	end

	-- 触发重新 peek 渲染新页面(参照内置 code 预览器:emit peek 更新 skip)
	ya.emit("peek", { next_skip, only_if = job.file.url })
end

return M
