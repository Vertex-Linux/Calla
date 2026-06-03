--[[ 
--	TODO
--
--	Why is text content changed when its color is changed? -- markdown? needs to be bg container?
--
--	Features:
--	Alt+tab menu
--	Desktop menu
--
--	Settings:
--	Completely redesign settings app
--	Add autostart commands to settings
--	Add modkey/sessionlock to settings
--	Add profile picture to settings
--	Create Gtk theme from color json
--	Import theme (Xresources?)
--
--	Design:
--	Redesign preview to look more like macos (expose)
--	Hover cursor on titlebar buttons
--	Hover background?
--
--	Refactor:
--	Is it finally time to make a helpers file...?
--	Make battery use upower
--	Move custom themes to cache
--	Get rid of color dir
--	Differentiate custom themes from default
--
--	Long Term:
--	Better multihead support
--]]

--[[
--	Known Bugs
--
--	Multihead:
--	Location of lockscreen promptbox depends on focused screen at startup,
--	doesn't appear if laptop screen focused
--	Systray opens/closes for both screens, one is redundant
--
--	General:
--	Preview does not entirely reload if visible
--	Desktop get grid function does not account for spacing
--	Icon theme is not refreshed with live reload
--	fprintd-verify does not work after suspend (issue #173)
--
--	Unknown Bugs:
--	Many
--]]

local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

-- Errors

naughty.connect_signal("request::display_error", function(message, startup)
	naughty.notification {
		urgency = "critical",
		title   = "Error"..(startup and " during startup!" or "!"),
		message = message
	}
end)

-- Json

function readjson(path)
	local r = assert(io.open(path, "r"))
	local table = r:read("*all")
	r:close()
	table = require("json"):decode(table)
	return table
end

function writejson(path, table)
	local w = assert(io.open(path, "w"))
	w:write(require("json"):encode_pretty(table, nil, { pretty = true, indent = "	", align_keys = false, array_newline = true}))
	w:close()
end

local config = gears.filesystem.get_cache_dir() .. "user.json"

local defaults = {
	batt = "BAT0",
	color = "light",
	font = "Roboto Medium 11",
	fontalt = "Roboto Bold 11",
	mod = "Mod4",
	passwd = "axos",
	reboot = "systemctl reboot",
	sessionlock = false,
	shotdir = "~/Pictures/Screenshots",
	shutdown = "systemctl poweroff",
	terminal = "alacritty",
	panel_menu     = true,
	panel_taglist  = true,
	panel_layouts  = true,
	panel_systray  = true,
	panel_media    = true,
	panel_volume   = true,
	panel_battery  = true,
	panel_clock    = true,
	panel_dock     = true,
}

if not gears.filesystem.file_readable(config) then
	writejson(config, defaults)
end

user = readjson(config)

-- Merge any new defaults missing from existing config (e.g. after upgrades)
local _dirty = false
for k, v in pairs(defaults) do
	if user[k] == nil then user[k] = v; _dirty = true end
end
if _dirty then writejson(config, user) end

-- Copy system config files to user cache dir so they can be written without root
local cachedir = gears.filesystem.get_cache_dir()
local confdir  = gears.filesystem.get_configuration_dir()

local function copyfile_ifnewer(src, dst)
	-- Always sync system → cache if system file is newer (picks up package updates)
	-- but preserve user edits: only overwrite if src is strictly newer
	os.execute("cp -u '" .. src .. "' '" .. dst .. "'")
end

copyfile_ifnewer("/usr/share/calla/compositor.conf", cachedir .. "compositor.conf")
copyfile_ifnewer("/usr/share/calla/Xresources",      cachedir .. "Xresources")
copyfile_ifnewer("/usr/share/calla/xsettingsd",      cachedir .. "xsettingsd")

os.execute("mkdir -p '" .. cachedir .. "color'")
for _, scheme in ipairs({"dark", "light", "solarized"}) do
	if not gears.filesystem.dir_readable(cachedir .. "color/" .. scheme) then
		os.execute("cp -r '" .. confdir .. "color/" .. scheme .. "' '" .. cachedir .. "color/'")
	end
end

-- Config

require("awful.autofocus")
require("signal")
require("config")
require("theme")
require("color.desktop")

-- Startup

local autostart = {
	"picom --config '" .. cachedir .. "compositor.conf'",
	"xsettingsd --config '" .. cachedir .. "xsettingsd'",
	"nm-applet",
	"/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
}

local function restarted()
	awesome.register_xproperty("restarted", "boolean")
	local detected = awesome.get_xproperty("restarted") ~= nil
	awesome.set_xproperty("restarted", true)
	return detected
end

if not restarted() then
	for _, command in ipairs(autostart) do
		awful.spawn.easy_async({ 'pkill', '--full', '--uid', os.getenv('USER'), '^' .. command }, function()
			awful.spawn.easy_async_with_shell(command, function() end) -- func needed to avoid callback error
		end)
	end
	if user.sessionlock then
		require("theme.lock")
		awesome.emit_signal("widget::lockscreen")
	end
end

-- Theme Init

awesome.emit_signal("live::reload")
