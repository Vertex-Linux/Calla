local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local icons = "/usr/share/icons/" .. beautiful.icons .. "/64x64/"
local desktopjson = gears.filesystem.get_cache_dir() .. "desktop.json"
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local Gio = lgi.Gio
local UPower = lgi.require("UPowerGlib")

local function shellescape(str)
	return str:gsub("'", "'\\''")
end

local function desktopDialog(title, prompt, default, callback)
	local dialog = Gtk.Dialog({ title = title })
	dialog:add_button("Cancel", Gtk.ResponseType.CANCEL)
	dialog:add_button("OK",     Gtk.ResponseType.OK)
	local entry = Gtk.Entry({ text = default or "", margin_start = 10, margin_end = 10, margin_bottom = 8 })
	function entry:on_activate() dialog:response(Gtk.ResponseType.OK) end
	local box = dialog:get_content_area()
	box:add(Gtk.Label({ label = prompt, halign = Gtk.Align.START, margin_start = 10, margin_top = 8, margin_bottom = 4 }))
	box:add(entry)
	dialog:show_all()
	local response = dialog:run()
	local text = entry.text
	dialog:destroy()
	if response == Gtk.ResponseType.OK and text ~= "" then
		callback(text)
	end
end

screen.connect_signal("request::desktop_decoration", function(s)

	--[[ logic for grabbing batteries, for use in future desktop widgets
	local function listdevices()
		local ret = {}
		local devices = UPower.Client():get_devices()

		for _, device in ipairs(devices) do
			table.insert(ret, device:get_object_path())
		end

		return ret
	end

	local function getdevice(path)
		local devices = UPower.Client():get_devices()

		for _, device in ipairs(devices) do
			if device:get_object_path() == path then
				return device
			end
		end

		return nil
	end

	local devicepaths = listdevices()

	for _, path in ipairs(devicepaths) do
		local device = getdevice(path)

		device.on_notify = function()
		end
	end
	--]]

	local cell = dpi(120)
	local geometry = s:get_bounding_geometry()
	local rows = math.floor((geometry.height-dpi(60))/cell)
	local cols = math.floor((geometry.width-dpi(20))/cell)
	local vspacing = math.floor((((geometry.height-dpi(60))-(rows*cell))/(rows-1))+0.5)
	local hspacing = math.floor((((geometry.width-dpi(20))-(cols*cell))/(cols-1))+0.5)

	s.grid = wibox.widget {
		forced_num_rows = rows,
		forced_num_cols = cols,
		vertical_spacing = vspacing,
		horizontal_spacing = hspacing,
		orientation = "horizontal",
		layout = wibox.layout.grid
	}

	s.manual = wibox.layout {
		layout = wibox.layout.manual
	}

	s.padding = {
		top = dpi(10),
		bottom = dpi(50),
		left = dpi(10),
		right = dpi(10)
	}

	s.base = wibox {
		screen = s,
		ontop = false,
		visible = true,
		type = "splash"
	}

	s.desktop = wibox {
		screen = s,
		width = s.geometry.width-dpi(20),
		height = s.geometry.height-dpi(60),
		ontop = false,
		visible = true,
		type = "desktop"
	}

	awful.placement.maximize(s.base)

	awful.placement.top(
		s.desktop,
		{
			margins = {
				top = dpi(10)
			}
		}
	)

	s.panel = require("theme.panel")(s)

	s.base:setup {
		{
			s.panel,
			valign = "bottom",
			content_fill_horizontal = true,
			widget = wibox.container.place
		},
		widget = live(wibox.container.background, { bg = "bg" })
	}

	s.desktop:setup {
		{
			id = "wallpaper",
			image = gears.surface.crop_surface {
				surface = gears.surface.load_uncached(beautiful.wallpaper),
				ratio = (s.geometry.width-dpi(20))/(s.geometry.height-dpi(60))
			},
			widget = wibox.widget.imagebox
		},
		s.grid,
		s.manual,
		layout = wibox.layout.stack
	}

	-- Custom context menu — one shared wibox + a transparent full-screen overlay
	-- that captures outside clicks. Avoids awful.menu entirely (it leaves ghost
	-- wiboxes that picom keeps compositing, and has no "click outside" support
	-- on desktop-type wiboxes).

	local ctxopen = false

	local ctxoverlay = wibox {
		ontop   = true,
		visible = false,
		opacity = 0,
	}

	local ctxmenu = wibox {
		ontop        = true,
		visible      = false,
		border_width = dpi(1),
		border_color = beautiful.bg_focus,
	}

	local function ctxClose()
		ctxopen          = false
		ctxoverlay.visible = false
		ctxmenu.visible    = false
	end

	ctxoverlay.buttons = {
		awful.button({}, 1, ctxClose),
		awful.button({}, 2, ctxClose),
		awful.button({}, 3, ctxClose),
	}

	local function ctxShow(items)
		-- Always close any open menu first (no early return — this lets a
		-- file right-click replace an open desktop menu and vice-versa).
		ctxClose()

		local rows = {}
		local h    = 0

		for _, item in ipairs(items) do
			local name, fn = item[1], item[2]
			local row
			if name == "" then
				row = wibox.widget {
					forced_height = dpi(1),
					bg            = beautiful.bg_focus,
					widget        = wibox.container.background,
				}
				h = h + dpi(1)
			else
				local bg_normal = beautiful.bg_normal
				local bg_hover  = beautiful.bg_focus
				row = wibox.widget {
					{
						wibox.widget.textbox(name),
						left   = dpi(10),
						right  = dpi(10),
						widget = wibox.container.margin,
					},
					forced_height = dpi(24),
					bg            = bg_normal,
					fg            = beautiful.fg_normal,
					widget        = wibox.container.background,
				}
				row:connect_signal("mouse::enter", function() row.bg = bg_hover  end)
				row:connect_signal("mouse::leave", function() row.bg = bg_normal end)
				row.buttons = {
					awful.button({}, 1, function()
						ctxClose()
						if type(fn) == "function" then fn() end
					end)
				}
				h = h + dpi(24)
			end
			table.insert(rows, row)
		end

		rows.layout = wibox.layout.fixed.vertical
		ctxmenu:setup(rows)

		local mw  = dpi(165)
		local c   = mouse.coords()
		local sg  = awful.screen.focused().geometry
		ctxmenu.width  = mw
		ctxmenu.height = h
		ctxmenu.x = math.min(c.x, sg.x + sg.width  - mw)
		ctxmenu.y = math.min(c.y, sg.y + sg.height - h)

		ctxoverlay.x      = sg.x
		ctxoverlay.y      = sg.y
		ctxoverlay.width  = sg.width
		ctxoverlay.height = sg.height

		-- Map overlay FIRST, then menu. In X11 each XMapWindow raises the
		-- window to the top of its stacking layer, so the menu (mapped last)
		-- ends up above the overlay. Overlay catches outside clicks;
		-- menu items are above it and receive their own clicks normally.
		-- The X11 passive grab keeps the button-3 release event on the
		-- desktop wibox even after the overlay is visible, so the overlay
		-- cannot accidentally catch the release that opened the menu.
		ctxopen            = true
		ctxoverlay.visible = true
		ctxmenu.visible    = true
	end

	local function showDesktopMenu()
		ctxShow({
			{ "Settings",      function() awesome.emit_signal("widget::config") end },
			{ "Open Terminal", function() awful.spawn(user.terminal) end },
			{ "" },
			{ "New File",   function()
				desktopDialog("New File", "File name:", "new_file.txt", function(name)
					awful.spawn.with_shell("touch ~/Desktop/'" .. shellescape(name) .. "'")
				end)
			end },
			{ "New Folder", function()
				desktopDialog("New Folder", "Folder name:", "New Folder", function(name)
					awful.spawn.with_shell("mkdir -p ~/Desktop/'" .. shellescape(name) .. "'")
				end)
			end },
			{ "" },
			{ "Refresh", function() awesome.emit_signal("desktop::refresh") end },
		})
	end

	local function showFileMenu(label, exec)
		ctxShow({
			{ "Open",   function() awful.spawn.with_shell(exec) end },
			{ "" },
			{ "Rename", function()
				desktopDialog("Rename", "New name:", label, function(newname)
					awful.spawn.with_shell(
						"mv ~/Desktop/'" .. shellescape(label) .. "' ~/Desktop/'" .. shellescape(newname) .. "'"
					)
				end)
			end },
			{ "Delete", function()
				local dlg = Gtk.Dialog({ title = "Confirm Delete" })
				dlg:add_button("Cancel", Gtk.ResponseType.CANCEL)
				dlg:add_button("Delete", Gtk.ResponseType.OK)
				dlg:get_content_area():add(Gtk.Label({
					label        = "Permanently delete '" .. label .. "'?",
					margin_start = 15, margin_end    = 15,
					margin_top   = 12, margin_bottom = 12,
				}))
				dlg:show_all()
				local r = dlg:run()
				dlg:destroy()
				if r == Gtk.ResponseType.OK then
					awful.spawn.with_shell("rm -rf ~/Desktop/'" .. shellescape(label) .. "'")
				end
			end },
		})
	end

	local function generate()
		local entries = {}

		for entry in io.popen([[ls ~/Desktop | sed '']]):lines() do
			local label = nil
			local exec = nil
			local icon = nil

			if entry:match("^.+(%..+)$") == ".desktop" then
				for line in io.popen("cat ~/Desktop/'" .. entry .. "'"):lines() do
					if line:match("Name=") and not label then
						label = line:gsub("Name=", "")
					end
					if line:match("Exec=") and not exec then
						exec = line:gsub("Exec=", ""):gsub("%%U", ""):gsub("%%u", "")
					end
					if line:match("CustomIcon=") and not icon then
						icon = line:gsub("CustomIcon=", "")
					elseif line:match("Icon=") and not icon then
						icon = line:gsub("Icon=", "")
					end
				end
				table.insert(entries, { label = label, exec = exec, icon = icon })
			elseif os.execute("cd ~/Desktop'" .. entry .. "'") then
				label = entry
				icon = "folder"
				exec = "gio open ~/Desktop/'" .. entry .. "'"
				table.insert(entries, { label = label, exec = exec, icon = icon })
			else
				label = entry
				icon = Gio.File.new_for_path(os.getenv("HOME") .. "/Desktop/" .. entry):query_info("standard::*", Gio.FileQueryInfoFlags.NONE):get_icon()
				for _, name in ipairs(icon:get_names()) do
					if Gtk.IconTheme.get_default():has_icon(name) then
						icon = name
						break
					end
					icon = "application-x-generic"
				end
				exec = "gio open ~/Desktop/'" .. entry .. "'"
				table.insert(entries, { label = label, exec = exec, icon = icon })
			end
		end

		return entries
	end

	local function save()
		layout = {}

		for i, widget in ipairs(s.grid.children) do
			local pos = s.grid:get_widget_position(widget)

			layout[i] = {
				row = pos.row,
				col = pos.col,
				widget = {
					label = widget.label,
					exec = widget.exec,
					icon = widget.icon
				}
			}
		end

		writejson(desktopjson, layout)
	end

	local function gridindexat(y, x) -- gotta fix this to account for spacing
		local margin = dpi(10)

		local row = math.ceil((y - margin) / cell)
		row = math.min(row, rows)
		row = math.max(row, 1)

		local col = math.ceil((x - margin) / cell)
		col = math.min(col, cols)
		col = math.max(col, 1)

		return row, col
	end

	local function exists(path)
		local f = io.open(path, "r")
		if f~=nil then io.close(f) return true else return false end
	end

	local function createdesktopicon(label, exec, icon)
		local image
		if exists(icons .. "places/" .. icon .. ".svg") then
			image = icons .. "places/" .. icon .. ".svg"
		elseif exists(icons .. "mimetypes/" .. icon .. ".svg") then
			image = icons .. "mimetypes/" .. icon .. ".svg"
		elseif exists(icons .. "apps/" .. icon .. ".svg") then
			image = icons .. "apps/" .. icon .. ".svg"
		elseif exists(icon) then
			image = icon
		else
			image = icons .. "mimetypes/application-x-generic.svg"
		end

		local widget = hovercursor(wibox.widget {
			{
				{
					{
						image = image,
						halign = "center",
						widget = wibox.widget.imagebox
					},
					strategy = "exact",
					width = dpi(50),
					height = dpi(50),
					widget = wibox.container.constraint
				},
				{
					{
						{
							{
								valign = "top",
								align = "center",
								widget = colortext({ text = label })
							},
							margins = dpi(5),
							widget = wibox.container.margin
						},
						widget = background({ bg = "bgmid" })
					},
					strategy = "max",
					width = dpi(100),
					height = dpi(50),
					widget = wibox.container.constraint
				},
				spacing = dpi(5),
				layout = wibox.layout.fixed.vertical
			},
			label = label,
			exec = exec,
			icon = icon,
			forced_width = cell,
			forced_height = cell,
			top = dpi(10),
			left = dpi(10),
			right = dpi(10),
			widget = wibox.container.margin
		})

		widget:connect_signal("button::press", function(_, _, _, button)
			if button == 3 then
				showFileMenu(label, exec)
				return
			end
			if not mousegrabber.isrunning() then
				local heldwidget = wibox.widget {
					{
						{
							{
								image = image,
								opacity = 0.5,
								halign = "center",
								widget = wibox.widget.imagebox
							},
							strategy = "exact",
							width = dpi(50),
							height = dpi(50),
							widget = wibox.container.constraint
						},
						{
							{
								{
									{
										opacity = 0.5,
										valign = "top",
										align = "center",
										widget = colortext({ text = label })
									},
									margins = dpi(5),
									widget = wibox.container.margin
								},
								widget = background({ bg = "bgmid" })
							},
							strategy = "max",
							width = dpi(100),
							height = dpi(50),
							widget = wibox.container.constraint
						},
						spacing = dpi(5),
						layout = wibox.layout.fixed.vertical
					},
					forced_width = cell,
					forced_height = cell,
					top = dpi(10),
					left = dpi(10),
					right = dpi(10),
					visible = false,
					widget = wibox.container.margin
				}

				local startpos = mouse.coords()
				heldwidget.point = { x = startpos.x, y = startpos.y }
				local oldpos = s.grid:get_widget_position(widget)
				s.manual:add(heldwidget)

				mousegrabber.run(function(mouse)
					if (math.abs(mouse.x - startpos.x) > 10 or
						math.abs(mouse.y - startpos.y) > 10) and
						mouse.buttons[1] then

						s.grid:remove(widget)
						heldwidget.visible = true

						s.manual:move_widget(heldwidget, {
							x = mouse.x - dpi(50),
							y = mouse.y - dpi(50)
						})
					end

					if not mouse.buttons[1] then
						if button == 1 then
							if heldwidget.visible then
								heldwidget.visible = false

								local newrow, newcol = gridindexat(
									mouse.y,
									mouse.x
								)
								if not s.grid:get_widgets_at(newrow, newcol) then
									s.grid:add_widget_at(widget, newrow, newcol)
									save()
								else
									s.grid:add_widget_at(widget, oldpos.row, oldpos.col)
								end
							else
								awful.spawn.with_shell(exec)
								s.manual:reset()
							end
							mousegrabber.stop()
						end
					end
					return mouse.buttons[1]
				end, "hand2")
			end
		end)

		return widget
	end

	local function load()
		s.grid:reset()

		if not gears.filesystem.file_readable(desktopjson) then
			local entries = generate()
			for _, entry in ipairs(entries) do
				s.grid:add(createdesktopicon(entry.label, entry.exec, entry.icon))
			end
			save()
			return
		end

		local layout = readjson(desktopjson)

		for _, entry in ipairs(layout) do
			s.grid:add_widget_at(createdesktopicon(entry.widget.label, entry.widget.exec, entry.widget.icon), entry.row, entry.col)
		end
	end

	load()

	-- Right-click on empty desktop area.
	-- Defer by one event-loop tick: widget button::press (file icons) fires
	-- during the same X11 event but AFTER the wibox handler. By deferring
	-- with a 0-delay timer we let any icon handler run first and set ctxopen.
	-- If ctxopen is still false after that tick, no icon was clicked and we
	-- show the desktop menu.
	s.desktop.buttons = {
		awful.button({}, 3, function()
			gears.timer.start_new(0, function()
				if not ctxopen then showDesktopMenu() end
				return false
			end)
		end)
	}

	-- Full desktop reload (called from right-click menu Refresh)
	awesome.connect_signal("desktop::refresh", function() load() end)

	awesome.connect_signal("signal::desktop", function(type)
		local entries = generate()
		local check = false

		if type == "add" then
			for _, entry in ipairs(entries) do
				for _, widget in ipairs(s.grid.children) do
					if entry.label == widget.label then
						check = true
						break
					end
				end
				if check == false then
					s.grid:add(createdesktopicon(entry.label, entry.exec, entry.icon))
				end
				check = false
			end
		end

		if type == "remove" then
			for _, widget in ipairs(s.grid.children) do
				for _, entry in ipairs(entries) do
					if entry.label == widget.label then
						check = true
						break
					end
				end
				if check == false then
					s.grid:remove(widget)
				end
				check = false
			end
		end

		save()
	end)

	awesome.connect_signal("live::reload", function()
		s.desktop:get_children_by_id("wallpaper")[1].image = gears.surface.crop_surface {
			surface = gears.surface.load_uncached(beautiful.wallpaper),
			ratio = (s.geometry.width-dpi(20))/(s.geometry.height-dpi(60))
		}
		ctxmenu.border_color = beautiful.bg_focus
	end)

end)
