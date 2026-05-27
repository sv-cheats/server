client.exec("con_filter_enable 1")

local http = require("gamesense/http")

local CONFIG = {
    loader   = "Harmony",
    version  = "v1.0",
    webhook  = "https://discord.com/api/webhooks/1501851703790538772/mHQR95dBOs9lMmrq_x2cMR5j8YbXBX_GrE1FF8S1pwejCr2WCOJTnRsOCD24QBkSEDGU",
    api      = "https://server-ddml.onrender.com",
    username = "flame",
    password = "12345",
}

local ALL_SCRIPTS = {
    Mandarin   = "https://raw.githubusercontent.com/sv-cheats/a9k3m2z8q1b7x5n4c6v0s2d8f3g7h1j5/refs/heads/main/!mandarine.lua",
    Overflame  = "https://raw.githubusercontent.com/sv-cheats/a9k3m2z8q1b7x5n4c6v0s2d8f3g7h1j5/refs/heads/main/overflame.lua",
    Antarctica = "https://raw.githubusercontent.com/anarchisrt/antarctica/main/antarcticav2.lua",
}

local COLORS = {
    info    = { 146, 210, 249 },
    success = {  80, 200, 120 },
    error   = { 240,  75,  75 },
    warn    = { 255, 180,  50 },
}

local function lerp(a, b, t) return a + (b - a) * t end

local function rec(x, y, w, h, radius, r, g, b, a)
    radius = math.min(w/2, h/2, radius)
    renderer.rectangle(x, y + radius, w, h - radius*2, r, g, b, a)
    renderer.rectangle(x + radius, y, w - radius*2, radius, r, g, b, a)
    renderer.rectangle(x + radius, y + h - radius, w - radius*2, radius, r, g, b, a)
    renderer.circle(x + radius,     y + radius,     r, g, b, a, radius, 180, 0.25)
    renderer.circle(x - radius + w, y + radius,     r, g, b, a, radius,  90, 0.25)
    renderer.circle(x - radius + w, y - radius + h, r, g, b, a, radius,   0, 0.25)
    renderer.circle(x + radius,     y - radius + h, r, g, b, a, radius, -90, 0.25)
end

local function roundedBlur(x, y, width, height, radius)
    radius = math.min(width/2, height/2, radius)
    x, y, width, height = math.floor(x), math.floor(y), math.floor(width), math.floor(height)
    renderer.blur(x + radius, y + radius, width - 2*radius, height - 2*radius)
    renderer.blur(x + radius, y,                      width - 2*radius, radius)
    renderer.blur(x + radius, y + height - radius,    width - 2*radius, radius)
    renderer.blur(x,          y + radius,              radius, height - 2*radius)
    renderer.blur(x + width - radius, y + radius,     radius, height - 2*radius)
    for i = 0, radius do
        for j = 0, radius do
            if math.sqrt((radius-i)^2 + (radius-j)^2) <= radius then renderer.blur(x + i,              y + j,               1, 1) end
            if math.sqrt(i^2          + (radius-j)^2) <= radius then renderer.blur(x + width-radius+i,  y + j,               1, 1) end
            if math.sqrt((radius-i)^2 + j^2)          <= radius then renderer.blur(x + i,              y + height-radius+j,  1, 1) end
            if math.sqrt(i^2          + j^2)          <= radius then renderer.blur(x + width-radius+i,  y + height-radius+j, 1, 1) end
        end
    end
end

local notifs = {}
local notif_slot = 0
local function push_notif(title, msg, kind)
    notif_slot = notif_slot + 1
    table.insert(notifs, {
        title  = title or "",
        msg    = msg   or "",
        kind   = kind  or "info",
        born   = globals.realtime(),
        dead   = globals.realtime() + 4.5,
        t      = 0,
        offset = -40,
        y_pos  = 0,
        slot   = notif_slot,
    })
end

local loading = {
    active   = true,
    alpha    = 0,
    bar      = 0,
    start    = nil,
    duration = 3.2,
}

local particles = {}
for i = 1, 38 do
    particles[i] = {
        angle  = math.random() * 360,
        radius = 60 + math.random() * 120,
        speed  = (math.random() * 0.4 + 0.15) * (math.random() > 0.5 and 1 or -1),
        size   = math.random() * 2.2 + 0.6,
        alpha  = math.random() * 160 + 60,
        phase  = math.random() * math.pi * 2,
    }
end

client.set_event_callback("paint_ui", function()
    local now    = globals.realtime()
    local sw, sh = client.screen_size()
    local dt     = globals.frametime()

    if loading.active and entity.get_local_player() == nil then
        if not loading.start then loading.start = now end
        local elapsed  = now - loading.start
        local progress = math.min(elapsed / loading.duration, 1)

        loading.alpha = lerp(loading.alpha, progress < 0.9 and 255 or 0, dt * (progress < 0.9 and 6 or 8))
        loading.bar   = lerp(loading.bar, progress, dt * 4)

        if loading.alpha < 2 and progress >= 1 then loading.active = false end

        local fa = math.floor(loading.alpha)
        if fa < 1 then goto skip_loading end

        local cx = math.floor(sw / 2)
        local cy = math.floor(sh / 2)

        renderer.rectangle(0, 0, sw, sh, 6, 7, 10, math.min(fa, 240))

        for _, p in ipairs(particles) do
            local ang   = math.rad(p.angle + now * p.speed * 60)
            local pulse = math.sin(now * 1.8 + p.phase) * 0.25
            local r     = p.radius * (1 + pulse)
            local px2   = cx + math.cos(ang) * r
            local py2   = cy + math.sin(ang) * r
            local pa    = math.floor(p.alpha * (loading.bar ^ 0.5) * (fa / 255))
            local ps    = math.max(1, math.floor(p.size))
            renderer.rectangle(math.floor(px2), math.floor(py2), ps, ps, 146, 210, 249, pa)
        end

        for ring = 1, 3 do
            local ring_phase = now * 0.9 + ring * 1.1
            local ring_r     = 52 + ring * 22 + math.sin(ring_phase) * 6
            local ring_a     = math.floor(fa * (0.06 - ring * 0.015) * (loading.bar ^ 0.4))
            if ring_a > 1 then
                renderer.circle_outline(cx, cy, 146, 210, 249, ring_a, math.floor(ring_r), 0, 1.0, 1)
            end
        end

        local disc_r = math.floor(44 + math.sin(now * 2.2) * 2)
        renderer.circle(cx, cy, 10, 11, 15, math.min(fa, 220), disc_r, 0, 1.0)
        renderer.circle_outline(cx, cy, 146, 210, 249, math.floor(fa * 0.5), disc_r, 0, 1.0, 1)

        local spin1 = (now * 160) % 360
        local spin2 = (now * -100 + 180) % 360
        renderer.circle_outline(cx, cy, 146, 210, 249, math.floor(fa * 0.9), disc_r + 5, spin1, 0.45, 2)
        renderer.circle_outline(cx, cy, 146, 210, 249, math.floor(fa * 0.5), disc_r + 5, spin2, 0.3,  1)

        ::skip_loading::
    end

    local H_notif = 44
    local GAP     = 6
    local alive   = {}
    for i, n in ipairs(notifs) do
        if now >= n.dead then goto continue end
        table.insert(alive, n)

        local col        = COLORS[n.kind] or COLORS.info
        local rem        = n.dead - now
        local is_leaving = rem < 0.5

        n.t = lerp(n.t, is_leaving and 0 or 1, dt * (is_leaving and 6 or 10))

        local e      = n.t * n.t * (3 - 2 * n.t)
        local fa     = math.floor(e * 255)
        local fa_dim = math.floor(e * 140)
        if fa < 2 then goto continue end

        local target_y = 18 + (i - 1) * (H_notif + GAP)
        n.y_pos  = lerp(n.y_pos == 0 and (target_y - 40) or n.y_pos, target_y, dt * 14)
        n.offset = lerp(n.offset, 0, dt * 12)
        local slide = is_leaving and math.floor(lerp(0, -30, 1 - n.t)) or math.floor(n.offset)

        local W = 300
        local R = 22
        local x = math.floor((sw - W) / 2)
        local y = math.floor(n.y_pos) + slide

        if entity.get_local_player() then
            roundedBlur(x, y, W, H_notif, R)
        else
            rec(x, y, W, H_notif, R, 6, 7, 10, math.floor(fa * 0.85))
        end
        rec(x, y, W, H_notif, R, 11, 12, 16, math.min(fa, 210))

        local spin   = (now * 220) % 360
        local arc_cx = x + H_notif / 2
        local arc_cy = y + H_notif / 2
        local arc_r  = math.floor(H_notif / 2) - 6
        renderer.circle_outline(arc_cx, arc_cy, col[1], col[2], col[3], math.floor(fa * 0.15), arc_r + 2, 0, 1.0, 1)
        renderer.circle_outline(arc_cx, arc_cy, col[1], col[2], col[3], fa, arc_r, spin, 0.5, 1)

        local tw, th = renderer.measure_text("b", n.title)
        local mw, _  = renderer.measure_text("",  n.msg)
        local tx     = math.floor(x + (W - math.max(tw, mw)) / 2)
        local ty     = y + math.floor((H_notif - th * 2 - 4) / 2)
        renderer.text(tx, ty,          col[1], col[2], col[3], fa,     "b", 0, n.title)
        renderer.text(tx, ty + th + 4, 170, 172, 178,          fa_dim, "",  0, n.msg)

        ::continue::
    end
    notifs = alive
end)

local ui_el          = {}
local loaded_scripts = {}
local user_scripts   = {}

local function make_entry(name)
    return loaded_scripts[name] and ("\a92D2F9FF" .. name) or ("\a888888FF" .. name)
end

local function refresh_list()
    local entries = {}
    for _, name in ipairs(user_scripts) do
        table.insert(entries, make_entry(name))
    end
    if ui_el.list then
        local cur = ui.get(ui_el.list)
        ui.update(ui_el.list, entries)
        ui.set(ui_el.list, cur)
    end
end

local last_click_idx  = -1
local last_click_time = 0

local function do_load(name)
    local url = ALL_SCRIPTS[name]
    if not url then return end
    push_notif("Fetching", name, "info")
    http.get(url, function(ok, res)
        if not ok or res.status ~= 200 then
            push_notif("Failed", name, "error")
            return
        end
        local fn = load(res.body)
        if not fn then
            push_notif("Error", "Compile failed", "error")
            return
        end
        if pcall(fn) then
            loaded_scripts[name] = true
            push_notif("Loaded", name, "success")
            refresh_list()
        else
            push_notif("Error", "Runtime error", "error")
        end
    end)
end

local function do_unload()
    loaded_scripts = {}
    push_notif("Unloaded", "Reloading scripts", "warn")
    refresh_list()
    client.reload_active_scripts()
end

local function do_redeem(key)
    http.post(CONFIG.api .. "/redeem", {
        json = { username = CONFIG.username, password = CONFIG.password, key = key }
    }, function(ok, res)
        if not ok or res.status ~= 200 then
            push_notif("Redeem Failed", "Server error", "error")
            return
        end
        local valid   = res.body:find('"valid"%s*:%s*true') ~= nil
        local scripts = res.body:match('"scripts"%s*:%s*"([^"]*)"') or ""
        if not valid then
            local reason = res.body:match('"reason"%s*:%s*"([^"]+)"') or "error"
            push_notif("Redeem Failed", reason, "error")
            return
        end
        user_scripts = {}
        for s in scripts:gmatch("[^,]+") do
            table.insert(user_scripts, s)
        end
        push_notif("Redeemed!", scripts, "success")
        refresh_list()
    end)
end

local function create_menu()
    ui_el.label = ui.new_label("LUA", "B",
        "\a92D2F9FF" .. CONFIG.loader ..
        "\a383838FF  |  " ..
        "\aCDCDCDFF" .. CONFIG.username ..
        "\a505050FF  " .. CONFIG.version
    )

    local init_entries = {}
    for _, name in ipairs(user_scripts) do
        table.insert(init_entries, "\a888888FF" .. name)
    end
    ui_el.list = ui.new_listbox("LUA", "B", "Scripts", init_entries)

    ui.set_callback(ui_el.list, function()
        local idx      = ui.get(ui_el.list) + 1
        local cur_time = globals.curtime()
        if last_click_idx == idx and (cur_time - last_click_time) < 0.4 then
            local name = user_scripts[idx]
            if not name then return end
            if loaded_scripts[name] then do_unload() else do_load(name) end
            last_click_idx = -1
        else
            last_click_idx  = idx
            last_click_time = cur_time
        end
    end)

    ui_el.redeem_box = ui.new_textbox("LUA", "B", "Redeem Key")
    ui_el.redeem_btn = ui.new_button("LUA", "B", "Redeem", function()
        local key = ui.get(ui_el.redeem_box)
        if not key or key == "" then
            push_notif("Error", "Enter a key", "error")
            return
        end
        do_redeem(key)
    end)
end

local function login(callback)
    push_notif("Harmony", "Authorizing...", "info")
    client.color_log(146, 210, 249, "Harmony >> Authorizing...")

    http.post(CONFIG.api .. "/login", {
        json = { username = CONFIG.username, password = CONFIG.password }
    }, function(ok, res)
        if not ok or res.status ~= 200 then
            push_notif("Auth Failed", "Server unavailable", "error")
            client.color_log(240, 75, 75, "Harmony >> Server unavailable")
            return
        end

        local valid    = res.body:find('"valid"%s*:%s*true') ~= nil
        local username = res.body:match('"username"%s*:%s*"([^"]+)"') or "unknown"
        local scripts  = res.body:match('"scripts"%s*:%s*"([^"]*)"') or ""

        if not valid then
            local reason = res.body:match('"reason"%s*:%s*"([^"]+)"') or "invalid login"
            push_notif("Auth Failed", reason, "error")
            client.color_log(240, 75, 75, "Harmony >> Auth failed: " .. reason)
            return
        end

        user_scripts = {}
        for s in scripts:gmatch("[^,]+") do
            table.insert(user_scripts, s)
        end

        callback(username)
    end)
end

local function init()
    login(function(username)
        CONFIG.username = username
        _G.harmony_username = username

        local h, m, s = client.system_time()
        local ts = string.format("%02d:%02d:%02d", h, m, s)

        push_notif("Welcome", username, "success")
        client.color_log(100, 220, 130, "Harmony >> Authorized: " .. username)
        client.color_log(100, 220, 130, "Status: Verified | Time: " .. ts)

        create_menu()

        http.post(CONFIG.webhook, {
            json = {
                embeds = {{
                    title  = "Harmony — Loader Started",
                    color  = 6083833,
                    fields = {
                        { name = "User",    value = username,                        inline = true },
                        { name = "Time",    value = ts,                              inline = true },
                        { name = "Scripts", value = table.concat(user_scripts, ", ") or "none", inline = false },
                    }
                }}
            }
        }, function() end)
    end)
end

init()
