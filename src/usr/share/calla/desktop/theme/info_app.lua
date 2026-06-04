local lgi       = require("lgi")
local Gtk       = lgi.require("Gtk", "3.0")
local GdkPixbuf = lgi.require("GdkPixbuf", "2.0")
local gears     = require("gears")
local dpi       = require("beautiful").xresources.apply_dpi

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end

local function exec(cmd)
    local f = io.popen(cmd .. " 2>/dev/null")
    if not f then return "N/A" end
    local out = trim(f:read("*l") or ""); f:close()
    return out ~= "" and out or "N/A"
end

local function readOSRelease()
    local data = {}
    local f = io.open("/etc/os-release", "r")
    if not f then return data end
    for line in f:lines() do
        local k, v = line:match('^([%w_]+)="?(.-)"?$')
        if k then data[k] = v end
    end
    f:close()
    return data
end

local function getMemory()
    local total, avail = nil, nil
    local f = io.open("/proc/meminfo", "r")
    if not f then return "N/A" end
    for line in f:lines() do
        local k, v = line:match("^(%w+):%s+(%d+)")
        if k == "MemTotal"     then total = tonumber(v) end
        if k == "MemAvailable" then avail = tonumber(v) end
    end
    f:close()
    if not total then return "N/A" end
    local used = total - (avail or 0)
    local function gib(kb) return string.format("%.1f GiB", kb / 1048576) end
    return gib(used) .. " / " .. gib(total)
end

local function getUptime()
    local f = io.open("/proc/uptime", "r")
    if not f then return "N/A" end
    local line = f:read("*l"); f:close()
    local secs = math.floor(tonumber(line:match("^([%d%.]+)") or 0))
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    if d > 0 then return string.format("%dd %dh %dm", d, h, m)
    elseif h > 0 then return string.format("%dh %dm", h, m)
    else return string.format("%dm", m) end
end

local function loadLogo(os_data, size)
    local id = (os_data.ID or "linux"):lower()

    -- 1. Try icon name from os-release LOGO field via GTK icon theme
    local logo_name = os_data.LOGO
    if logo_name then
        local theme = Gtk.IconTheme.get_default()
        if theme:has_icon(logo_name) then
            local info = theme:lookup_icon(logo_name, size, {})
            if info then
                local ok, pb = pcall(function() return info:load_icon() end)
                if ok and pb then return Gtk.Image.new_from_pixbuf(pb) end
            end
        end
    end

    -- 2. Try common pixmap file paths
    local paths = {
        "/usr/share/pixmaps/" .. id .. "-logo.png",
        "/usr/share/pixmaps/" .. id .. "-logo.svg",
        "/usr/share/pixmaps/" .. id .. ".png",
        "/usr/share/logos/"   .. id .. ".png",
    }
    for _, p in ipairs(paths) do
        local fh = io.open(p, "r")
        if fh then
            fh:close()
            local ok, pb = pcall(function()
                return GdkPixbuf.Pixbuf.new_from_file_at_scale(p, size, size, true)
            end)
            if ok and pb then return Gtk.Image.new_from_pixbuf(pb) end
        end
    end

    -- 3. Calla logo fallback — white for dark mode, coloured for light mode
    local bg = require("beautiful").bg or "#000000"
    local bh = bg:gsub("^#", "")
    local r  = tonumber(bh:sub(1,2), 16) / 255
    local g  = tonumber(bh:sub(3,4), 16) / 255
    local b  = tonumber(bh:sub(5,6), 16) / 255
    local light = (0.2126*r + 0.7152*g + 0.0722*b) > 0.4
    local fallback = gears.filesystem.get_configuration_dir() ..
                     "theme/icons/" .. (light and "calla.png" or "calla-white.png")
    local ok, pb = pcall(function()
        return GdkPixbuf.Pixbuf.new_from_file_at_scale(fallback, size, size, true)
    end)
    if ok and pb then return Gtk.Image.new_from_pixbuf(pb) end

    -- 4. Generic system icon
    local img = Gtk.Image.new_from_icon_name("computer", Gtk.IconSize.INVALID)
    img.pixel_size = size
    return img
end

-- ── Signal handler ────────────────────────────────────────────────────────────

awesome.connect_signal("widget::info", function()

    local app = Gtk.Application({ application_id = "io.github.stardust-kyun.calla.info" })

    function app:on_startup()
        local os_data = readOSRelease()
        local os_name = os_data.PRETTY_NAME or os_data.NAME or "Linux"

        local win = Gtk.ApplicationWindow({
            title         = "System Information",
            application   = self,
            default_width = dpi(500),
            resizable     = true,
        })
        win:set_wmclass("info", "Info")

        local scroll = Gtk.ScrolledWindow()
        scroll:set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        local outer = Gtk.Box({
            orientation = Gtk.Orientation.VERTICAL,
            spacing     = dpi(14),
            margin      = dpi(22),
        })

        -- ── Logo ─────────────────────────────────────────────────────────────
        local logo_img = loadLogo(os_data, 96)
        logo_img.halign   = Gtk.Align.CENTER
        logo_img.margin_top = dpi(4)
        outer:add(logo_img)

        -- ── OS name ───────────────────────────────────────────────────────────
        local name_lbl = Gtk.Label({ halign = Gtk.Align.CENTER })
        name_lbl:set_markup(
            '<span font_size="x-large" font_weight="bold">' ..
            os_name:gsub("&","&amp;"):gsub("<","&lt;") ..
            '</span>'
        )
        outer:add(name_lbl)

        outer:add(Gtk.Separator({ orientation = Gtk.Orientation.HORIZONTAL }))

        -- ── Section builder ───────────────────────────────────────────────────
        local function section(title, rows)
            local vbox = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL, spacing = dpi(5) })

            local hdr = Gtk.Label({ halign = Gtk.Align.START })
            hdr:set_markup('<span font_weight="bold">' .. title .. '</span>')
            hdr:get_style_context():add_class("dim-label")
            vbox:add(hdr)

            local grid = Gtk.Grid({ column_spacing = dpi(16), row_spacing = dpi(3) })
            for i, row in ipairs(rows) do
                local k = Gtk.Label({
                    label       = row[1],
                    halign      = Gtk.Align.START,
                    xalign      = 0,
                    width_chars = 14,
                })
                k:get_style_context():add_class("dim-label")

                local v = Gtk.Label({
                    label      = row[2],
                    halign     = Gtk.Align.START,
                    xalign     = 0,
                    selectable = true,
                    wrap       = true,
                    max_width_chars = 42,
                })
                grid:attach(k, 0, i - 1, 1, 1)
                grid:attach(v, 1, i - 1, 1, 1)
            end
            vbox:add(grid)
            return vbox
        end

        -- ── Gather system data ────────────────────────────────────────────────

        local cpu = exec("grep -m1 'model name' /proc/cpuinfo | cut -d: -f2")
        local cores = exec("nproc")
        if cores ~= "N/A" then
            cpu = cpu .. "  (" .. cores .. " cores)"
        end

        local gpu_raw = exec("lspci | grep -iE 'VGA|3D|Display' | head -1")
        local gpu = gpu_raw:match(":%s+(.+)$") or "N/A"
        gpu = gpu:gsub("%s*%(rev %w+%)", "")

        local disk = exec("df -h / | awk 'NR==2 {print $3 \" used / \" $2}'")

        local res = exec("xrandr | grep ' connected primary' | grep -oE '[0-9]+x[0-9]+' | head -1")
        if res == "N/A" then
            res = exec("xrandr | grep ' connected' | grep -oE '[0-9]+x[0-9]+' | head -1")
        end

        local kernel   = exec("uname -r")
        local hostname = exec("cat /etc/hostname")
        local shell    = exec("basename \"$SHELL\"")

        local pkgs = "N/A"
        if exec("which pacman") ~= "N/A" then
            pkgs = exec("pacman -Q | wc -l") .. " (pacman)"
        elseif exec("which dpkg") ~= "N/A" then
            pkgs = exec("dpkg -l | grep -c '^ii'") .. " (dpkg)"
        elseif exec("which rpm") ~= "N/A" then
            pkgs = exec("rpm -qa | wc -l") .. " (rpm)"
        end

        -- ── System section ────────────────────────────────────────────────────

        outer:add(section("System", {
            { "Hostname",   hostname },
            { "Kernel",     kernel   },
            { "OS",         os_name  },
            { "Uptime",     getUptime() },
            { "Shell",      shell    },
            { "Packages",   pkgs     },
        }))

        -- ── Hardware section ──────────────────────────────────────────────────

        outer:add(section("Hardware", {
            { "CPU",        cpu          },
            { "Memory",     getMemory()  },
            { "GPU",        gpu          },
            { "Disk (/)",   disk         },
            { "Resolution", res          },
        }))

        outer:add(Gtk.Separator({ orientation = Gtk.Orientation.HORIZONTAL }))

        -- ── Calla DE section ──────────────────────────────────────────────────

        local wm_ver = tostring(awesome and awesome.version or "N/A")
        local theme  = tostring(user and user.color or "N/A")
        local font   = tostring(user and user.font  or "N/A")
        local cfgdir = gears.filesystem.get_configuration_dir()

        outer:add(section("Calla Desktop", {
            { "Desktop",    "Calla"               },
            { "Window Mgr", "AwesomeWM " .. wm_ver },
            { "Theme",      theme                 },
            { "Font",       font                  },
            { "Config",     cfgdir                },
        }))

        scroll:add(outer)
        scroll:show_all()
        win:add(scroll)
    end

    function app:on_activate()
        self.active_window:present()
    end

    return app:run()
end)
