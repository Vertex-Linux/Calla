local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local iconpath = require("gears").filesystem.get_configuration_dir() .. "theme/icons/"

client.connect_signal("request::titlebars", function(c)

	-- Button actions

    local buttons = {
        awful.button({ }, 1, function()
            c:activate { context = "titlebar", action = "mouse_move"  }
        end),
        awful.button({ }, 3, function()
            c:activate { context = "titlebar", action = "mouse_resize"}
        end),
    }

	local resize_buttons = {
		awful.button({ }, 1, function()
			c:activate { context = "titlebar", action = "mouse_resize" }
		end),
	}

	-- Widgets

	local icon = wibox.widget {
		{
			awful.titlebar.widget.iconwidget(c), 
			buttons = buttons,
			margins = dpi(5),
			widget = wibox.container.margin
		},
		widget = background({ bg = "bgmid" })
	}

	local title = wibox.widget {
		{
			awful.titlebar.widget.titlewidget(c), 
			buttons = buttons,
			top = dpi(5),
			bottom = dpi(5),
			left = dpi(10),
			right = dpi(10),
			widget = wibox.container.margin
		},
		bg = beautiful.bgmid,
		widget = background({ bg = "bgmid" })
	}

	local function titlebutton(action, run)
		local img = gears.color.recolor_image(iconpath .. action .. ".png", beautiful.bgmid)
		local button = wibox.widget {
			{
				id = "image",
				image = gears.color.recolor_image(img, beautiful.fg.."40"),
				widget = wibox.widget.imagebox
			},
			buttons = {
				awful.button({}, 1, run)
			},
			widget = wibox.container.background
		}

		local function update()
			local img = gears.color.recolor_image(iconpath .. action .. ".png", beautiful.bgmid)
			if client.focus == c then
				button:get_children_by_id("image")[1].image = gears.color.recolor_image(img, beautiful.fg)
			else
				button:get_children_by_id("image")[1].image = gears.color.recolor_image(img, beautiful.fg.."40")
			end
		end

		client.connect_signal("focus", update)
		client.connect_signal("unfocus", update)
		awesome.connect_signal("live::reload", update)

		return button
	end

	local titlebuttons = wibox.widget {
		{
			{
				titlebutton("minimize", function() c.minimized = true end),
				titlebutton("maximize", function() c.maximized = not c.maximized end),
				titlebutton("close", function() c:kill() end),
				spacing = dpi(10),
				widget = wibox.layout.fixed.horizontal
			},
			margins = dpi(10),
			widget = wibox.container.margin
		},
		widget = background({ bg = "bgmid" })
	}

	-- Titlebar

    local titlebar   = awful.titlebar(c, { size = dpi(40), position = "top"    })
	local handle     = awful.titlebar(c, { size = dpi(8),  position = "bottom" })
	local leftedge   = awful.titlebar(c, { size = dpi(4),  position = "left"   })
	local rightedge  = awful.titlebar(c, { size = dpi(4),  position = "right"  })

	titlebar:setup {
		{
			{
				icon,
				title,
				spacing = dpi(5),
				layout = wibox.layout.fixed.horizontal
			},
			{
				buttons = buttons,
				widget = wibox.container.background
			},
			titlebuttons,
			layout = wibox.layout.align.horizontal
		},
		margins = dpi(5),
		widget = wibox.container.margin
	}

	-- Bottom, left, right edges: left-click drag to resize from any edge or corner
	handle:setup {
		buttons = resize_buttons,
		widget  = live(wibox.container.background, { bg = "bg" })
	}
	leftedge:setup {
		buttons = resize_buttons,
		widget  = live(wibox.container.background, { bg = "bg" })
	}
	rightedge:setup {
		buttons = resize_buttons,
		widget  = live(wibox.container.background, { bg = "bg" })
	}

	awesome.connect_signal("live::reload", function()
		titlebar:set_bg(beautiful.bg)
		titlebar:set_fg(beautiful.fg)
		handle:set_bg(beautiful.bg)
		leftedge:set_bg(beautiful.bg)
		rightedge:set_bg(beautiful.bg)
	end)

end)
