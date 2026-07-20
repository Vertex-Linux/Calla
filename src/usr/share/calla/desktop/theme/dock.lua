local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local dockjson = gears.filesystem.get_cache_dir() .. "dock.json"
local dockicondir = gears.filesystem.get_cache_dir() .. "dock/"

os.execute("mkdir -p '" .. dockicondir .. "'")

-- Cache the icon a running client is actually using (the same source
-- awful.widget.clienticon shows in the taskbar) so a pinned icon always
-- matches, instead of guessing an icon-theme name from the WM_CLASS string.
local function saveIcon(class, c)
	if not (c and c.icon) then return nil end
	local path = dockicondir .. class:gsub("[^%w%-_.]", "_") .. ".png"
	local ok = pcall(function()
		gears.surface.load(c.icon):write_to_png(path)
	end)
	return ok and path or nil
end

local tasklist

-- Custom context menu (same overlay pattern as the desktop menu so that
-- clicking anywhere outside dismisses it and the menu never goes off-screen).
local _dmenu_open = false

local _dmenu_overlay = wibox { ontop = true, visible = false, opacity = 0 }
local _dmenu_box     = wibox {
	ontop        = true,
	visible      = false,
	border_width = dpi(1),
	border_color = beautiful.bgalt,
}

local function dockMenuClose()
	_dmenu_open            = false
	_dmenu_overlay.visible = false
	_dmenu_box.visible     = false
end

_dmenu_overlay.buttons = {
	awful.button({}, 1, dockMenuClose),
	awful.button({}, 2, dockMenuClose),
	awful.button({}, 3, dockMenuClose),
}

local function showDockMenu(items)
	dockMenuClose()

	local rows = {}
	local h    = 0
	for _, item in ipairs(items) do
		local name, fn = item[1], item[2]
		local bg_n = beautiful.bg
		local bg_h = beautiful.bgalt
		local row = wibox.widget {
			{
				wibox.widget.textbox(name),
				left   = dpi(10),
				right  = dpi(10),
				widget = wibox.container.margin,
			},
			forced_height = dpi(24),
			bg            = bg_n,
			fg            = beautiful.fg,
			widget        = wibox.container.background,
		}
		row:connect_signal("mouse::enter", function() row.bg = bg_h end)
		row:connect_signal("mouse::leave", function() row.bg = bg_n end)
		row.buttons = {
			awful.button({}, 1, function()
				dockMenuClose()
				if type(fn) == "function" then fn() end
			end)
		}
		table.insert(rows, row)
		h = h + dpi(24)
	end

	rows.layout = wibox.layout.fixed.vertical
	_dmenu_box:setup(rows)

	local mw = dpi(165)
	local c  = mouse.coords()
	local sg = awful.screen.focused().geometry

	-- Clamp to screen so the menu never overflows any edge
	local mx = math.min(c.x, sg.x + sg.width  - mw)
	local my = math.min(c.y, sg.y + sg.height - h)
	mx = math.max(mx, sg.x)
	my = math.max(my, sg.y)

	_dmenu_box.width  = mw
	_dmenu_box.height = h
	_dmenu_box.x = mx
	_dmenu_box.y = my

	_dmenu_overlay.x      = sg.x
	_dmenu_overlay.y      = sg.y
	_dmenu_overlay.width  = sg.width
	_dmenu_overlay.height = sg.height

	-- Overlay first → menu maps on top
	_dmenu_open            = true
	_dmenu_overlay.visible = true
	_dmenu_box.visible     = true
end

local pins = wibox.widget {
	spacing = dpi(5),
	layout = wibox.layout.fixed.horizontal
}

local separator = wibox.widget {
	orientation = "vertical",
	thickness = dpi(2),
	span_ratio = 0.75,
	forced_width = dpi(5),
	visible = false,
	widget = live(wibox.widget.separator, { color = "bgalt" })
}

if not gears.filesystem.file_readable(dockjson) then
	writejson(dockjson, {})
end
local pinned = readjson(dockjson)

-- Rebuild `pinned` to match the current on-screen order of `pins` (each pin
-- widget is tagged with `.pin_class`), then persist it.
local function syncPinnedOrder()
	local neworder = {}
	for _, w in ipairs(pins:get_children()) do
		for _, app in ipairs(pinned) do
			if app.class == w.pin_class then
				table.insert(neworder, app)
				break
			end
		end
	end
	for i = #pinned, 1, -1 do pinned[i] = nil end
	for i, app in ipairs(neworder) do pinned[i] = app end
	writejson(dockjson, pinned)
end

local function pin(class, exec, iconpath)
	local icon = iconpath
	if not icon then
		local theme = Gtk.IconTheme.get_default()
		local info = theme:lookup_icon(class:lower(), 64, 0)
		if info then
			icon = info:get_filename()
		else
			icon = require("menubar").utils.lookup_icon_uncached(class:lower())
			if not icon then
				local fallback = theme:lookup_icon("application-default-icon", 64, 0)
				icon = fallback and fallback:get_filename() or nil
			end
		end
	end
	local widget = hovercursor(wibox.widget {
		{
			{
				{
					shape = function(cr, width, height)
								gears.shape.rounded_rect(cr, width, height, dpi(8))
							end,
					id = "background",
					bg = beautiful.bg,
					widget = wibox.container.background
				},
				margins = dpi(2),
				widget = wibox.container.margin
			},
			shape = function(cr, width, height)
						gears.shape.rounded_rect(cr, width, height, dpi(10))
					end,
			id = "foreground",
			bg = beautiful.fg,
			widget = wibox.container.background
		},
		{
			wibox.widget.imagebox(icon),
			margins = dpi(5),
			widget = wibox.container.margin
		},
		layout = wibox.layout.stack
	})
	widget.pin_class = class

	local function unpin()
		for i, app in ipairs(pinned) do
			if app.class == class then table.remove(pinned, i); break end
		end
		pins:remove(pins:index(widget))
		tasklist._do_tasklist_update_now()
		writejson(dockjson, pinned)
	end

	local clickAction = function() awful.spawn.with_shell(exec) end

	local function check()
		local present = false
		local focused = false
		if client.focus and client.focus.class == class then
			widget:get_children_by_id("background")[1].bg = beautiful.bgalt
			widget:get_children_by_id("foreground")[1].bg = beautiful.fg .. "64"
			local fc = client.focus
			clickAction = function()
				for _, c in ipairs(client.get()) do
					if c.class == class then c.minimized = false; c:raise() end
				end
			end
			widget.buttons = {
				awful.button({ "Shift" }, 1, function() awful.spawn.with_shell(exec) end),
				awful.button({}, 3, function()
					showDockMenu({
						{ "Minimize",        function() fc.minimized = true end },
						{ "Force Quit",      function() fc:kill() end },
						{ "Unpin from Dock", unpin },
					})
				end),
			}
			present = true
			focused = true
		end
		if not focused then
			for _, c in ipairs(client.get()) do
				if c.class == class then
					widget:get_children_by_id("background")[1].bg = beautiful.bgalt
					widget:get_children_by_id("foreground")[1].bg = beautiful.bgalt
					clickAction = function()
						c.first_tag:view_only()
						for _, c2 in ipairs(client.get()) do
							if c2.class == class then
								c2.minimized = false; c2:raise(); c2:activate()
							end
						end
					end
					widget.buttons = {
						awful.button({ "Shift" }, 1, function() awful.spawn.with_shell(exec) end),
						awful.button({}, 3, function()
							showDockMenu({
								{ "Minimize",        function() c.minimized = true end },
								{ "Force Quit",      function() c:kill() end },
								{ "Unpin from Dock", unpin },
							})
						end),
					}
					present = true
					return
				end
			end
		end
		if not present then
			widget:get_children_by_id("background")[1].bg = beautiful.bg
			widget:get_children_by_id("foreground")[1].bg = beautiful.bg
			clickAction = function() awful.spawn.with_shell(exec) end
			widget.buttons = {
				awful.button({}, 3, function()
					showDockMenu({
						{ "Launch",          function() awful.spawn.with_shell(exec) end },
						{ "Unpin from Dock", unpin },
					})
				end),
			}
		end
		widget:emit_signal("widget::redraw_needed")
	end

	-- Modifiers awesome itself ignores when matching "no modifier" bindings
	-- (Caps Lock / Num Lock) -- see awful.button's `ignore_modifiers`.
	local IGNORED_MODS = { Lock = true, Mod2 = true }

	-- Plain left-click is handled by hand here (rather than via `.buttons`) so
	-- it can be distinguished from a drag-to-reorder gesture. Shift+click and
	-- right-click stay on `.buttons` above, untouched.
	widget:connect_signal("button::press", function(_, _, _, button, modifiers)
		if button ~= 1 then return end
		if modifiers then
			for _, m in ipairs(modifiers) do
				if not IGNORED_MODS[m] then return end
			end
		end
		if mousegrabber.isrunning() then return end

		local startpos = mouse.coords()
		local dragging = false

		mousegrabber.run(function(m)
			if not dragging and m.buttons[1] and
				(math.abs(m.x - startpos.x) > 10 or math.abs(m.y - startpos.y) > 10) then
				dragging = true
				widget.opacity = 0.5
			end

			if dragging then
				local under = mouse.current_widgets
				if under then
					for _, w in ipairs(under) do
						if w ~= widget and w.pin_class then
							pins:swap_widgets(widget, w)
							break
						end
					end
				end
			end

			if not m.buttons[1] then
				if dragging then
					widget.opacity = 1
					syncPinnedOrder()
				else
					clickAction()
				end
				mousegrabber.stop()
				return false
			end

			return true
		end, "fleur")
	end)

	client.connect_signal("request::manage", check)
	client.connect_signal("request::unmanage", check)
	client.connect_signal("focus", check)
	client.connect_signal("unfocus", check)
	awesome.connect_signal("live::reload", check)

	check()

	return widget
end

local function contains(table, name)
	for _, app in ipairs(table) do
		if app == name then
			return true
		end
	end
	return false
end

tasklist = awful.widget.tasklist {
	screen = awful.screen.focused(),
	filter = awful.widget.tasklist.filter.allscreen,
	source = function()
		local seen = {}
		local ret = {}

		for _, c in ipairs(client.get()) do
			local exclude = false
			for _, app in ipairs(pinned) do
				if c.class == app.class then
					exclude = true
					break
				end
			end
			if not exclude and not contains(seen, c.class) or c.minimized == true then
				table.insert(seen, c.class)
				table.insert(ret, c)
			end
		end

		if seen[1] and pinned[1] then
			separator.visible = true
		else
			separator.visible = false
		end

		return ret
	end,
	style = {
		shape = function(cr, width, height)
					gears.shape.rounded_rect(cr, width, height, dpi(10))
				end
	},
	layout = {
		spacing = dpi(5),
		spacing_widget = wibox.container.background,
		layout = wibox.layout.fixed.horizontal
	},
	widget_template = {
		{
			{
				{
					awful.widget.clienticon,
					margins = dpi(5),
					widget = wibox.container.margin
				},
				shape = function(cr, width, height)
							gears.shape.rounded_rect(cr, width, height, dpi(8))
						end,
				id = "background",
				widget = wibox.container.background
			},
			margins = dpi(2),
			widget = wibox.container.margin
		},
		shape = function(cr, width, height)
					gears.shape.rounded_rect(cr, width, height, dpi(10))
				end,
		id = "foreground",
		bg = beautiful.fg,
		widget = wibox.container.background,
		create_callback = function(self, c)
			local exec
			if c.pid then
				awful.spawn.easy_async("readlink -f /proc/" .. c.pid .. "/exe", function(out)
					exec = out:gsub("\n", "")
				end)
			end
			self.buttons = {
				awful.button({}, 1, function()
					c.first_tag:view_only()
					c.minimized = false
					c:raise()
				end),
				awful.button({}, 3, function()
					local already_pinned = false
					for _, app in ipairs(pinned) do
						if app.class == c.class then already_pinned = true; break end
					end
					local pin_label = already_pinned and "Unpin from Dock" or "Pin to Dock"
					local pin_action = function()
						if already_pinned then return end
						local iconpath = saveIcon(c.class, c)
						pins:add(pin(c.class, exec, iconpath))
						table.insert(pinned, { class = c.class, exec = exec, icon = iconpath })
						tasklist._do_tasklist_update_now()
						writejson(dockjson, pinned)
					end
					showDockMenu({
						{ "Focus",       function() c.first_tag:view_only(); c.minimized = false; c:raise() end },
						{ "Minimize",    function() c.minimized = true end },
						{ "Force Quit",  function() c:kill() end },
						{ pin_label,     pin_action },
					})
				end)
			}
			hovercursor(self)

			if client.focus == c then
				self:get_children_by_id("background")[1].bg = beautiful.bgalt
				self:get_children_by_id("foreground")[1].bg = beautiful.fg .. "64"
			else
				self:get_children_by_id("background")[1].bg = beautiful.bgalt
				self:get_children_by_id("foreground")[1].bg = beautiful.bgalt
			end
			client.connect_signal("focus", function()
				if client.focus == c then
					self:get_children_by_id("background")[1].bg = beautiful.bgalt
					self:get_children_by_id("foreground")[1].bg = beautiful.fg .. "64"
				else
					self:get_children_by_id("background")[1].bg = beautiful.bgalt
					self:get_children_by_id("foreground")[1].bg = beautiful.bgalt
				end
			end)
			client.connect_signal("unfocus", function()
				self:get_children_by_id("background")[1].bg = beautiful.bgalt
				self:get_children_by_id("foreground")[1].bg = beautiful.bgalt
			end)
			awesome.connect_signal("live::reload", function()
				if client.focus == c then
					self:get_children_by_id("background")[1].bg = beautiful.bgalt
					self:get_children_by_id("foreground")[1].bg = beautiful.fg .. "64"
				else
					self:get_children_by_id("background")[1].bg = beautiful.bgalt
					self:get_children_by_id("foreground")[1].bg = beautiful.bgalt
				end
			end)
		end
	}
}

for _, app in ipairs(pinned) do
	pins:add(pin(app.class, app.exec, app.icon))
end

local dock = wibox.widget {
	{
		pins,
		separator,
		tasklist,
		spacing = dpi(5),
		layout = wibox.layout.fixed.horizontal
	},
	halign = "center",
	widget = wibox.container.place
}

return dock
