--==============================================================================
--  SMPWORK  ·  loader
--  ------------------------------------------------------------------
--  Paste THIS file into the Xeno executor. It downloads SMPWORK.lua from
--  GitHub and runs it.
--
--  Usage:
--    1. edit the URL below (replace YOUR_USER / SMPWORK with your repo)
--    2. open Roblox with Xeno, open the script tab, paste this, press Execute
--
--  Credits : Akram Abbaoui  &  Amjad Nejjari
--  Target  : Xeno (Luau) executor
--==============================================================================

local PROJECT = "SMPWORK"

--------------------------------------------------------------------------------
-- 1. WHERE TO DOWNLOAD THE HUB FROM
--------------------------------------------------------------------------------
-- Replace YOUR_USER with your GitHub username and SMPWORK with your repo name.
-- Example:
--   "https://raw.githubusercontent.com/AkramX/SMPWORK/main/SMPWORK.lua"
--
-- Add more mirrors below if you want a fallback (the first one that answers
-- wins). A mirror is just another raw URL that serves the same file.
local SOURCES = {
    "https://raw.githubusercontent.com/YOUR_USER/SMPWORK/main/SMPWORK.lua",
}

--------------------------------------------------------------------------------
-- 2. DOWNLOAD HELPERS
--------------------------------------------------------------------------------

-- Fetch a URL as a string, trying every method the executor might expose.
-- Returns the body, or nil + a reason.
local function fetch(url)
    local lastError = "no HTTP method available"

    -- Roblox's own HttpGet (executors usually patch it back in)
    if type(game) == "table" and type(game.HttpGet) == "function" then
        local ok, body = pcall(game.HttpGet, game, url)
        if ok and type(body) == "string" and #body > 0 then return body end
        lastError = ok and "empty response" or tostring(body)
    end

    -- executor globals
    for _, name in ipairs({ "request", "http_request", "syn_request" }) do
        local fn = rawget(_G, name)
        if type(fn) == "function" then
            local ok, body = pcall(fn, url)
            if ok and type(body) == "string" and #body > 0 then return body end
            lastError = ok and "empty response" or tostring(body)
        end
    end

    -- syn.request
    if type(syn) == "table" and type(syn.request) == "function" then
        local ok, res = pcall(syn.request, { Url = url, Method = "GET" })
        if ok then
            if type(res) == "string" and #res > 0 then return res end
            if type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
                return res.Body
            end
            lastError = "empty response"
        else
            lastError = tostring(res)
        end
    end

    return nil, lastError
end

-- Compile a chunk of Luau source.
local function compile(source)
    if type(loadstring) == "function" then
        local ok, chunk = pcall(loadstring, source)
        if ok and type(chunk) == "function" then return chunk end
        return nil, chunk
    end
    if type(load) == "function" then
        local ok, chunk = pcall(load, source, "@" .. PROJECT .. ".lua")
        if ok and type(chunk) == "function" then return chunk end
        return nil, chunk
    end
    return nil, "this executor has no loadstring()/load()"
end

--------------------------------------------------------------------------------
-- 3. RUN
--------------------------------------------------------------------------------

local function report(msg)
    print("[" .. PROJECT .. "] " .. msg)
    -- some executors show a chat message, which is friendlier than a console line
    if type(warn) == "function" then pcall(warn, "[" .. PROJECT .. "] " .. msg) end
end

local function run()
    -- sanity check the URLs before we waste a request
    local usable = {}
    for _, url in ipairs(SOURCES) do
        if type(url) == "string" and #url > 0 and not url:find("YOUR_USER", 1, true) then
            usable[#usable + 1] = url
        end
    end

    if #usable == 0 then
        report("SOURCES is not configured yet.")
        report("Open loader.lua and replace YOUR_USER with your GitHub username.")
        return
    end

    local source, lastError = nil, nil

    for _, url in ipairs(usable) do
        local body, err = fetch(url)
        if type(body) == "string" and #body > 0 then
            source = body
            report("downloaded " .. #body .. " bytes from " .. url)
            break
        end
        lastError = err or "empty response"
        report("failed: " .. url .. " (" .. tostring(lastError) .. ")")
    end

    if not source then
        report("could not download the script. Check the URL and your internet.")
        return
    end

    -- basic sanity check so we do not run an HTML error page from GitHub
    if not source:find("SMPWORK", 1, true) and not source:find("MinimaHub", 1, true) then
        report("the downloaded file does not look like SMPWORK.lua - aborting.")
        return
    end

    local chunk, compileError = compile(source)
    if not chunk then
        report("syntax error in the downloaded script: " .. tostring(compileError))
        return
    end

    local ok, err = pcall(chunk)
    if not ok then
        report("error while running: " .. tostring(err))
        return
    end

    report("loaded. RightControl toggles the overlay.")
end

run()
