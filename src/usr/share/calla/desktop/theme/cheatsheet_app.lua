local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local dpi = require("beautiful").xresources.apply_dpi

local function modstr(mods)
    local map = { Mod4 = "Super", Mod1 = "Alt", Control = "Ctrl", Shift = "Shift" }
    local parts = {}
    for _, m in ipairs(mods) do
        table.insert(parts, map[m] or m)
    end
    return table.concat(parts, " + ")
end

local function keystr(mods, key)
    local m = modstr(mods)
    if m ~= "" then return m .. " + " .. key end
    return key
end

local mod = user.mod

local groups = {
    {
        name = "Awesome",
        binds = {
            { mods = { mod },           key = "Space",  desc = "Control center"    },
            { mods = { mod },           key = "d",      desc = "App launcher"      },
            { mods = { mod },           key = "k",      desc = "Calendar"          },
            { mods = { mod, "Shift" },  key = "c",      desc = "Settings"          },
            { mods = { mod },           key = "l",      desc = "Lock screen"       },
            { mods = { mod },           key = "F1",     desc = "Help popup"        },
            { mods = { mod },           key = "z",      desc = "Next layout"       },
            { mods = { mod },           key = "Tab",    desc = "Next window"       },
            { mods = { mod, "Shift" },  key = "Tab",    desc = "Previous window"   },
            { mods = { mod, "Shift" },  key = "r",      desc = "Reload awesome"    },
        },
    },
    {
        name = "Client",
        binds = {
            { mods = { mod }, key = "q", desc = "Close window"      },
            { mods = { mod }, key = "f", desc = "Toggle fullscreen" },
            { mods = { mod }, key = "m", desc = "Toggle maximize"   },
            { mods = { mod }, key = "s", desc = "Toggle floating"   },
            { mods = { mod }, key = "n", desc = "Minimize"          },
            { mods = { mod }, key = "c", desc = "Center window"     },
            { mods = { mod }, key = "b", desc = "Toggle sticky"     },
        },
    },
    {
        name = "Programs",
        binds = {
            { mods = { mod }, key = "Return", desc = "Terminal"       },
            { mods = { mod }, key = "e",      desc = "File manager"   },
            { mods = { mod }, key = "w",      desc = "Firefox"        },
            { mods = { mod }, key = "k",      desc = "Calendar"        },
        },
    },
    {
        name = "Workspaces",
        binds = {
            { mods = { mod },           key = "1 – 9", desc = "Switch to workspace"       },
            { mods = { mod, "Control"}, key = "1 – 9", desc = "Move window to workspace"  },
            { mods = { mod, "Shift" },  key = "1 – 9", desc = "Move & follow to workspace"},
        },
    },
    {
        name = "Screenshot",
        binds = {
            { mods = { mod },           key = "Print", desc = "Area screenshot"          },
            { mods = { mod, "Shift" },  key = "Print", desc = "Full screenshot"          },
            { mods = { mod, "Control"}, key = "Print", desc = "Full screenshot (5s delay)"},
        },
    },
    {
        name = "Media & System",
        binds = {
            { mods = {}, key = "XF86AudioRaiseVolume",  desc = "Volume up"       },
            { mods = {}, key = "XF86AudioLowerVolume",  desc = "Volume down"     },
            { mods = {}, key = "XF86AudioMute",         desc = "Mute"            },
            { mods = {}, key = "XF86MonBrightnessUp",   desc = "Brightness up"   },
            { mods = {}, key = "XF86MonBrightnessDown", desc = "Brightness down" },
        },
    },
}

awesome.connect_signal("widget::cheatsheet", function()

    local app = Gtk.Application({ application_id = "io.github.stardust-kyun.calla.cheatsheet" })

    function app:on_startup()
        local win = Gtk.ApplicationWindow({
            title          = "Keybind Cheatsheet",
            application    = self,
            default_width  = dpi(760),
            default_height = dpi(520),
        })
        win:set_wmclass("cheatsheet", "Cheatsheet")

        local scroll = Gtk.ScrolledWindow()
        scroll:set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        local flow = Gtk.FlowBox({
            margin              = dpi(16),
            column_spacing      = dpi(20),
            row_spacing         = dpi(20),
            min_children_per_line = 2,
            max_children_per_line = 3,
            selection_mode      = Gtk.SelectionMode.NONE,
            homogeneous         = false,
        })

        for _, group in ipairs(groups) do
            local frame = Gtk.Frame({ label = group.name })
            local vbox  = Gtk.Box({
                orientation = Gtk.Orientation.VERTICAL,
                spacing     = dpi(4),
                margin      = dpi(8),
            })

            for _, bind in ipairs(group.binds) do
                local row   = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = dpi(8) })
                local chord = keystr(bind.mods, bind.key)

                local key_lbl = Gtk.Label({
                    label       = chord,
                    halign      = Gtk.Align.START,
                    width_chars = 26,
                    xalign      = 0,
                })
                key_lbl:get_style_context():add_class("monospace")

                local desc_lbl = Gtk.Label({
                    label  = bind.desc,
                    halign = Gtk.Align.START,
                    xalign = 0,
                })

                row:pack_start(key_lbl,  false, false, 0)
                row:pack_start(desc_lbl, true,  true,  0)
                vbox:add(row)
            end

            frame:add(vbox)
            flow:add(frame)
        end

        scroll:add(flow)
        scroll:show_all()
        win:add(scroll)
    end

    function app:on_activate()
        self.active_window:present()
    end

    return app:run()
end)
