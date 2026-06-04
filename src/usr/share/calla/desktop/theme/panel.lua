local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local dock = require("theme.dock")

local function create(s)

local menu = button {
	image = "calla",
	run = function()
		awesome.emit_signal('widget::launcher')
	end
}

local tray = wibox.widget {
	wibox.widget.systray(),
	margins = 0,
	visible = false,
	widget = wibox.container.margin
}

local systraybutton = hovercursor(wibox.widget {
	buttons = { 
		awful.button({}, 1, function()
			awesome.emit_signal("widget::systray")
		end)
	},
	align = "center",
	widget = iconbox({ image = "left" })
})

local systray = wibox.widget {
	{
		{
			systraybutton,
			forced_width = dpi(30),
			widget = wibox.container.background
		},
		tray,
		layout = wibox.layout.fixed.horizontal
	},
	widget = background({ bg = "bgmid" })
}

local closed = true

local systraystore
awesome.connect_signal("widget::systray", function()
	if closed == true then
		tray.visible = true
		tray.margins = dpi(5)
		systraystore = "right"
		closed = false
	else
		tray.visible = false
		tray.margins = 0
		systraystore = "left"
		closed = true
	end
	systraybutton.image = createicon(systraystore)
end)

local media = wibox.widget {
	{
		{
			{
				id = "icon",
				widget = iconbox({ image = "musicon" })
			},
			{
				id = "title",
				widget = wibox.widget.textbox("Not Playing - No Artist")
			},
			spacing = dpi(4),
			layout = wibox.layout.fixed.horizontal
		},
		left = dpi(8),
		right = dpi(8),
		widget = wibox.container.margin
	},
	widget = background({ bg = "bgmid", fg = "fg" })
}

local playerstore
awesome.connect_signal("signal::playerctl", function(title, album, artist, cover, status)
	if string.len(title .. " - " .. artist) > 50 then
		media:get_children_by_id("title")[1].text = title
	else
		media:get_children_by_id("title")[1].text = title .. " - " .. artist
	end
	if title == "Not Playing" then
		state = false
		playerstore = "musicoff"
	else
		state = true
		playerstore = "musicon"
	end
	media:get_children_by_id("icon")[1].image = createicon(playerstore)
end)

local volumepercent = wibox.widget {
	text = "N/A",
	widget = wibox.widget.textbox
}

local volumeicon = iconbox({ image = "volumemute" })

local volume = wibox.widget {
	{
		{
			volumeicon,
			volumepercent,
			spacing = dpi(4),
			layout = wibox.layout.fixed.horizontal
		},
		left = dpi(8),
		right = dpi(8),
		widget = wibox.container.margin
	},
	widget = background({ bg = "bgmid", fg = "fg" })
}

local volumestore
awesome.connect_signal("signal::volume", function(volume, mute)
	if mute then
		volumepercent.text = "Muted"
		volumestore = "volumemute"
	else
		volumepercent.text = tostring(volume) .. "%"
		if volume > 100 then
			volumestore = "volumewarn"
		elseif volume >= 50 then
			volumestore = "volume100"
		elseif volume >= 25 then
			volumestore = "volume50"
		elseif volume > 0 then
			volumestore = "volume25"
		elseif volume == 0 then
			volumestore = "volume0"
		end
	end
	volumeicon.image = createicon(volumestore)
end)

local batterypercent = wibox.widget {
	text = "N/A",
	widget = wibox.widget.textbox
}

local batteryicon = iconbox({ image = "batterynone" })

local batterybolt = wibox.widget {
	text    = "⚡",
	visible = false,
	widget  = wibox.widget.textbox,
}

local battery = wibox.widget {
	{
		{
			batteryicon,
			batterybolt,
			batterypercent,
			spacing = dpi(4),
			layout = wibox.layout.fixed.horizontal
		},
		left = dpi(8),
		right = dpi(8),
		widget = wibox.container.margin
	},
	widget = background({ bg = "bgmid", fg = "fg" })
}

local batterystore
if user.batt ~= nil then
	awful.widget.watch(
		"cat /sys/class/power_supply/" .. user.batt .. "/capacity && " ..
		"cat /sys/class/power_supply/" .. user.batt .. "/status",
		15,
		function(widget, stdout)
			local lines = {}
			for line in stdout:gmatch("[^\n]+") do
				table.insert(lines, line)
			end
			local percent = tonumber(lines[1])
			local status  = lines[2] or ""
			if percent == nil then return end
			batterypercent.text    = percent .. "%"
			batterybolt.visible    = (status == "Charging")
			if percent > 80 then
				batterystore = "battery100"
			elseif percent > 50 then
				batterystore = "battery80"
			elseif percent > 25 then
				batterystore = "battery50"
			elseif percent > 10 then
				batterystore = "battery25"
			elseif percent > 5 then
				batterystore = "battery10"
			else
				batterystore = "battery0"
			end
			batteryicon.image = createicon(batterystore)
		end
	)
end

local cheatsheet = button({
	image = "keyboard",
	run   = function() awesome.emit_signal("widget::cheatsheet") end,
})

local wifi_icon_w = iconbox({ image = "wifioff" })
local wifi_ssid_w = wibox.widget { text = "WiFi", widget = wibox.widget.textbox }
local wifistore   = "wifioff"

local wifi_widget = hovercursor(wibox.widget {
	{
		{
			wifi_icon_w,
			wifi_ssid_w,
			spacing = dpi(4),
			layout  = wibox.layout.fixed.horizontal,
		},
		left = dpi(8), right = dpi(8),
		widget = wibox.container.margin,
	},
	buttons = { awful.button({}, 1, function() awesome.emit_signal("widget::wifi") end) },
	widget  = background({ bg = "bgmid", fg = "fg" }),
})

local function updateWifiPanel()
	awful.spawn.easy_async_with_shell(
		-- line 1: wifi radio state ("enabled" / "disabled")
		-- line 2: active wifi SSID if any ("yes:SSID")
		-- line 3: ethernet connected device if any ("ethernet:connected:…")
		"nmcli radio wifi 2>/dev/null; " ..
		"nmcli -t -f ACTIVE,SSID dev wifi list --rescan no 2>/dev/null | grep -m1 '^yes:'; " ..
		"nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -m1 '^ethernet:connected'",
		function(out)
			local radio    = out:match("enabled")
			local wifi_ssid = out:match("yes:(.+)")
			local ethernet = out:match("ethernet:connected")

			if wifi_ssid then
				wifi_ssid = wifi_ssid:match("^%s*(.-)%s*$")
				wifi_ssid_w.text = "Connected"
				wifistore = "wifion"
			elseif ethernet then
				wifi_ssid_w.text = "Ethernet"
				wifistore = "wifion"
			elseif radio then
				wifi_ssid_w.text = "Disconnected"
				wifistore = "wifinotconnected"
			else
				wifi_ssid_w.text = "WiFi Off"
				wifistore = "wifioff"
			end
			wifi_icon_w.image = createicon(wifistore)
		end
	)
end

updateWifiPanel()
gears.timer { timeout = 10, autostart = true, callback = updateWifiPanel }

local clock = wibox.widget {
	{
		{
			iconbox({ image = "clock" }),
			wibox.widget.textclock('%I:%M %p'),
			spacing = dpi(4),
			layout = wibox.layout.fixed.horizontal
		},
		left = dpi(8),
		right = dpi(8),
		widget = wibox.container.margin
	},
	widget = background({ bg = "bgmid", fg = "fg" })
}

local taglist = awful.widget.taglist {
	screen = s,
	filter = awful.widget.taglist.filter.selected,
	style = {
		shape = function(cr, width, height)
					gears.shape.rounded_rect(cr, width, height, dpi(10))
				end
	},
	widget_template = {
		{
			{
				{
					wibox.widget.textbox("Workspace "),
					widget = background({ fg = "fg" })
				},
				{
					id = "text_role",
					widget = wibox.widget.textbox
				},
				layout = wibox.layout.fixed.horizontal
			},
			left = dpi(8),
			right = dpi(8),
			widget = wibox.container.margin
		},
		id = "background_role",
		widget = wibox.container.background,
		create_callback = function(self)
			hovercursor(self)
		end
	},
	buttons = {
		awful.button({ }, 1, function()
			awesome.emit_signal("widget::preview")
		end),
		awful.button({ }, 4, function(t)
			awful.tag.viewnext(t.screen)
		end),
		awful.button({ }, 5, function(t)
			awful.tag.viewprev(t.screen)
		end)
	}
}

local layouts = awful.widget.layoutbox {
	screen  = s,
	buttons = {
		awful.button({ }, 1, function () awful.layout.inc( 1) end),
		awful.button({ }, 3, function () awful.layout.inc(-1) end),
	}
}

local layoutbox = hovercursor(wibox.widget {
	{
		layouts,
		margins = dpi(5),
		widget = wibox.container.margin
	},
	widget = background({ bg = "bgmid" })
})

local function applyPanelVisibility()
	menu.visible        = user.panel_menu        ~= false
	taglist.visible     = user.panel_taglist     ~= false
	layoutbox.visible   = user.panel_layouts     ~= false
	systray.visible     = user.panel_systray     ~= false
	media.visible       = user.panel_media       ~= false
	volume.visible      = user.panel_volume      ~= false
	battery.visible     = user.panel_battery     ~= false
	clock.visible       = user.panel_clock       ~= false
	dock.visible        = user.panel_dock        ~= false
	cheatsheet.visible   = user.panel_cheatsheet  ~= false
	wifi_widget.visible  = user.panel_wifi        ~= false
end

applyPanelVisibility()

awesome.connect_signal("live::reload", function()
	if systraystore then systraybutton.image = createicon(systraystore) end
	if playerstore  then media:get_children_by_id("icon")[1].image = createicon(playerstore) end
	if volumestore  then volumeicon.image = createicon(volumestore) end
	if batterystore then batteryicon.image = createicon(batterystore) end
	if wifistore    then wifi_icon_w.image = createicon(wifistore) end
	taglist._do_taglist_update_now()
	tag.emit_signal("property::layout", awful.screen.focused().selected_tag)
	applyPanelVisibility()
end)

return wibox.widget {
	{
		{
			{
				menu,
				taglist,
				layoutbox,
				spacing = dpi(5),
				layout = wibox.layout.fixed.horizontal
			},
			nil,
			{
				systray,
				cheatsheet,
				wifi_widget,
				hovercursor(wibox.widget {
					media,
					volume,
					battery,
					clock,
					buttons = {
						awful.button({ }, 1, function()
							awesome.emit_signal("widget::control")
						end)
					},
					spacing = dpi(5),
					layout = wibox.layout.fixed.horizontal
				}),
				spacing = dpi(5),
				layout = wibox.layout.fixed.horizontal
			},
			layout = wibox.layout.align.horizontal
		},
		{
			dock,
			halign = "center",
			widget = wibox.container.place
		},
		layout = wibox.layout.stack
	},
	forced_height = dpi(50),
	margins = dpi(10),
	widget = wibox.container.margin
}

end

return create
