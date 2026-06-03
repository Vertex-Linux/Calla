local gears    = require("gears")
local lgi      = require("lgi")
local Gtk      = lgi.require("Gtk", "3.0")

local calfile  = gears.filesystem.get_cache_dir() .. "calendar.json"

-- ── Data ──────────────────────────────────────────────────────────────────────

local function calLoad()
    if not gears.filesystem.file_readable(calfile) then
        return { events = {}, tasks = {} }
    end
    local d = readjson(calfile)
    if not d then d = {} end
    if not d.events then d.events = {} end
    if not d.tasks  then d.tasks  = {} end
    return d
end

local function calSave(d)
    writejson(calfile, d)
    awesome.emit_signal("calendar::update")
end

local function newId()
    return tostring(os.time()) .. tostring(math.random(10000, 99999))
end

-- ── Date helpers ──────────────────────────────────────────────────────────────

local MONTHS = {
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
}

local function daysInMonth(y, m)
    return os.date("*t", os.time({ year = y, month = m + 1, day = 0 })).day
end

local function firstWeekday(y, m)
    return os.date("*t", os.time({ year = y, month = m, day = 1 })).wday - 1
end

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

local function isTaskDone(task, ds)
    if not task.repeat_type or task.repeat_type == "none" then
        return task.completed == true
    end
    if task.completed_dates then
        for _, cd in ipairs(task.completed_dates) do
            if cd == ds then return true end
        end
    end
    return false
end

local function getForDate(data, ds)
    local events, tasks, seen = {}, {}, {}
    for _, e in ipairs(data.events) do
        if itemMatchesDate(e, ds) and not seen[e.id] then
            seen[e.id] = true
            table.insert(events, e)
        end
    end
    for _, t in ipairs(data.tasks) do
        if itemMatchesDate(t, ds) then table.insert(tasks, t) end
    end
    return { events = events, tasks = tasks }
end

-- ── Input dialogs ─────────────────────────────────────────────────────────────

local REPEAT_LABELS = { "None", "Daily", "Weekly", "Monthly", "Yearly" }
local REPEAT_VALUES = { "none", "daily", "weekly", "monthly", "yearly" }

local function inputDialog(parent, is_event, default_date, callback)
    local dlg = Gtk.Dialog({
        title         = is_event and "Add Event" or "Add Task",
        transient_for = parent,
        modal         = true,
    })
    dlg:add_button("Cancel", Gtk.ResponseType.CANCEL)
    dlg:add_button(is_event and "Add Event" or "Add Task", Gtk.ResponseType.OK)

    local box = dlg:get_content_area()
    box.margin = 12; box.spacing = 6

    local function lrow(lbl, w)
        local r = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL, spacing = 2 })
        r:add(Gtk.Label({ label = lbl, halign = Gtk.Align.START }))
        r:add(w); return r
    end

    local title_e = Gtk.Entry({ placeholder_text = is_event and "Event title" or "Task title" })
    box:add(lrow("Title", title_e))
    local date_e  = Gtk.Entry({ text = default_date or "" })
    box:add(lrow("Date (YYYY-MM-DD)", date_e))
    local allday  = Gtk.CheckButton({ label = "All Day", active = true })
    box:add(allday)
    local trow    = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = 8 })
    local start_e = Gtk.Entry({ text = "09:00", width_chars = 5 })
    trow:add(Gtk.Label({ label = "Start:" })); trow:add(start_e)
    local end_e
    if is_event then
        end_e = Gtk.Entry({ text = "10:00", width_chars = 5 })
        trow:add(Gtk.Label({ label = "End:" })); trow:add(end_e)
    end
    box:add(trow)
    function allday:on_toggled() trow.visible = not self.active end
    local rep = Gtk.ComboBoxText()
    for _, l in ipairs(REPEAT_LABELS) do rep:append_text(l) end
    rep:set_active(0)
    box:add(lrow("Repeat", rep))

    dlg:show_all(); trow.visible = false
    local response = dlg:run()
    local result   = nil
    if response == Gtk.ResponseType.OK and title_e.text ~= "" and date_e.text ~= "" then
        local ri = rep:get_active()
        result = {
            id = newId(), title = title_e.text, date = date_e.text,
            all_day     = allday.active,
            start_time  = (not allday.active) and start_e.text or nil,
            end_time    = (is_event and not allday.active) and (end_e and end_e.text) or nil,
            repeat_type = REPEAT_VALUES[ri + 1] or "none",
            completed   = false, completed_dates = {},
        }
    end
    dlg:destroy()
    if result then callback(result) end
end

-- ── Application ───────────────────────────────────────────────────────────────

awesome.connect_signal("widget::calendar", function(open_y, open_m, open_d)

    local app = Gtk.Application({ application_id = "io.github.stardust-kyun.calla.calendar" })

    local td0  = os.date("*t")
    local cy   = open_y or td0.year
    local cm   = open_m or td0.month
    local cday = open_d or td0.day

    -- These are assigned in on_startup and captured by the rebuild functions
    local grid_box, panel_box, hdr_label, win

    -- clear a GTK container safely
    local function clear(container)
        container:foreach(function(w) w:destroy() end)
    end

    -- ── Rebuild day panel ──────────────────────────────────────────────────

    local function rebuildPanel()
        clear(panel_box)
        local ds    = dateStr(cy, cm, cday)
        local data  = calLoad()
        local items = getForDate(data, ds)
        local sep   = function() return Gtk.Separator({ orientation = Gtk.Orientation.HORIZONTAL }) end

        local date_lbl = Gtk.Label({
            label = string.format("%s %d, %d", MONTHS[cm], cday, cy),
            halign = Gtk.Align.START,
        })
        panel_box:add(date_lbl)
        panel_box:add(sep())
        panel_box:add(Gtk.Label({ label = "Events", halign = Gtk.Align.START }))

        if #items.events == 0 then
            local lbl = Gtk.Label({ label = "No events", halign = Gtk.Align.START })
            lbl:set_sensitive(false); panel_box:add(lbl)
        end
        for _, e in ipairs(items.events) do
            local time_txt = e.all_day and "All Day"
                or ((e.start_time or "") .. (e.end_time and ("  –  " .. e.end_time) or ""))
            local row  = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = 4 })
            local info = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL })
            info:add(Gtk.Label({ label = time_txt, halign = Gtk.Align.START }))
            info:add(Gtk.Label({ label = e.title,  halign = Gtk.Align.START }))
            local del = Gtk.Button({ label = "✕" })
            local eid = e.id
            function del:on_clicked()
                local d2 = calLoad()
                for i, ev in ipairs(d2.events) do
                    if ev.id == eid then table.remove(d2.events, i); break end
                end
                calSave(d2); rebuildPanel()
            end
            row:pack_start(info, true, true, 0)
            row:pack_end(del, false, false, 0)
            panel_box:add(row)
        end

        panel_box:add(sep())
        panel_box:add(Gtk.Label({ label = "Tasks", halign = Gtk.Align.START }))

        if #items.tasks == 0 then
            local lbl = Gtk.Label({ label = "No tasks", halign = Gtk.Align.START })
            lbl:set_sensitive(false); panel_box:add(lbl)
        end
        for _, t in ipairs(items.tasks) do
            local done  = isTaskDone(t, ds)
            local row   = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = 4 })
            local check = Gtk.CheckButton({ label = t.title, active = done })
            local tid   = t.id
            function check:on_toggled()
                local d2 = calLoad()
                for _, t2 in ipairs(d2.tasks) do
                    if t2.id == tid then
                        if not t2.repeat_type or t2.repeat_type == "none" then
                            t2.completed = not t2.completed
                        else
                            if not t2.completed_dates then t2.completed_dates = {} end
                            local found = false
                            for i, cd in ipairs(t2.completed_dates) do
                                if cd == ds then table.remove(t2.completed_dates, i); found = true; break end
                            end
                            if not found then table.insert(t2.completed_dates, ds) end
                        end
                        break
                    end
                end
                calSave(d2)
            end
            local del = Gtk.Button({ label = "✕" })
            function del:on_clicked()
                local d2 = calLoad()
                for i, t2 in ipairs(d2.tasks) do
                    if t2.id == tid then table.remove(d2.tasks, i); break end
                end
                calSave(d2); rebuildPanel()
            end
            row:pack_start(check, true, true, 0)
            row:pack_end(del, false, false, 0)
            panel_box:add(row)
        end

        panel_box:show_all()
    end

    -- ── Rebuild month grid ─────────────────────────────────────────────────

    local function rebuildGrid()
        clear(grid_box)
        hdr_label.label = MONTHS[cm] .. "  " .. cy

        local data     = calLoad()
        local td       = os.date("*t")
        local today_ds = dateStr(td.year, td.month, td.day)
        local sel_ds   = dateStr(cy, cm, cday)

        for i, d in ipairs({ "Su","Mo","Tu","We","Th","Fr","Sa" }) do
            grid_box:attach(Gtk.Label({ label = d }), i - 1, 0, 1, 1)
        end

        local first = firstWeekday(cy, cm)
        local days  = daysInMonth(cy, cm)

        for day = 1, days do
            local ds     = dateStr(cy, cm, day)
            local grow   = math.floor((first + day - 1) / 7) + 1
            local gcol   = (first + day - 1) % 7
            local items  = getForDate(data, ds)
            local has_ev = #items.events > 0
            local has_tk = #items.tasks  > 0

            local lbl
            if ds == today_ds then
                lbl = "[ " .. day .. " ]"
            else
                lbl = tostring(day)
            end
            if has_ev then lbl = lbl .. " •" end
            if has_tk then lbl = lbl .. (has_ev and "○" or " ○") end

            local btn = Gtk.Button({ label = lbl })
            if ds == sel_ds then
                btn:get_style_context():add_class("suggested-action")
            end
            local cap = day
            function btn:on_clicked()
                cday = cap; rebuildGrid(); rebuildPanel()
            end
            grid_box:attach(btn, gcol, grow, 1, 1)
        end

        grid_box:show_all()
    end

    -- ── Build window ───────────────────────────────────────────────────────

    function app:on_startup()
        win = Gtk.ApplicationWindow({
            title          = "Calendar",
            application    = self,
            default_width  = 860,
            default_height = 520,
        })
        win:set_wmclass("calendar", "Calendar")

        local vbox = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL, spacing = 6, margin = 10 })

        -- Header
        hdr_label = Gtk.Label({ label = "" })
        local prev_btn = Gtk.Button({ label = "◀" })
        function prev_btn:on_clicked()
            cm = cm - 1
            if cm < 1 then cm = 12; cy = cy - 1 end
            if cday > daysInMonth(cy, cm) then cday = daysInMonth(cy, cm) end
            rebuildGrid(); rebuildPanel()
        end
        local next_btn = Gtk.Button({ label = "▶" })
        function next_btn:on_clicked()
            cm = cm + 1
            if cm > 12 then cm = 1; cy = cy + 1 end
            if cday > daysInMonth(cy, cm) then cday = daysInMonth(cy, cm) end
            rebuildGrid(); rebuildPanel()
        end
        local today_btn = Gtk.Button({ label = "Today" })
        function today_btn:on_clicked()
            local td = os.date("*t"); cy, cm, cday = td.year, td.month, td.day
            rebuildGrid(); rebuildPanel()
        end
        local hdr = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = 8 })
        hdr:pack_start(prev_btn,  false, false, 0)
        hdr:pack_start(hdr_label, false, false, 0)
        hdr:pack_start(next_btn,  false, false, 0)
        hdr:pack_end(today_btn,   false, false, 0)
        vbox:pack_start(hdr, false, false, 0)

        -- Content pane
        grid_box = Gtk.Grid({
            row_spacing = 4, column_spacing = 4,
            row_homogeneous = true, column_homogeneous = true, margin = 4,
        })

        panel_box = Gtk.Box({ orientation = Gtk.Orientation.VERTICAL, spacing = 6, margin = 10 })
        local scroll = Gtk.ScrolledWindow()
        scroll:set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll:add(panel_box)

        local paned = Gtk.Paned({ orientation = Gtk.Orientation.HORIZONTAL })
        paned:pack1(grid_box, true,  false)
        paned:pack2(scroll,   false, false)
        vbox:pack_start(paned, true, true, 0)

        -- Footer
        local add_event_btn = Gtk.Button({ label = "+ Add Event" })
        function add_event_btn:on_clicked()
            inputDialog(win, true, dateStr(cy, cm, cday), function(ev)
                local d = calLoad(); table.insert(d.events, ev); calSave(d)
                rebuildGrid(); rebuildPanel()
            end)
        end
        local add_task_btn = Gtk.Button({ label = "+ Add Task" })
        function add_task_btn:on_clicked()
            inputDialog(win, false, dateStr(cy, cm, cday), function(tk)
                local d = calLoad(); table.insert(d.tasks, tk); calSave(d)
                rebuildGrid(); rebuildPanel()
            end)
        end
        local footer = Gtk.Box({ orientation = Gtk.Orientation.HORIZONTAL, spacing = 8 })
        footer:pack_start(add_event_btn, false, false, 0)
        footer:pack_start(add_task_btn,  false, false, 0)
        vbox:pack_end(footer, false, false, 0)

        -- Build initial content, THEN show and add to window
        rebuildGrid()
        rebuildPanel()

        -- Handle navigation signals when the app is already open
        local nav_handler = function(y, m, d)
            cy = y; cm = m; cday = d
            rebuildGrid(); rebuildPanel()
            win:present()
        end
        awesome.connect_signal("calendar::navigate", nav_handler)
        win.on_destroy = function()
            awesome.disconnect_signal("calendar::navigate", nav_handler)
        end

        vbox:show_all()   -- must call before win:add so GTK registers windows
        win:add(vbox)
    end

    function app:on_activate()
        self.active_window:present()
    end

    return app:run()
end)
