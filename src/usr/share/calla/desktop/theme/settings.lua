awesome.connect_signal("widget::config", function()

local dpi = require("beautiful").xresources.apply_dpi
local lgi = require("lgi")
local Gio = lgi.Gio
local Gtk = lgi.require("Gtk", "3.0")
local Gdk = lgi.require("Gdk", "3.0")
local GdkPixbuf = lgi.require("GdkPixbuf", "2.0")
local GObject = lgi.require("GObject", "2.0")

local appID = "io.github.stardust-kyun.calla.settings"
local appTitle = "Settings"
local app = Gtk.Application({ application_id = appID })

local function copytable(table)
	local copy = {}
	for key, value in pairs(table) do
		copy[key] = value
	end
	return copy
end

local settings = copytable(user)

local color

local function genColor()
	color = readjson(require("gears").filesystem.get_cache_dir() .. "color/" .. settings.color .. "/" .. settings.color .. ".json")
end

genColor()

local function settingsEntry(name, setting, default)

	local label = Gtk.Label({ label = name, halign = Gtk.Align.START })
	local settingsEntry = Gtk.Entry({ placeholder_text = settings[setting], width = dpi(175) })
	function settingsEntry:on_key_release_event()
		settings[setting] = settingsEntry.text
	end
	local button = Gtk.Button.new_with_label("Default")
	function button:on_clicked()
		settings[setting] = default
		settingsEntry.placeholder_text = settings[setting]
		settingsEntry.text = ""
	end
	local grid = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),
		halign = Gtk.Align.CENTER,

		{ label, top_attach = 0, left_attach = 0, width = 2 },
		{ settingsEntry, top_attach = 1, left_attach = 0 },
		{ button, top_attach = 1, left_attach = 1 },
	})

	return grid

end

local function colorEntry(name, setting, default)

	local label = Gtk.Label({ label = name, halign = Gtk.Align.START })
	local colorEntry = Gtk.Entry({ placeholder_text = color[setting], width = dpi(175) })
	function colorEntry:on_key_release_event()
		color[setting] = colorEntry.text
	end
	local button = Gtk.Button.new_with_label("Default")
	function button:on_clicked()
		color[setting] = default
		colorEntry.placeholder_text = color[setting]
		colorEntry.text = ""
	end
	local grid = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),
		halign = Gtk.Align.CENTER,

		{ label, top_attach = 0, left_attach = 0, width = 2 },
		{ colorEntry, top_attach = 1, left_attach = 0 },
		{ button, top_attach = 1, left_attach = 1 },
	})

	return grid

end

local function createColor(name, col, colname)

	local rgbcol = Gdk.RGBA.parse(col)

	local label = Gtk.Label({ label = name, halign = Gtk.Align.START })
	local button = Gtk.ColorButton({ rgba = rgbcol, show_editor = true })
	function button:on_color_set()
		local out = button:get_rgba():to_string()

		local red = out:match("%d+,"):gsub(",", "")
		local green = out:match(",%d+,"):gsub(",", "")
		local blue = out:match(",%d+%)"):gsub(",", ""):gsub("%)", "")

		local hex = string.format("#%02X%02X%02X", red, green, blue)
		
		color[colname] = hex
	end
	local grid = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),
		halign = Gtk.Align.CENTER,

		{ label, top_attach = 0, left_attach = 0 },
		{ button, top_attach = 1, left_attach = 0 },
	})

	return grid

end

local function doGeneral()

	local function wallpaper()

		local label = Gtk.Label({ label = "Wallpaper", halign = Gtk.Align.START })

		local filter = Gtk.FileFilter()
		filter:add_pattern("*.png")
		filter:add_pattern("*.jpg")
		filter:add_pattern("*.JPG")
		filter:add_pattern("*.jpeg")

		if settings.wallpaper ~= nil then
			local pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(settings.wallpaper:gsub("~", os.getenv("HOME")), 500, 500, true)
		else
			local pixbuf
		end
		local preview = Gtk.Image()

		local wallpaper = Gtk.FileChooserButton({ filter = filter, title = "Choose Wallpaper", width = dpi(175), preview_widget = preview })
		if settings.wallpaper ~= nil then
			wallpaper:set_file(Gio.File.new_for_path(settings.wallpaper:gsub("~", os.getenv("HOME"))))
			wallpaper:set_current_folder_file(Gio.File.new_for_path(settings.wallpaper:gsub("~", os.getenv("HOME"))))
		else
			wallpaper:set_file(Gio.File.new_for_path(""))
			wallpaper:set_current_folder_file(Gio.File.new_for_path(os.getenv("HOME")))
		end
		function wallpaper:on_file_set()
			settings.wallpaper = self:get_filename():gsub(os.getenv("HOME"), "~")
		end
		function wallpaper:on_update_preview()
			pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(self:get_preview_filename(), 500, 500, true)
			preview:set_from_pixbuf(pixbuf)
			wallpaper:set_preview_widget_active(true)
		end

		local button = Gtk.Button.new_with_label("Default")
		function button:on_clicked()
			settings.wallpaper = nil
			wallpaper:set_file(Gio.File.new_for_path(""))
		end

		local grid = Gtk.Grid({
			column_spacing = dpi(10),
			row_spacing = dpi(10),
			halign = Gtk.Align.CENTER,

			{ label, top_attach = 0, left_attach = 0, width = 2 },
			{ wallpaper, top_attach = 1, left_attach = 0 },
			{ button, top_attach = 1, left_attach = 1 },
		})

		return grid

	end

	local function screenshot()

		local label = Gtk.Label({ label = "Screenshot Directory", halign = Gtk.Align.START })
		local button = Gtk.FileChooserButton({ title = "Choose Screenshot Directory", width = dpi(245), action = Gtk.FileChooserAction.SELECT_FOLDER })
		button:set_current_folder_file(Gio.File.new_for_path(settings.shotdir:gsub("~", os.getenv("HOME"))))
		function button:on_file_set()
			settings.shotdir = self:get_filename():gsub(os.getenv("HOME"), "~")
		end

		local grid = Gtk.Grid({
			column_spacing = dpi(10),
			row_spacing = dpi(10),
			halign = Gtk.Align.CENTER,

			{ label, top_attach = 0, left_attach = 0 },
			{ button, top_attach = 1, left_attach = 0 },
		})

		return grid

	end

	local grid = Gtk.Grid({
		column_spacing = dpi(20),
		row_spacing = dpi(10),
		margin = dpi(20),
		halign = Gtk.Align.CENTER,

		{ settingsEntry("Terminal", "terminal", "st"), top_attach = 0, left_attach = 0 },
		{ settingsEntry("Shutdown", "shutdown", "systemctl poweroff"), top_attach = 1, left_attach = 0 },
		{ settingsEntry("Reboot", "reboot", "systemctl reboot"), top_attach = 2, left_attach = 0 },
		{ settingsEntry("Font", "font", "Roboto Medium 11"), top_attach = 0, left_attach = 1 },
		{ settingsEntry("Alt Font", "fontalt", "Roboto Bold 11"), top_attach = 1, left_attach = 1 },
		{ settingsEntry("Fallback Password", "passwd", "awesomewm"), top_attach = 3, left_attach = 0 },
		{ settingsEntry("Battery", "batt", "BAT0"), top_attach = 2, left_attach = 1 },
		{ wallpaper(), top_attach = 3, left_attach = 1 },
		{ settingsEntry("temp", "temp", "temp"), top_attach = 4, left_attach = 1 },
		{ screenshot(), top_attach = 4, left_attach = 0 },
	})

	return grid

end

local function doColor()

	genColor()

	local left = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),
		halign = Gtk.Align.CENTER,

		{ createColor("Bg", color.bg, "bg"), top_attach = 0, left_attach = 0 },
		{ createColor("Mid Bg", color.bgmid, "bgmid"), top_attach = 1, left_attach = 0 },
		{ createColor("Alt Bg", color.bgalt, "bgalt"), top_attach = 2, left_attach = 0 },
		{ createColor("Fg", color.fg, "fg"), top_attach = 0, left_attach = 1 },
		{ createColor("Black", color.black, "black"), top_attach = 1, left_attach = 1 },
		{ createColor("White", color.white, "white"), top_attach = 2, left_attach = 1 },
		{ createColor("Red", color.red, "red"), top_attach = 0, left_attach = 2 },
		{ createColor("Green", color.green, "green"), top_attach = 1, left_attach = 2 },
		{ createColor("Yellow", color.yellow, "yellow"), top_attach = 2, left_attach = 2 },
		{ createColor("Blue", color.blue, "blue"), top_attach = 0, left_attach = 3 },
		{ createColor("Magenta", color.magenta, "magenta"), top_attach = 1, left_attach = 3 },
		{ createColor("Cyan", color.cyan, "cyan"), top_attach = 2, left_attach = 3 },

		{ colorEntry("Gui Theme", "gtk", color.gtk), top_attach = 3, left_attach = 0, width = 4 },
	})

	local right = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),
		halign = Gtk.Align.CENTER,

		{ colorEntry("Compositor Radius", "compradius", color.compradius), top_attach = 0, left_attach = 0 },
		{ colorEntry("Compositor Offset", "compoffset", color.compoffset), top_attach = 1, left_attach = 0 },
		{ colorEntry("Compositor Opacity", "compopacity", color.compopacity), top_attach = 2, left_attach = 0 },
		{ colorEntry("Icon Theme", "icons", color.icons), top_attach = 3, left_attach = 0 },
	})

	local grid = Gtk.Grid({
		column_spacing = dpi(20),
		halign = Gtk.Align.CENTER,

		{ left, top_attach = 0, left_attach = 0 },
		{ right, top_attach = 0, left_attach = 1 },

	})

	return grid
end

local function doTheme()

	local function colorgen()
		local colors = {}

		for dir in io.popen("ls -d " .. require("gears").filesystem.get_configuration_dir() .. "color/*/ | rev | cut -f2 -d'/' | rev"):lines() do
			table.insert(colors, dir)
		end

		return colors
	end

	local model = Gtk.ListStore.new({ GObject.Type.STRING })
	local items = colorgen()
	local currentcolor = 0

	for i, name in ipairs(items) do
		model:append({ name })

		if name == settings.color then
			currentcolor = i-1
		end
	end

	local combo = Gtk.ComboBox({
		model = model,
		active = currentcolor,
		cells = {
			{
				Gtk.CellRendererText(),
				{ text = 1 },
				align = Gtk.Align.START
			}
		},
		expand = true
	})

	local savebutton = Gtk.Button.new_with_label("Save Theme As...")
	local confirmbutton = Gtk.Button.new_with_label("Confirm")
	local cancelbutton = Gtk.Button.new_with_label("Cancel")
	local nameset = false

	local themeprompt = Gtk.Label({ label = "What should this theme be called?", halign = Gtk.Align.START })
	local themename = Gtk.Entry({ placeholder_text = "Theme Name", hexpand = true })
	local name
	function themename:on_key_release_event()
		name = themename.text
	end

	local wallprompt = Gtk.Label({ label = "What wallpaper should this theme use?", halign = Gtk.Align.START })
	local filter = Gtk.FileFilter()
	filter:add_pattern("*.png")
	filter:add_pattern("*.jpg")

	local preview = Gtk.Image()

	local wallpaper = nil
	local wallpaperbutton = Gtk.FileChooserButton({ filter = filter, title = "Choose Wallpaper", hexpand = true, preview_widget = preview })
	wallpaperbutton:set_file(Gio.File.new_for_path(""))
	wallpaperbutton:set_current_folder_file(Gio.File.new_for_path(os.getenv("HOME")))
	function wallpaperbutton:on_file_set()
		wallpaper = self:get_filename()
	end
	function wallpaperbutton:on_update_preview()
		pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(self:get_preview_filename(), 500, 500, true)
		preview:set_from_pixbuf(pixbuf)
		wallpaperbutton:set_preview_widget_active(true)
	end

	local colorscheme = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),

		{ Gtk.Label({ label = "Color Scheme", halign = Gtk.Align.START }), top_attach = 0, left_attach = 0 },
		{ combo, top_attach = 1, left_attach = 0 },
		{ savebutton, top_attach = 1, left_attach = 1 }
	})

	function savebutton:on_clicked()
		colorscheme:remove(combo)
		colorscheme:remove(savebutton)
		colorscheme:attach(themeprompt, 0, 1, 1, 1)
		colorscheme:attach(themename, 1, 1, 1, 1)
		colorscheme:attach(confirmbutton, 2, 1, 1, 1)
		colorscheme:attach(cancelbutton, 3, 1, 1, 1)
		colorscheme:show_all()
	end
	function confirmbutton:on_clicked()
		if nameset == false and name ~= "" then
			nameset = true
			colorscheme:remove(themeprompt)
			colorscheme:remove(themename)
			colorscheme:attach(wallprompt, 0, 1, 1, 1)
			colorscheme:attach(wallpaperbutton, 1, 1, 1, 1)
			colorscheme:show_all()	
		elseif nameset == true and wallpaper then
			local themedir = require("gears").filesystem.get_cache_dir() .. "color/" .. name .. "/"
			local path = Gio.File.new_for_path(themedir)
			local sourcepath = Gio.File.new_for_path(wallpaper)
			local targetpath = Gio.File.new_for_path(themedir .. name .. ".png")
			path:make_directory()
			sourcepath:copy(targetpath, Gio.FileCopyFlags.NONE, nil, nil, nil, nil)
			color.wall = targetpath:get_path():gsub(require("gears").filesystem.get_cache_dir(), "")
			writejson(require("gears").filesystem.get_cache_dir() .. "color/" .. name .. "/" .. name .. ".json", color)
		
			table.insert(items, name)
			model:append({name})
			colorscheme:remove(wallprompt)
			colorscheme:remove(wallpaperbutton)
			colorscheme:remove(confirmbutton)
			colorscheme:remove(cancelbutton)
			colorscheme:attach(combo, 0, 1, 1, 1)
			colorscheme:attach(savebutton, 1, 1, 1, 1)
			nameset = false
			themename.text = ""
			colorscheme:show_all()
		end
	end
	function cancelbutton:on_clicked()
		colorscheme:remove(themeprompt)
		colorscheme:remove(themename)
		colorscheme:remove(wallprompt)
		colorscheme:remove(wallpaperbutton)
		colorscheme:remove(confirmbutton)
		colorscheme:remove(cancelbutton)
		colorscheme:attach(combo, 0, 1, 1, 1)
		colorscheme:attach(savebutton, 1, 1, 1, 1)
		nameset = false
		themename.text = ""
		colorscheme:show_all()
	end

	local grid = Gtk.Grid({
		column_spacing = dpi(10),
		row_spacing = dpi(10),
		margin = dpi(20),
		halign = Gtk.Align.CENTER,

		{ colorscheme, top_attach = 0, left_attach = 0 },
		{ doColor(), top_attach = 1, left_attach = 0 },

	})

	function combo:on_changed()
		local n = self:get_active()
		settings.color = items[n+1]
		grid:remove(grid:get_child_at(0, 1))
		local colorwidget = doColor()
		grid:attach(colorwidget, 0, 1, 1, 1)
		colorwidget:show_all()
	end

	return grid

end

local function doPanel()

	local function panelSwitch(name, setting)
		local label = Gtk.Label({ label = name, halign = Gtk.Align.START, hexpand = true })
		local switch = Gtk.Switch({ active = settings[setting] ~= false, valign = Gtk.Align.CENTER })
		function switch:on_state_set(state)
			settings[setting] = state
			return false
		end
		local row = Gtk.Box({
			orientation = Gtk.Orientation.HORIZONTAL,
			spacing = dpi(20),
			margin_start = dpi(10),
			margin_end = dpi(10),
			label,
			switch,
		})
		return row
	end

	local col1 = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		spacing = dpi(10),
		panelSwitch("Start Menu",   "panel_menu"),
		panelSwitch("Workspace",    "panel_taglist"),
		panelSwitch("Layout Box",   "panel_layouts"),
		panelSwitch("System Tray",  "panel_systray"),
		panelSwitch("Dock",         "panel_dock"),
		panelSwitch("WiFi",         "panel_wifi"),
	})

	local col2 = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		spacing = dpi(10),
		panelSwitch("Music",      "panel_media"),
		panelSwitch("Volume",     "panel_volume"),
		panelSwitch("Battery",    "panel_battery"),
		panelSwitch("Clock",      "panel_clock"),
		panelSwitch("Cheatsheet", "panel_cheatsheet"),
	})

	local grid = Gtk.Grid({
		column_spacing = dpi(30),
		row_spacing = dpi(10),
		margin = dpi(20),
		halign = Gtk.Align.CENTER,
		valign = Gtk.Align.START,

		{ col1, top_attach = 0, left_attach = 0 },
		{ col2, top_attach = 0, left_attach = 1 },
	})

	return grid

end

-- ── Display helpers ───────────────────────────────────────────────────────────

local function getDisplays()
	local displays, current = {}, nil
	local f = io.popen("xrandr --query 2>/dev/null")
	if not f then return displays end
	for line in f:lines() do
		local name = line:match("^(%S+) connected")
		if name then
			if current then table.insert(displays, current) end
			current = { name = name, cur_res = nil, cur_rate = nil, modes = {} }
			local cw, ch = line:match("(%d+)x(%d+)%+%d+%+%d+")
			if cw then current.cur_res = cw .. "x" .. ch end
		elseif current then
			local res = line:match("^%s+(%d+x%d+)")
			if res then
				local rates = {}
				for rate in line:gmatch("(%d+%.%d+)") do
					table.insert(rates, rate)
				end
				table.insert(current.modes, { res = res, rates = rates })
				if line:find("%*") then
					current.cur_res  = res
					current.cur_rate = line:match("(%d+%.%d+)%*")
				end
			end
		end
	end
	f:close()
	if current then table.insert(displays, current) end
	return displays
end

-- ── Audio helpers ─────────────────────────────────────────────────────────────

local function parsePactl(cmd)
	local items, cur = {}, nil
	local f = io.popen(cmd .. " 2>/dev/null")
	if not f then return items end
	for line in f:lines() do
		local n = line:match("^\tName: (.+)")
		if n then
			if cur then table.insert(items, cur) end
			cur = { name = n, desc = n, volume = 100 }
		elseif cur then
			local d = line:match("^\tDescription: (.+)")
			if d then cur.desc = d end
			if not cur.vol_set then
				local v = line:match("(%d+)%%")
				if v then cur.volume = tonumber(v); cur.vol_set = true end
			end
		end
	end
	f:close()
	if cur then table.insert(items, cur) end
	return items
end

local function getSinks()   return parsePactl("pactl list sinks")   end
local function getSources()
	local all, real = parsePactl("pactl list sources"), {}
	for _, s in ipairs(all) do
		if not s.name:find("%.monitor$") then table.insert(real, s) end
	end
	return real
end

local function getDefault(cmd)
	local f = io.popen(cmd .. " 2>/dev/null")
	if not f then return nil end
	local r = f:read("*l"); f:close()
	return r and r:match("^%S+") or nil
end

-- ── Display tab ───────────────────────────────────────────────────────────────

local function doDisplay()

	local displays = getDisplays()

	local outer = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		spacing     = dpi(16),
		margin      = dpi(20),
		halign      = Gtk.Align.CENTER,
		valign      = Gtk.Align.START,
	})

	if #displays == 0 then
		outer:add(Gtk.Label({ label = "No connected displays found (is xrandr installed?)" }))
		return outer
	end

	for _, disp in ipairs(displays) do
		local frame = Gtk.Frame({ label = disp.name })
		local grid  = Gtk.Grid({
			column_spacing = dpi(10),
			row_spacing    = dpi(8),
			margin         = dpi(12),
		})

		-- Determine which mode index is current
		local cur_idx = 0
		for i, mode in ipairs(disp.modes) do
			if mode.res == disp.cur_res then cur_idx = i - 1; break end
		end

		local res_combo  = Gtk.ComboBoxText()
		local rate_combo = Gtk.ComboBoxText()

		for _, mode in ipairs(disp.modes) do
			res_combo:append_text(mode.res)
		end

		local function fillRates(mi)
			rate_combo:remove_all()
			local rates = disp.modes[mi + 1] and disp.modes[mi + 1].rates or {}
			for _, r in ipairs(rates) do rate_combo:append_text(r .. " Hz") end
			-- Highlight current rate on initial fill
			if mi == cur_idx and disp.cur_rate then
				for j, r in ipairs(rates) do
					if r == disp.cur_rate then rate_combo:set_active(j - 1); break end
				end
			else
				if #rates > 0 then rate_combo:set_active(0) end
			end
		end

		res_combo:set_active(cur_idx)
		fillRates(cur_idx)

		function res_combo:on_changed() fillRates(self:get_active()) end

		local apply = Gtk.Button({ label = "Apply" })
		function apply:on_clicked()
			local ri  = res_combo:get_active()
			local rti = rate_combo:get_active()
			local mode = disp.modes[ri + 1]
			if not mode then return end
			local rate = mode.rates[rti + 1]
			local cmd  = "xrandr --output " .. disp.name ..
			             " --mode " .. mode.res ..
			             (rate and (" --rate " .. rate) or "")
			require("awful").spawn.with_shell(cmd)
		end

		grid:attach(Gtk.Label({ label = "Resolution",    halign = Gtk.Align.START }), 0, 0, 1, 1)
		grid:attach(Gtk.Label({ label = "Refresh Rate",  halign = Gtk.Align.START }), 1, 0, 1, 1)
		grid:attach(res_combo,  0, 1, 1, 1)
		grid:attach(rate_combo, 1, 1, 1, 1)
		grid:attach(apply,      2, 1, 1, 1)

		frame:add(grid)
		outer:add(frame)
	end

	-- ── Display power / DPMS ──────────────────────────────────────────────────
	local power_frame = Gtk.Frame({ label = "Display Power" })
	local power_grid  = Gtk.Grid({
		column_spacing = dpi(15),
		row_spacing    = dpi(10),
		margin         = dpi(12),
	})

	local dpms_adj   = Gtk.Adjustment.new(settings.dpms_timeout or 10, 1, 120, 1, 5, 0)
	local timeout_spin = Gtk.SpinButton.new(dpms_adj, 1, 0)

	local dpms_switch = Gtk.Switch({
		active = settings.dpms_enabled ~= false,
		valign = Gtk.Align.CENTER,
	})
	timeout_spin:set_sensitive(settings.dpms_enabled ~= false)

	local function applyDPMS(enabled, mins)
		local awful = require("awful")
		if not enabled then
			awful.spawn.with_shell("xset -dpms s off")
		else
			local s = mins * 60
			awful.spawn.with_shell(string.format("xset dpms %d %d %d s %d", s, s, s, s))
		end
	end

	function dpms_switch:on_state_set(state)
		settings.dpms_enabled = state
		timeout_spin:set_sensitive(state)
		applyDPMS(state, settings.dpms_timeout or 10)
		return false
	end

	function timeout_spin:on_value_changed()
		settings.dpms_timeout = math.floor(self:get_value())
		if settings.dpms_enabled ~= false then
			applyDPMS(true, settings.dpms_timeout)
		end
	end

	local spin_box = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = dpi(6) })
	spin_box:pack_start(timeout_spin, false, false, 0)
	spin_box:pack_start(Gtk.Label({ label = "minutes" }), false, false, 0)

	power_grid:attach(Gtk.Label({ label = "Enable display timeout", halign = Gtk.Align.START, hexpand = true }), 0, 0, 1, 1)
	power_grid:attach(dpms_switch, 1, 0, 1, 1)
	power_grid:attach(Gtk.Label({ label = "Turn off after",         halign = Gtk.Align.START }), 0, 1, 1, 1)
	power_grid:attach(spin_box,    1, 1, 1, 1)
	power_frame:add(power_grid)
	outer:add(power_frame)

	local arandr_btn = Gtk.Button({ label = "More settings (ARandR)", halign = Gtk.Align.START })
	function arandr_btn:on_clicked()
		require("awful").spawn.with_shell("arandr")
	end
	outer:add(arandr_btn)

	local scroll = Gtk.ScrolledWindow()
	scroll:set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
	scroll:add(outer)
	return scroll

end

-- ── Audio tab ─────────────────────────────────────────────────────────────────

local function doAudio()

	local sinks      = getSinks()
	local sources    = getSources()
	local def_sink   = getDefault("pactl get-default-sink")
	local def_source = getDefault("pactl get-default-source")

	local function section(title)
		local lbl = Gtk.Label({ label = title, halign = Gtk.Align.START })
		lbl:get_style_context():add_class("dim-label")
		return lbl
	end

	local function makeSlider(val, lo, hi)
		local adj = Gtk.Adjustment.new(val, lo, hi, 1, 5, 0)
		local s   = Gtk.Scale.new(Gtk.Orientation.HORIZONTAL, adj)
		s.draw_value = true
		s.digits     = 0
		s:set_size_request(dpi(340), -1)
		return s
	end

	local outer = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		spacing     = dpi(14),
		margin      = dpi(20),
		halign      = Gtk.Align.CENTER,
		valign      = Gtk.Align.START,
	})

	-- ── Output ────────────────────────────────────────────────────────────────
	outer:add(section("Output Device"))

	local out_combo = Gtk.ComboBoxText()
	local out_names = {}
	local def_out   = 0
	for i, sink in ipairs(sinks) do
		out_combo:append_text(sink.desc)
		table.insert(out_names, sink.name)
		if sink.name == def_sink then def_out = i - 1 end
	end
	if #sinks == 0 then out_combo:append_text("No output devices found") end
	out_combo:set_active(def_out)
	outer:add(out_combo)

	outer:add(Gtk.Label({ label = "Output Volume", halign = Gtk.Align.START }))
	local init_out_vol = sinks[def_out + 1] and sinks[def_out + 1].volume or 100
	local out_slider   = makeSlider(init_out_vol, 0, 150)
	outer:add(out_slider)

	-- apply output device change
	function out_combo:on_changed()
		local n = out_names[self:get_active() + 1]
		if n then require("awful").spawn.with_shell("pactl set-default-sink " .. n) end
	end
	-- apply output volume change
	function out_slider:on_value_changed()
		local v = math.floor(self:get_value())
		require("awful").spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ " .. v .. "%")
		awesome.emit_signal("widget::volume")
	end

	outer:add(Gtk.Separator({ orientation = Gtk.Orientation.HORIZONTAL }))

	-- ── Input ─────────────────────────────────────────────────────────────────
	outer:add(section("Input Device (Microphone)"))

	local in_combo = Gtk.ComboBoxText()
	local in_names = {}
	local def_in   = 0
	for i, src in ipairs(sources) do
		in_combo:append_text(src.desc)
		table.insert(in_names, src.name)
		if src.name == def_source then def_in = i - 1 end
	end
	if #sources == 0 then in_combo:append_text("No input devices found") end
	in_combo:set_active(def_in)
	outer:add(in_combo)

	outer:add(Gtk.Label({ label = "Microphone Gain", halign = Gtk.Align.START }))
	local init_in_vol = sources[def_in + 1] and sources[def_in + 1].volume or 100
	local in_slider   = makeSlider(init_in_vol, 0, 150)
	outer:add(in_slider)

	function in_combo:on_changed()
		local n = in_names[self:get_active() + 1]
		if n then require("awful").spawn.with_shell("pactl set-default-source " .. n) end
	end
	function in_slider:on_value_changed()
		local v = math.floor(self:get_value())
		require("awful").spawn.with_shell("pactl set-source-volume @DEFAULT_SOURCE@ " .. v .. "%")
	end

	local scroll = Gtk.ScrolledWindow()
	scroll:set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
	scroll:add(outer)
	return scroll

end

-- ── Restart dialog ────────────────────────────────────────────────────────────

local function restartdialog()
	
	local label = Gtk.Label({ label = "Some changes require a restart. Restart now?" })
	local cancelButton = Gtk.Button.new_with_label("No Thanks")
	local restartButton = Gtk.Button.new_with_label("Restart")
	function cancelButton:on_clicked()
		awesome.emit_signal("settings::cancel")
	end
	function restartButton:on_clicked()
		awesome.restart()
	end

	local grid = Gtk.Grid({
		column_spacing = dpi(10),
		halign = Gtk.Align.END,
		margin_end = dpi(20),

		{ label, top_attach = 0, left_attach = 0 },
		{ cancelButton, top_attach = 0, left_attach = 1 },
		{ restartButton, top_attach = 0, left_attach = 2 },
	})

	return grid

end

function app:on_startup()
	local window = Gtk.ApplicationWindow({
		title = appTitle,
		application = self,
		default_width = dpi(640),
		default_height = dpi(440)
	})

	window:set_wmclass("settings", "Settings")

	local stack = Gtk.Stack({
		transition_type = Gtk.StackTransitionType.NONE
	})

	stack:add_titled(doGeneral(), "general", "General")
	stack:add_titled(doTheme(),   "theme",   "Theme")
	stack:add_titled(doPanel(),   "panel",   "Panel")
	stack:add_titled(doDisplay(), "display", "Display")
	stack:add_titled(doAudio(),   "audio",   "Audio")

	local saveButton = Gtk.Button({ label = "Save", halign = Gtk.Align.END, margin_end = dpi(20) })

	local box = Gtk.Box({
		orientation = Gtk.Orientation.VERTICAL,
		margin = dpi(10),
		Gtk.StackSwitcher({ stack = stack, halign = Gtk.Align.CENTER }),
		{ stack, expand = true },
		saveButton
	})

	function saveButton:on_clicked()

		local shouldrestart = false

		local userrestart = {
			"font",
			"fontalt",
			"batt",
		}

		for _, property in ipairs(userrestart) do
			if user[property] ~= settings[property] then
				shouldrestart = true
				break
			end
		end

		writejson(require("gears").filesystem.get_cache_dir() .. "user.json", settings)
		user = copytable(settings)

		writejson(require("gears").filesystem.get_cache_dir() .. "color/" .. settings.color .. "/" .. settings.color .. ".json", color)

		awesome.emit_signal("color::change", color)

		if shouldrestart then
			box:remove(saveButton)
			local dialog = restartdialog()
			box:add(dialog)
			dialog:show_all()
			awesome.connect_signal("settings::cancel", function()
				box:remove(dialog)
				box:add(saveButton)
				saveButton:show_all()
			end)
		end

		require("gears").timer.start_new(0.05, function()
			require("beautiful").init(require("gears").filesystem.get_configuration_dir() .. "theme/theme.lua")
			awesome.emit_signal("live::reload")
			return false
		end)
	end

	box:show_all()
	window:add(box)
end

function app:on_activate()
	self.active_window:present()
end

return app:run()

end)
