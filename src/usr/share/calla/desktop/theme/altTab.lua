local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

local mod = user.mod

local clients = {}
local index = 1

local itemlist = wibox.widget {
	spacing = dpi(10),
	layout = wibox.layout.fixed.horizontal
}

local altTabBox = wibox {
	ontop = true,
	visible = false,
	bg = beautiful.bg_normal,
	widget = {
		{
			itemlist,
			margins = dpi(10),
			widget = wibox.container.margin
		},
		widget = background({ bg = "bg" })
	}
}

local function createitem(c, selected)
	local imagebox = wibox.widget {
		resize = true,
		forced_height = dpi(48),
		forced_width = dpi(48),
		widget = wibox.widget.imagebox
	}
	if not pcall(function() imagebox.image = gears.surface.load(c.icon) end) or not imagebox.image then
		imagebox.image = beautiful.calla
	end

	local title = wibox.widget {
		text = c.name or "",
		forced_width = dpi(110),
		align = "center",
		widget = wibox.widget.textbox
	}

	return wibox.widget {
		{
			{
				imagebox,
				title,
				spacing = dpi(6),
				layout = wibox.layout.fixed.vertical
			},
			margins = dpi(10),
			widget = wibox.container.margin
		},
		widget = background({ bg = selected and "bgmid" or "bg" })
	}
end

local function rebuild()
	itemlist:reset()
	for i, c in ipairs(clients) do
		itemlist:add(createitem(c, i == index))
	end
end

local function buildClients()
	clients = {}
	local scr = awful.screen.focused()
	for _, c in ipairs(awful.client.focus.history.list) do
		if c.screen == scr and c:isvisible() then
			table.insert(clients, c)
		end
	end
end

local function cycle(dir)
	if #clients == 0 then return end
	index = index + dir
	if index > #clients then index = 1 end
	if index < 1 then index = #clients end
	rebuild()
end

local altGrabber

altGrabber = awful.keygrabber {
	keybindings = {
		awful.key { modifiers = { mod }, key = "Tab", on_press = function() cycle(1) end },
		awful.key { modifiers = { mod, "Shift" }, key = "Tab", on_press = function() cycle(-1) end },
		awful.key { modifiers = {}, key = "Escape", on_press = function()
			index = 1
			altGrabber:stop()
		end },
	},
	stop_key = mod,
	stop_event = "release",
	export_keybindings = true,
	start_callback = function()
		buildClients()
		if #clients < 2 then
			clients = {}
			altGrabber:stop()
			return
		end
		index = 2
		rebuild()

		local geo = awful.screen.focused().geometry
		altTabBox.width = math.min(dpi(130) * #clients + dpi(20), geo.width - dpi(80))
		altTabBox.height = dpi(110)
		awful.placement.centered(altTabBox, { parent = awful.screen.focused() })
		altTabBox.visible = true
	end,
	stop_callback = function()
		altTabBox.visible = false
		local c = clients[index]
		clients = {}
		if c and c.valid then
			c:activate({ raise = true, context = "altTab" })
		end
	end,
}

awesome.connect_signal("live::reload", function()
	altTabBox.bg = beautiful.bg_normal
end)
