local awful    = require("awful")
local wibox    = require("wibox")
local gears    = require("gears")
local beautiful = require("beautiful")
local dpi      = beautiful.xresources.apply_dpi

-- ── Data helpers ──────────────────────────────────────────────────────────────

local function getNetworks(callback)
    awful.spawn.easy_async_with_shell(
        "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null",
        function(stdout)
            local nets, seen = {}, {}
            for line in stdout:gmatch("[^\n]+") do
                -- Format: *:SSID:signal:security  (or space for not-in-use)
                local use, ssid, sig, sec = line:match("^([^:]):(.+):(%d+):(.-)%s*$")
                if ssid and ssid ~= "" and not seen[ssid] then
                    seen[ssid] = true
                    table.insert(nets, {
                        ssid    = ssid,
                        signal  = tonumber(sig) or 0,
                        secured = sec ~= "" and sec ~= "--",
                        active  = use == "*",
                    })
                end
            end
            table.sort(nets, function(a, b) return a.signal > b.signal end)
            callback(nets)
        end
    )
end

local function getWifiEnabled(callback)
    awful.spawn.easy_async_with_shell(
        "nmcli radio wifi 2>/dev/null",
        function(out) callback(out:match("enabled") ~= nil) end
    )
end

-- GTK password dialog (no Application wrapper needed — GTK is already initialised)
local function askPassword(ssid, callback)
    local lgi = require("lgi")
    local Gtk = lgi.require("Gtk", "3.0")

    local dlg = Gtk.Dialog({ title = "WiFi Password", modal = true })
    dlg:add_button("Cancel",  Gtk.ResponseType.CANCEL)
    dlg:add_button("Connect", Gtk.ResponseType.OK)
    dlg:set_default_response(Gtk.ResponseType.OK)

    local box   = dlg:get_content_area()
    box.margin  = dpi(14)
    box.spacing = dpi(8)

    box:add(Gtk.Label({ label = 'Password for "' .. ssid .. '"', halign = Gtk.Align.START }))
    local entry = Gtk.Entry({
        visibility        = false,
        placeholder_text  = "Password",
        activates_default = true,
    })
    box:add(entry)
    dlg:show_all()

    local resp = dlg:run()
    local pwd  = entry.text
    dlg:destroy()
    if resp == Gtk.ResponseType.OK and pwd ~= "" then callback(pwd) end
end

local function esc(s) return s:gsub('"', '\\"') end

-- ── Popup ─────────────────────────────────────────────────────────────────────

local net_container    = wibox.container.background()
local wifi_toggle_icon = iconbox({ image = "wifion" })

local function rebuild()
    getNetworks(function(nets)
        local list = wibox.layout.fixed.vertical()
        list.spacing = dpi(2)

        if #nets == 0 then
            list:add(wibox.widget {
                { text = "No networks found", halign = "center", widget = wibox.widget.textbox },
                margins = dpi(16),
                widget  = wibox.container.margin,
            })
        end

        for i, net in ipairs(nets) do
            if i > 10 then break end

            local ssid_c = net.ssid
            local sec_c  = net.secured
            local act_c  = net.active
            local bg_base = act_c and (beautiful.fg .. "18") or "transparent"

            local dot = wibox.widget {
                markup = act_c
                    and ('<span foreground="' .. beautiful.fg .. '">⏺</span>')
                    or  ('<span foreground="' .. beautiful.fg .. '30">○</span>'),
                forced_width = dpi(14),
                widget = wibox.widget.textbox,
            }
            local ssid_w = wibox.widget {
                text         = ssid_c,
                forced_width = dpi(148),
                widget       = wibox.widget.textbox,
            }
            local lock_w = sec_c
                and iconbox({ image = "lock", size = dpi(11) })
                or  wibox.widget { forced_width = dpi(12), widget = wibox.container.background }
            local sig_w = wibox.widget {
                text         = net.signal .. "%",
                align        = "right",
                forced_width = dpi(36),
                widget       = wibox.widget.textbox,
            }

            local row = wibox.widget {
                {
                    {
                        dot, ssid_w, lock_w, sig_w,
                        spacing = dpi(5),
                        layout  = wibox.layout.fixed.horizontal,
                    },
                    top = dpi(7), bottom = dpi(7),
                    left = dpi(10), right = dpi(10),
                    widget = wibox.container.margin,
                },
                bg     = bg_base,
                shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(5)) end,
                widget = wibox.container.background,
            }

            row.buttons = { awful.button({}, 1, function()
                if act_c then
                    awful.spawn.with_shell('nmcli con down id "' .. esc(ssid_c) .. '" 2>/dev/null')
                    gears.timer.start_new(2, function() rebuild(); return false end)
                    return
                end
                awful.spawn.easy_async_with_shell(
                    'nmcli con show "' .. esc(ssid_c) .. '" 2>/dev/null | wc -l',
                    function(out)
                        local saved = (tonumber(out) or 0) > 1
                        if saved then
                            awful.spawn.with_shell('nmcli con up id "' .. esc(ssid_c) .. '"')
                            gears.timer.start_new(3, function() rebuild(); return false end)
                        elseif sec_c then
                            askPassword(ssid_c, function(pwd)
                                awful.spawn.with_shell(
                                    'nmcli dev wifi connect "' .. esc(ssid_c) ..
                                    '" password "' .. esc(pwd) .. '"')
                                gears.timer.start_new(4, function() rebuild(); return false end)
                            end)
                        else
                            awful.spawn.with_shell('nmcli dev wifi connect "' .. esc(ssid_c) .. '"')
                            gears.timer.start_new(3, function() rebuild(); return false end)
                        end
                    end
                )
            end) }

            hovercursor(row)
            row:connect_signal("mouse::enter", function(w) w.bg = beautiful.fg .. "25" end)
            row:connect_signal("mouse::leave", function(w) w.bg = bg_base end)

            list:add(row)
        end

        net_container:set_widget(list)
    end)
end

-- Header bar: title, WiFi toggle, rescan button
local toggle_btn = hovercursor(wibox.widget {
    {
        wifi_toggle_icon,
        margins = dpi(4),
        widget  = wibox.container.margin,
    },
    forced_width  = dpi(26),
    forced_height = dpi(26),
    buttons = { awful.button({}, 1, function()
        getWifiEnabled(function(enabled)
            if enabled then
                awful.spawn.with_shell("nmcli radio wifi off")
                wifi_toggle_icon.image = createicon("wifioff")
            else
                awful.spawn.with_shell("nmcli radio wifi on")
                wifi_toggle_icon.image = createicon("wifion")
                gears.timer.start_new(2, function() rebuild(); return false end)
            end
        end)
    end) },
    widget = background({ bg = "bgmid" }),
})

local rescan_btn = hovercursor(button {
    image = "restart",
    size  = dpi(26),
    run   = function()
        awful.spawn.with_shell("nmcli dev wifi rescan 2>/dev/null &")
        gears.timer.start_new(2, function() rebuild(); return false end)
    end,
})

local header = wibox.widget {
    {
        wibox.widget { text = "WiFi", font = user.fontalt, widget = wibox.widget.textbox },
        nil,
        {
            toggle_btn,
            rescan_btn,
            spacing = dpi(4),
            layout  = wibox.layout.fixed.horizontal,
        },
        layout = wibox.layout.align.horizontal,
    },
    margins = dpi(10),
    widget  = wibox.container.margin,
}

-- Popup wibox
local wifibox = wibox {
    width   = dpi(280),
    height  = dpi(420),
    ontop   = true,
    visible = false,
    bg      = beautiful.bg_normal,
    widget  = {
        {
            {
                header,
                { widget = wibox.widget.separator },
                {
                    net_container,
                    margins = dpi(6),
                    widget  = wibox.container.margin,
                },
                layout = wibox.layout.fixed.vertical,
            },
            margins = dpi(4),
            widget  = wibox.container.margin,
        },
        widget = background({ bg = "bg" }),
    }
}

local open = false

awesome.connect_signal("widget::wifi", function()
    open = not open
    if open then
        -- Close control panel if open
        awesome.emit_signal("widget::control::close")
        awful.placement.bottom_right(wifibox, {
            margins = { bottom = dpi(60), right = dpi(20) },
            parent  = awful.screen.focused(),
        })
        rebuild()
    end
    wifibox.visible = open
end)

awesome.connect_signal("widget::wifi::close", function()
    open = false
    wifibox.visible = false
end)

awesome.connect_signal("live::reload", function()
    wifibox.bg = beautiful.bg_normal
end)
