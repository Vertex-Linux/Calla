local lgi       = require("lgi")
local Gtk       = lgi.require("Gtk", "3.0")
local Gdk       = lgi.require("Gdk", "3.0")
local beautiful = require("beautiful")

local provider = nil  -- reused so we never stack duplicate providers

-- Returns true if a hex color reads as light (luminance > 0.4)
local function isLight(hex)
    if not hex or #hex < 7 then return false end
    local h = hex:gsub("^#", "")
    local r = tonumber(h:sub(1,2), 16) / 255
    local g = tonumber(h:sub(3,4), 16) / 255
    local b = tonumber(h:sub(5,6), 16) / 255
    return (0.2126*r + 0.7152*g + 0.0722*b) > 0.4
end

-- Convert #RRGGBB + alpha to rgba() for GTK CSS
local function rgba(hex, a)
    local h = hex:gsub("^#", "")
    return string.format("rgba(%d,%d,%d,%.2f)",
        tonumber(h:sub(1,2), 16),
        tonumber(h:sub(3,4), 16),
        tonumber(h:sub(5,6), 16), a)
end

-- Template: {TOKENS} are replaced by makeCSS(); plain % signs are safe here
local CSS_TEMPLATE = [[
window, dialog, .background, .csd {
    background-color: {BG};
    color: {FG};
}
.titlebar, headerbar {
    background-color: {BGMID};
    color: {FG};
    border-bottom-color: {FG12};
    box-shadow: none;
}
button {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG12};
    border-radius: 8px;
    padding: 4px 12px;
    box-shadow: none;
    text-shadow: none;
    -gtk-icon-shadow: none;
}
button:hover {
    background-color: {BGALT};
    border-color: {FG25};
}
button:active {
    background-color: {FG15};
}
button:checked {
    background-color: {FG15};
    border-color: {FG25};
}
button.suggested-action {
    background-color: {FG};
    color: {BG};
    border-color: {FG};
}
button.suggested-action label {
    color: {BG};
}
button.suggested-action:hover {
    background-color: {FG80};
    color: {BG};
}
button.suggested-action:hover label {
    color: {BG};
}
entry {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG12};
    border-radius: 6px;
    box-shadow: none;
    caret-color: {FG};
}
entry:focus {
    border-color: {FG40};
    box-shadow: none;
}
entry selection {
    background-color: {FG25};
    color: {FG};
}
combobox > box > button {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG12};
    border-radius: 6px;
}
combobox > box > button:hover {
    background-color: {BGALT};
}
popover contents, popover {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG25};
    border-radius: 8px;
}
popover row, row {
    color: {FG};
    background-color: transparent;
}
popover row:hover, row:hover {
    background-color: {FG12};
}
scale trough {
    background-color: {BGMID};
    border-radius: 4px;
    min-height: 4px;
    min-width: 4px;
    border: none;
}
scale trough highlight {
    background-color: {FG};
    border-radius: 4px;
    border: none;
}
scale slider {
    background-color: {FG};
    border: none;
    border-radius: 50%;
    min-width: 14px;
    min-height: 14px;
    box-shadow: none;
}
switch {
    background-color: {BGMID};
    border-radius: 14px;
    border: 1px solid {FG25};
}
switch:checked {
    background-color: {FG};
    border-color: {FG};
}
switch slider {
    background-color: {BGALT};
    border-radius: 50%;
    margin: 2px;
    box-shadow: none;
}
switch:checked slider {
    background-color: {BG};
}
frame > border, frame border {
    border: 1px solid {FG12};
    border-radius: 8px;
}
label {
    color: {FG};
}
.dim-label {
    color: {FG60};
}
separator, .separator {
    background-color: {FG12};
    min-height: 1px;
    min-width: 1px;
}
scrollbar {
    background-color: transparent;
    border: none;
}
scrollbar slider {
    background-color: {FG30};
    border-radius: 6px;
    min-width: 6px;
    min-height: 6px;
    margin: 2px;
}
scrollbar slider:hover {
    background-color: {FG50};
}
stackswitcher button {
    border-radius: 6px;
    padding: 4px 14px;
    background-color: transparent;
    border-color: transparent;
}
stackswitcher button:checked {
    background-color: {FG15};
    border-color: {FG25};
}
stackswitcher button:hover {
    background-color: {FG12};
}
flowboxchild {
    background-color: transparent;
    padding: 0;
}
flowboxchild:selected {
    background-color: transparent;
}
spinbutton {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG12};
    border-radius: 6px;
    box-shadow: none;
}
spinbutton button {
    background-color: transparent;
    border: none;
    border-radius: 0;
    padding: 2px 6px;
}
spinbutton button:hover {
    background-color: {FG12};
}
notebook > header {
    background-color: {BGMID};
    border-color: {FG12};
}
notebook > header tab {
    background-color: transparent;
    color: {FG60};
    padding: 6px 14px;
}
notebook > header tab:checked {
    background-color: {BG};
    color: {FG};
}
colorbutton {
    border: 1px solid {FG25};
    border-radius: 6px;
    padding: 2px;
}
filechooserbutton {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG12};
    border-radius: 6px;
}
.sidebar, filechooser .sidebar {
    background-color: {BGMID};
    color: {FG};
}
.sidebar row {
    color: {FG};
    background-color: transparent;
}
.sidebar row:selected {
    background-color: {FG15};
}
tooltip {
    background-color: {BGMID};
    color: {FG};
    border: 1px solid {FG25};
    border-radius: 6px;
}
checkbutton {
    color: {FG};
}
checkbutton check {
    background-color: {BGMID};
    border: 1px solid {FG25};
    border-radius: 4px;
}
checkbutton:checked check {
    background-color: {FG};
    border-color: {FG};
    color: {BG};
}
]]

local function makeCSS(bg, bgmid, bgalt, fg)
    local subs = {
        BG    = bg,    BGMID = bgmid, BGALT = bgalt, FG = fg,
        FG80  = rgba(fg, 0.80), FG60 = rgba(fg, 0.60),
        FG50  = rgba(fg, 0.50), FG40 = rgba(fg, 0.40),
        FG30  = rgba(fg, 0.30), FG25 = rgba(fg, 0.25),
        FG15  = rgba(fg, 0.15), FG12 = rgba(fg, 0.12),
    }
    return (CSS_TEMPLATE:gsub("{(%w+)}", subs))
end

local M = {}

function M.apply()
    local screen = Gdk.Screen.get_default()
    if not screen then return end

    local bg    = beautiful.bg    or "#1e1e2e"
    local bgmid = beautiful.bgmid or "#313244"
    local bgalt = beautiful.bgalt or "#45475a"
    local fg    = beautiful.fg    or "#cdd6f4"

    if isLight(bg) then
        -- Light mode: remove dark CSS so GTK uses its native theme
        if provider then
            Gtk.StyleContext.remove_provider_for_screen(screen, provider)
            provider = nil
        end
        return
    end

    -- Dark mode: add provider once, then just reload its data on updates
    if not provider then
        provider = Gtk.CssProvider.new()
        Gtk.StyleContext.add_provider_for_screen(screen, provider, 600)
    end
    pcall(function() provider:load_from_data(makeCSS(bg, bgmid, bgalt, fg)) end)
end

return M
