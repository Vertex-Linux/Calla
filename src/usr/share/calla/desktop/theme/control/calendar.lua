local awful    = require("awful")
local wibox    = require("wibox")
local gears    = require("gears")
local beautiful = require("beautiful")
local dpi      = beautiful.xresources.apply_dpi

local calfile  = gears.filesystem.get_cache_dir() .. "calendar.json"

-- ── Shared calendar data (updated via signal) ─────────────────────────────────

local cal_data = { events = {}, tasks = {} }

local function loadData()
    if gears.filesystem.file_readable(calfile) then
        local d = readjson(calfile)
        if d then
            if not d.events then d.events = {} end
            if not d.tasks  then d.tasks  = {} end
            cal_data = d
            return
        end
    end
    cal_data = { events = {}, tasks = {} }
end

loadData()

local function dateStr(y, m, d)
    return string.format("%04d-%02d-%02d", y, m, d)
end

local function parseDate(ds)
    return tonumber(ds:sub(1,4)), tonumber(ds:sub(6,7)), tonumber(ds:sub(9,10))
end

local function itemMatchesDate(item, ds)
    if item.date == ds then return true end
    local rt = item.repeat_type
    if not rt or rt == "none" or item.date > ds then return false end
    local ey, em, ed = parseDate(item.date)
    local dy, dm, dd = parseDate(ds)
    if rt == "daily"   then return true end
    if rt == "weekly"  then
        local ew = os.date("*t", os.time({ year=ey, month=em, day=ed })).wday
        local dw = os.date("*t", os.time({ year=dy, month=dm, day=dd })).wday
        return ew == dw
    end
    if rt == "monthly" then return ed == dd end
    if rt == "yearly"  then return em == dm and ed == dd end
    return false
end

local function getForDate(ds)
    local events, tasks, seen = {}, {}, {}
    for _, e in ipairs(cal_data.events) do
        if itemMatchesDate(e, ds) and not seen[e.id] then
            seen[e.id] = true
            table.insert(events, e)
        end
    end
    for _, t in ipairs(cal_data.tasks) do
        if itemMatchesDate(t, ds) then table.insert(tasks, t) end
    end
    return { events = events, tasks = tasks }
end

local function hasItemsOnDate(y, m, d)
    local ds = dateStr(y, m, d)
    local i  = getForDate(ds)
    return (#i.events + #i.tasks) > 0
end

-- ── fn_embed: add dots to days that have events/tasks ────────────────────────

local function decorate(widget, flag, date)
    local retbg
    if flag == "focus" then
        retbg = beautiful.fg .. "33"
    else
        retbg = beautiful.bgmid
    end

    local inner = wibox.widget {
        {
            widget,
            halign = "center",
            valign = "center",
            fill_horizontal = true,
            fill_vertical   = true,
            widget = wibox.container.place,
        },
        bg     = retbg,
        shape  = flag == "focus" and gears.shape.circle or nil,
        widget = background({ fg = "fg" })
    }

    local result = inner

    if (flag == "normal" or flag == "focus") and date and date.day then
        -- Stack a small dot at the bottom of days that have events/tasks
        if hasItemsOnDate(date.year, date.month, date.day) then
            result = wibox.widget {
                inner,
                {
                    {
                        forced_width  = dpi(4),
                        forced_height = dpi(4),
                        shape  = gears.shape.circle,
                        bg     = beautiful.fg,
                        widget = wibox.container.background,
                    },
                    valign = "end",
                    halign = "center",
                    widget = wibox.container.place,
                },
                layout = wibox.layout.stack,
            }
        end

        -- Click any day cell to open the calendar app at that date
        result.buttons = {
            awful.button({}, 1, function()
                awesome.emit_signal("widget::control")
                awesome.emit_signal("widget::calendar", date.year, date.month, date.day)
                awesome.emit_signal("calendar::navigate", date.year, date.month, date.day)
            end)
        }
    end

    awesome.connect_signal("live::reload", function()
        if flag == "focus" then retbg = beautiful.fg .. "33"
        else retbg = beautiful.bgmid end
        inner.bg    = retbg
        inner.shape = flag == "focus" and gears.shape.circle or nil
    end)

    return result
end

-- ── Month calendar widget ─────────────────────────────────────────────────────

local cal_widget = wibox.widget {
    font         = user.font,
    start_sunday = true,
    flex_height  = true,
    fn_embed     = decorate,
    widget       = wibox.widget.calendar.month(os.date("*t")),
}

local calendar = wibox.widget {
    {
        {
            cal_widget,
            margins = dpi(10),
            widget  = wibox.container.margin,
        },
        forced_width  = dpi(220),
        forced_height = dpi(220),
        widget        = background({ bg = "bgmid", fg = "fg" })
    },
    -- "Open Calendar" tap area at the bottom of the calendar
    {
        hovercursor(wibox.widget {
            {
                text   = "Open Calendar →",
                font   = user.font,
                halign = "center",
                widget = wibox.widget.textbox,
            },
            top    = dpi(4),
            bottom = dpi(4),
            widget = wibox.container.margin,
        }),
        buttons = {
            awful.button({}, 1, function()
                awesome.emit_signal("widget::control")  -- close control panel
                awesome.emit_signal("widget::calendar") -- open calendar app
            end)
        },
        forced_width  = dpi(220),
        bg     = beautiful.bgalt,
        fg     = beautiful.fg,
        shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(6)) end,
        widget = background({ bg = "bgalt", fg = "fg" }),
    },
    spacing = dpi(6),
    layout  = wibox.layout.fixed.vertical,
}

-- ── Refresh when calendar data changes ───────────────────────────────────────

awesome.connect_signal("calendar::update", function()
    loadData()
    cal_widget:emit_signal("widget::redraw_needed")
end)

return calendar
