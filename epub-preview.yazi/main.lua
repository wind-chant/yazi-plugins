--- @since 26.5.6
-- 电子书分页预览:1 封面 / 2 元信息(标题/作者等) / 3+ 正文(行级滚动,与内置 txt 预览器一致)
-- 支持 epub / mobi / azw3 / fb2(纯 Python 标准库,零外部依赖,解析 ~30ms)
-- skip 编码:0=封面 1=元信息 >=2=正文起始行号(skip-2)
-- 滚动:封面/元信息页 J/K 切换页面;正文滚轮逐行、J/K 整页翻动
-- 文本页渲染前用 ui.Clear 擦除残留封面图像(图像/文本是两个独立层)
-- 依赖外部命令 epub-preview(见本插件 scripts/ 目录,需安装到 PATH)
local M = {}

local MISSING_MSG = "[epub-preview] 未找到 epub-preview 命令,请先把本插件 scripts/epub-preview 安装到 PATH(如 ~/.local/bin)"

local function cache_path(job, suffix)
	local cache = ya.file_cache { file = job.file }
	if not cache then
		return nil
	end
	return tostring(cache) .. suffix
end

local function img_fallback(job, zip_path)
	-- 插图显示失败:回退为提示行(并擦除可能残留的图像层)
	local widgets = {
		ui.Clear(job.area),
		ui.Text({ "[插图: " .. zip_path .. "]" }):area(job.area),
	}
	ya.preview_widget(job, widgets)
end

local function show_img(job, zip_path)
	local cache = ya.file_cache { file = job.file }
	if not cache then
		img_fallback(job, zip_path)
		return
	end

	local child = Command("epub-preview")
		:arg("img")
		:arg(tostring(job.file.url))
		:arg(zip_path)
		:arg(tostring(cache))
		:stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		img_fallback(job, zip_path)
		return
	end

	local output, err = child:wait_with_output()
	local img_file = output and output.stdout:gsub("%s+$", "") or ""
	if not output or img_file == "" or not fs.cha(Url(img_file)) then
		img_fallback(job, zip_path)
		return
	end

	local area, ierr = ya.image_show(Url(img_file), job.area)
	if not area then
		img_fallback(job, zip_path)
		return
	end
	-- 图像层显示成功:清掉残留的文本层(不带 Clear,保留图像)
	ya.preview_widget(job, {})
end

local function run_text(job, sub, start_line)
	-- 文本层渲染前先擦掉残留的封面图像(ui.Clear 会 image_erase 重叠区域)
	local widgets = { ui.Clear(job.area) }

	local cmd = Command("epub-preview")
		:arg(sub)
		:arg(tostring(job.file.url))
		:arg(tostring(job.area.w))
	if sub == "text" then
		local cache = cache_path(job, ".text.txt")
		cmd = cmd:arg(tostring(start_line or 0)):arg("1000")
		if cache then
			cmd = cmd:arg(cache)
		end
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

	-- 不能用 "[^\r\n]+"：那会吞掉空行，而 job.skip 仍把空行计数。
	-- 必须保留空行，否则滚到空行时相邻两个 offset 会渲染同一屏内容。
	local lines = {}
	local text = output.stdout:gsub("\r\n", "\n")
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	-- 上面的补换行会在 stdout 原本以换行结尾时多捕获一个尾空行；它不影响
	-- 普通正文页，但移除以避免末尾多出无意义的一次滚动。
	if text:sub(-1) == "\n" then
		table.remove(lines)
	end
	-- 图片标记行:整页显示插图,滚动经过时像封面一样占一"页"
	local mark = lines[1] and lines[1]:match("^\x1fIMG:(.-)\x1f$")
	if mark then
		show_img(job, mark)
		return
	end

	-- 普通文本页:标记行显示为插图提示
	for i, ln in ipairs(lines) do
		if ln:match("^\x1fIMG:") then
			lines[i] = "[插图]"
		end
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
		-- 正文:起始行号 = skip - 2(行级滚动,与内置 code 预览器一致)
		run_text(job, "text", skip - 2)
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local skip = cx.active.preview.skip or 0
	local next_skip
	if skip < 2 then
		-- 封面/元信息页:J 下一页,K 上一页
		next_skip = skip + (job.units > 0 and 1 or -1)
	else
		-- 正文：滚轮保持逐行；J/K（units 绝对值大于 1）整页翻动。
		local step = job.units
		if math.abs(job.units) > 1 then
			step = job.units > 0 and job.area.h or -job.area.h
		end
		next_skip = skip + step
		if next_skip <= 1 then
			next_skip = 1 -- 滚回顶部时停到元信息页
		end
	end
	if next_skip < 0 then
		return
	end

	-- 触发重新 peek(参照内置 code 预览器:emit peek 更新 skip)
	ya.emit("peek", { next_skip, only_if = job.file.url })
end

return M
