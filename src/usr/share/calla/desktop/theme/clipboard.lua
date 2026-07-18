local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

-- ── Storage ──────────────────────────────────────────────────────────────────

local cachedir = gears.filesystem.get_cache_dir()
local clipdir  = cachedir .. "clipboard/"
local histfile = cachedir .. "clipboard.json"

os.execute("mkdir -p '" .. clipdir .. "'")

local function histLoad()
	if not gears.filesystem.file_readable(histfile) then
		return {}
	end
	local h = readjson(histfile)
	if not h then h = {} end
	return h
end

local function histSave(h)
	writejson(histfile, h)
end

local MAX_ENTRIES = 30

local function pruneAndSave(h)
	while #h > MAX_ENTRIES do
		local old = table.remove(h)
		if old.type == "image" and old.path then os.remove(old.path) end
	end
	histSave(h)
end

-- ── UI: standalone popup (modeled on theme/control/wifi.lua + theme/control/notifs.lua) ─────

local clipcontainer = wibox.widget {
	spacing = dpi(10),
	layout = wibox.layout.fixed.vertical
}

local clipempty = wibox.widget {
	wibox.widget.textbox("No Clipboard History"),
	fill_vertical = true,
	align = "center",
	layout = wibox.container.place
}

local function clipbutton(widget)
	return hovercursor(wibox.widget {
		{
			iconbox({ image = widget.image }),
			margins = dpi(5),
			widget = wibox.container.margin
		},
		widget = background({ bg = "bgalt", fg = "fg" })
	})
end

local function copyBack(entry)
	if entry.type == "text" then
		local pastefile = clipdir .. "paste.tmp"
		local f = io.open(pastefile, "w")
		if f then
			f:write(entry.text or "")
			f:close()
			awful.spawn.with_shell("xclip -selection clipboard -i < '" .. pastefile .. "'")
		end
	elseif entry.type == "image" and entry.path then
		awful.spawn.with_shell("cat '" .. entry.path .. "' | xclip -selection clipboard -t image/png -i")
	end
end

local function removeFromHistory(id)
	local h = histLoad()
	for i, e in ipairs(h) do
		if e.id == id then
			if e.type == "image" and e.path then os.remove(e.path) end
			table.remove(h, i)
			break
		end
	end
	histSave(h)
end

local function createrow(entry)
	local previewwidget
	if entry.type == "image" then
		previewwidget = wibox.widget {
			image = entry.path,
			forced_width = dpi(40),
			forced_height = dpi(40),
			upscale = false,
			downscale = true,
			widget = wibox.widget.imagebox
		}
	else
		local text = (entry.text or ""):gsub("\n", " ")
		if #text > 40 then text = text:sub(1, 40) .. "…" end
		previewwidget = wibox.widget {
			text = text,
			widget = wibox.widget.textbox
		}
	end

	local row = wibox.widget {
		{
			{
				{
					previewwidget,
					left = dpi(10),
					right = dpi(5),
					top = dpi(8),
					bottom = dpi(8),
					widget = wibox.container.margin
				},
				nil,
				{
					{ id = "remove", widget = clipbutton({ image = "close" }) },
					valign = "center",
					widget = wibox.container.place
				},
				layout = wibox.layout.align.horizontal
			},
			margins = dpi(5),
			widget = wibox.container.margin
		},
		buttons = { awful.button({}, 1, function() copyBack(entry) end) },
		widget = background({ bg = "bgalt", fg = "fg" })
	}

	row:get_children_by_id("remove")[1].buttons = {
		awful.button({}, 1, function()
			clipcontainer:remove_widgets(row)
			if #clipcontainer.children == 0 then clipempty.visible = true end
			removeFromHistory(entry.id)
		end)
	}

	return row
end

local function rebuildList()
	clipcontainer:reset()
	local h = histLoad()
	if #h == 0 then
		clipempty.visible = true
	else
		clipempty.visible = false
		for _, entry in ipairs(h) do
			clipcontainer:insert(#clipcontainer.children + 1, createrow(entry))
		end
	end
end

local header = wibox.widget {
	{
		wibox.widget { text = "Clipboard", font = user.fontalt, widget = wibox.widget.textbox },
		nil,
		{ id = "clear", widget = clipbutton({ image = "close" }) },
		layout = wibox.layout.align.horizontal,
	},
	margins = dpi(10),
	widget = wibox.container.margin,
}

header:get_children_by_id("clear")[1].buttons = {
	awful.button({}, 1, function()
		clipcontainer:reset()
		clipempty.visible = true
		pruneAndSave({})
	end)
}

local clipboardbox = wibox {
	width = dpi(280),
	height = dpi(420),
	ontop = true,
	visible = false,
	bg = beautiful.bg_normal,
	widget = {
		{
			{
				header,
				{
					forced_height = dpi(1),
					bg = beautiful.fg .. "30",
					widget = wibox.container.background,
				},
				{
					{
						clipempty,
						clipcontainer,
						layout = wibox.layout.stack
					},
					margins = dpi(6),
					widget = wibox.container.margin,
				},
				layout = wibox.layout.fixed.vertical,
			},
			margins = dpi(4),
			widget = wibox.container.margin,
		},
		widget = background({ bg = "bg" }),
	}
}

local open = false

awesome.connect_signal("widget::clipboard", function()
	open = not open
	if open then
		awesome.emit_signal("widget::control::close")
		awesome.emit_signal("widget::wifi::close")
		awful.placement.bottom_right(clipboardbox, {
			margins = { bottom = dpi(60), right = dpi(20) },
			parent  = awful.screen.focused(),
		})
		rebuildList()
	end
	clipboardbox.visible = open
end)

awesome.connect_signal("widget::clipboard::close", function()
	open = false
	clipboardbox.visible = false
end)

awesome.connect_signal("live::reload", function()
	clipboardbox.bg = beautiful.bg_normal
end)

-- ── Polling ──────────────────────────────────────────────────────────────────

local last_text, last_hash = nil, nil

local POLL_CMD = [[
T=$(xclip -o -selection clipboard -t TARGETS 2>/dev/null)
case "$T" in
  *image/png*)
    printf 'IMG:'
    xclip -o -selection clipboard -t image/png 2>/dev/null | sha1sum | cut -d' ' -f1
    ;;
  *UTF8_STRING*|*STRING*|*TEXT*)
    printf 'TXT:'
    xclip -o -selection clipboard -t UTF8_STRING 2>/dev/null
    ;;
  *)
    printf 'NONE'
    ;;
esac
]]

local function addEntry(entry)
	entry.id = tostring(os.time()) .. tostring(math.random(10000, 99999))
	local h = histLoad()
	table.insert(h, 1, entry)
	pruneAndSave(h)
	rebuildList()
end

local function onPollResult(out)
	if out:sub(1, 4) == "TXT:" then
		local text = out:sub(5)
		if text ~= "" and text ~= last_text then
			last_text = text
			addEntry({ type = "text", text = text, time = os.time() })
		end
	elseif out:sub(1, 4) == "IMG:" then
		local hash = out:sub(5):gsub("%s+$", "")
		if hash ~= "" and hash ~= last_hash then
			last_hash = hash
			local dest = clipdir .. hash .. ".png"
			awful.spawn.easy_async_with_shell(
				"xclip -o -selection clipboard -t image/png 2>/dev/null > '" .. dest .. "'",
				function()
					addEntry({ type = "image", path = dest, time = os.time() })
				end
			)
		end
	end
end

gears.timer {
	timeout = 1.5,
	autostart = true,
	callback = function()
		if user.panel_clipboard == false then return end
		awful.spawn.easy_async_with_shell(POLL_CMD, onPollResult)
	end,
}
