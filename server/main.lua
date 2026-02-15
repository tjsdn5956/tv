local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP",GetCurrentResourceName())

local Locations = {}

function SetTelevision(coords, key, value, update)
    local index, data = GetTelevision(coords)
    if (index ~= nil) then 
        if (Televisions[index] == nil) then 
            Televisions[index] = {}
        end
        Televisions[index][key] = value
    else
        index = os.time()
        while Televisions[index] do 
            index = index + 1
            Citizen.Wait(0)
        end
        if (Televisions[index] == nil) then 
            Televisions[index] = {}
        end
        Televisions[index][key] = value
    end
    Televisions[index].coords = coords
    Televisions[index].update_time = os.time()
    if (update) then
        TriggerClientEvent("ptelevision:event", -1, Televisions, index, key, value)
    end
    return index
end

function SetChannel(source, data)
    if data then 
        for k,v in pairs(Channels) do 
            if (Channels[k].source == source) then 
                return
            end
        end
        local index = 1
        while Channels[index] do 
            index = index + 1
            Citizen.Wait(0)
        end
        Channels[index] = data
        Channels[index].source = source
        TriggerClientEvent("ptelevision:broadcast", -1, Channels, index)
        return
    else
        for k,v in pairs(Channels) do 
            if (Channels[k].source == source) then 
                Channels[k] = nil
                TriggerClientEvent("ptelevision:broadcast", -1, Channels, k)
                return
            end
        end
    end
end

-- 관리자 권한 체크 함수
function IsAdmin(source)
    local user_id = vRP.getUserId({source})
    if user_id then
        return vRP.hasPermission({user_id, "admin.score"})
    end
    return false
end

-- TV 메뉴 열기 권한 체크
RegisterNetEvent("ptelevision:checkPermission", function()
    local _source = source
    if IsAdmin(_source) then
        TriggerClientEvent("ptelevision:openMenu", _source, true)
    else
        TriggerClientEvent("ptelevision:openMenu", _source, false)
        local user_id = vRP.getUserId({_source})
        if user_id then
            vRPclient.notify(_source, {"~r~관리자만 TV를 사용할 수 있습니다."})
        end
    end
end)

-- Broadcast 권한 체크
RegisterNetEvent("ptelevision:checkBroadcastPermission", function()
    local _source = source
    if IsAdmin(_source) then
        TriggerClientEvent("ptelevision:openBroadcast", _source, true)
    else
        TriggerClientEvent("ptelevision:openBroadcast", _source, false)
        local user_id = vRP.getUserId({_source})
        if user_id then
            vRPclient.notify(_source, {"~r~관리자만 방송을 시작할 수 있습니다."})
        end
    end
end)

RegisterNetEvent("ptelevision:requestSync", function(coords) 
    local _source = source
    local index, data = GetTelevision(coords)
    TriggerClientEvent("ptelevision:requestSync", _source, coords, {current_time = os.time()})
end)

RegisterNetEvent("ptelevision:event", function(data, key, value) 
    local _source = source
    if not IsAdmin(_source) then
        local user_id = vRP.getUserId({_source})
        if user_id then
            vRPclient.notify(_source, {"~r~관리자만 TV를 제어할 수 있습니다."})
        end
        return
    end
    
    Config.Events.ScreenInteract(_source, data, key, value, function()
        SetTelevision(data.coords, key, value, true)
    end)
end)

RegisterNetEvent("ptelevision:broadcast", function(data)
    local _source = source
    if not IsAdmin(_source) then
        local user_id = vRP.getUserId({_source})
        if user_id then
            vRPclient.notify(_source, {"~r~관리자만 방송을 시작할 수 있습니다."})
        end
        return
    end
    
    Config.Events.Broadcast(_source, data, function()
        SetChannel(_source, data)
    end)
end)

RegisterNetEvent("ptelevision:inputSync", function(payload)
    local _source = source
    if not IsAdmin(_source) then
        return
    end
    TriggerClientEvent("ptelevision:inputSync", -1, _source, payload)
end)

RegisterNetEvent("ptelevision:requestUpdate", function()
    local _source = source
    TriggerClientEvent("ptelevision:requestUpdate", _source, {
        Televisions = Televisions,
        Channels = Channels
    })
end)

-- ============================================================
-- nooo8.tv URL 리졸버 - iframe을 직접 브라우저로 재생
-- ============================================================
local function ExtractDirectSource(body, base)
    if not body then return nil end
    local directSrc =
        string.match(body, 'src="([^"]+%.mp4[^"]*)"') or
        string.match(body, "src='([^']+%.mp4[^']*)'") or
        string.match(body, 'src="([^"]+%.m3u8[^"]*)"') or
        string.match(body, "src='([^']+%.m3u8[^']*)'") or
        string.match(body, 'file%s*:%s*"([^"]+%.m3u8[^"]*)"') or
        string.match(body, "file%s*:%s*'([^']+%.m3u8[^']*)'") or
        string.match(body, 'file%s*:%s*"([^"]+%.mp4[^"]*)"') or
        string.match(body, "file%s*:%s*'([^']+%.mp4[^']*)'")
    if directSrc then
        if string.sub(directSrc, 1, 2) == "//" then
            directSrc = "https:" .. directSrc
        elseif string.sub(directSrc, 1, 4) ~= "http" and base then
            directSrc = base .. directSrc
        end
    end
    return directSrc
end

local function FindMediaUrlInBody(body, base)
    if not body then return nil end
    local cleaned = body
    cleaned = string.gsub(cleaned, "\\/", "/")
    cleaned = string.gsub(cleaned, "\\u002f", "/")
    cleaned = string.gsub(cleaned, "&amp;", "&")

    local url =
        string.match(cleaned, "(https?://[^\"'%s>]+%.m3u8[^\"'%s>]*)") or
        string.match(cleaned, "(https?://[^\"'%s>]+%.mp4[^\"'%s>]*)") or
        string.match(cleaned, "file%s*:%s*\"(https?://[^\"]+%.m3u8[^\"]*)\"") or
        string.match(cleaned, "file%s*:%s*\"(https?://[^\"]+%.mp4[^\"]*)\"") or
        string.match(cleaned, "file%s*:%s*'(https?://[^']+%.m3u8[^']*)'") or
        string.match(cleaned, "file%s*:%s*'(https?://[^']+%.mp4[^']*)'") or
        string.match(cleaned, "src%s*:%s*\"(https?://[^\"]+%.m3u8[^\"]*)\"") or
        string.match(cleaned, "src%s*:%s*\"(https?://[^\"]+%.mp4[^\"]*)\"") or
        string.match(cleaned, "src%s*:%s*'(https?://[^']+%.m3u8[^']*)'") or
        string.match(cleaned, "src%s*:%s*'(https?://[^']+%.mp4[^']*)'") or
        string.match(cleaned, "src%s*:%s*\"(https?://[^\"]+%.m3u8[^\"]*)\"") or
        string.match(cleaned, "src%s*:%s*\"(https?://[^\"]+%.mp4[^\"]*)\"")

    if url then
        if string.sub(url, 1, 2) == "//" then
            url = "https:" .. url
        elseif string.sub(url, 1, 4) ~= "http" and base then
            url = base .. url
        end
    end
    return url
end

local function ResolveEmbedToDirect(url, referer, cb)
    if not url then
        cb(nil)
        return
    end
    local base = string.match(url, "^(https?://[^/]+)")
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        ["Referer"] = referer or url,
        ["Origin"] = base or "https://fvideostream.com"
    }
    PerformHttpRequest(url, function(statusCode, body, resHeaders)
        if statusCode ~= 200 or not body then
            cb(nil)
            return
        end
        local directSrc = ExtractDirectSource(body, base)
        if not directSrc then
            directSrc = FindMediaUrlInBody(body, base)
        end
        cb(directSrc)
    end, "GET", "", headers)
end

local function ResolveNooo8Mp4(url, cb)
    if not url or type(url) ~= "string" then
        cb(nil)
        return
    end
    
    -- 이미 처리된 URL은 그대로 반환 (임베드 서비스는 직접 소스 추출 시도)
    if string.match(url, "%.mp4") or string.match(url, "%.m3u8") then
        cb(url)
        return
    end
    if string.match(url, "fvideostream%.com") or string.match(url, "streamtape%.com") then
        ResolveEmbedToDirect(url, nil, function(direct)
            if direct then
                print("[ptelevision] ✅ 임베드에서 직접 소스 추출: " .. direct)
                cb(direct)
            else
                print("[ptelevision] ❌ 임베드 직접 소스 추출 실패 (입력 URL)")
                cb(url)
            end
        end)
        return
    end
    
    local base = string.match(url, "^(https?://[^/]+)")
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        ["Referer"] = url
    }
    
    print("[ptelevision] URL 분석 중: " .. url)
    
    PerformHttpRequest(url, function(statusCode, body, resHeaders)
        if statusCode ~= 200 or not body then
            print("[ptelevision] ❌ HTTP 요청 실패: " .. tostring(statusCode))
            cb(nil)
            return
        end
        
        -- iframe src 찾기
        local iframeSrc = string.match(body, '<iframe[^>]+src="([^"]+)"') or
                         string.match(body, "<iframe[^>]+src='([^']+)'")
        
        if iframeSrc then
            -- 상대 경로를 절대 경로로 변환
            if string.sub(iframeSrc, 1, 4) ~= "http" then
                if string.sub(iframeSrc, 1, 2) == "//" then
                    iframeSrc = "https:" .. iframeSrc
                elseif string.sub(iframeSrc, 1, 1) == "/" then
                    iframeSrc = base .. iframeSrc
                end
            end
            
            print("[ptelevision] ✅ iframe URL 추출 성공: " .. iframeSrc)

            -- 임베드 페이지에서 직접 비디오 소스 재추출 시도
            if string.find(iframeSrc, "fvideostream%.com") or string.find(iframeSrc, "streamtape%.com") then
                ResolveEmbedToDirect(iframeSrc, url, function(direct)
                    if direct then
                        print("[ptelevision] ✅ 임베드에서 직접 소스 추출: " .. direct)
                        cb(direct)
                    else
                        print("[ptelevision] ❌ 임베드 직접 소스 추출 실패 (iframe)")
                        cb(iframeSrc)
                    end
                end)
                return
            end

            cb(iframeSrc)
            return
        end
        
        -- iframe이 없으면 직접 비디오 URL 찾기
        local directSrc = ExtractDirectSource(body, base)
        if not directSrc then
            directSrc = FindMediaUrlInBody(body, base)
        end
        
        if directSrc then
            if string.sub(directSrc, 1, 4) ~= "http" and base then
                directSrc = base .. directSrc
            end
            print("[ptelevision] ✅ 직접 비디오 URL 추출: " .. directSrc)
            cb(directSrc)
        else
            print("[ptelevision] ❌ 비디오 소스를 찾을 수 없습니다")
            cb(nil)
        end
    end, "GET", "", headers)
end

RegisterNetEvent("ptelevision:resolveUrl", function(data, url)
    local _source = source
    if not IsAdmin(_source) then
        local user_id = vRP.getUserId({_source})
        if user_id then
            vRPclient.notify(_source, {"~r~관리자만 TV를 제어할 수 있습니다."})
        end
        return
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("[ptelevision] 🔍 URL 리졸빙 시작")
    print("[ptelevision] 📍 입력 URL: " .. url)
    
    ResolveNooo8Mp4(url, function(resolved)
        if not resolved then
            local user_id = vRP.getUserId({_source})
            if user_id then
                vRPclient.notify(_source, {"~r~영상 URL 추출에 실패했습니다."})
            end
            print("[ptelevision] ❌ URL 리졸빙 실패")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        end
        
        -- URL 타입에 따라 모드 결정
        local mode = "browser"  -- 기본값은 브라우저
        
        -- 직접 mp4/m3u8 파일이고 임베드 서비스가 아닌 경우만 play 모드
        if (string.match(resolved, "%.mp4") or string.match(resolved, "%.m3u8")) and
           not string.match(resolved, "fvideostream") and 
           not string.match(resolved, "streamtape") and
           not string.match(resolved, "embed") and
           not string.match(resolved, "player") then
            mode = "play"
        end
        
        print("[ptelevision] ✅ URL 리졸빙 성공")
        print("[ptelevision] 📺 재생 모드: " .. mode)
        print("[ptelevision] 🔗 최종 URL: " .. resolved)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        SetTelevision(data.coords, "ptv_status", {
            type = mode,
            url = resolved,
            time = 0,
            state = "playing"
        }, true)
        
        local user_id = vRP.getUserId({_source})
        if user_id then
            if mode == "browser" then
                vRPclient.notify(_source, {"~g~웹 브라우저 모드로 재생"})
            else
                vRPclient.notify(_source, {"~g~비디오 플레이어 모드로 재생"})
            end
        end
    end)
end)

RegisterNetEvent("ptelevision:playerSync", function(payload)
    local _source = source
    if not IsAdmin(_source) then
        return
    end
    if payload and payload.coords then
        local index, tv = GetTelevision(payload.coords)
        if index and Televisions[index] and Televisions[index].ptv_status then
            local status = Televisions[index].ptv_status
            if payload.time ~= nil then
                status.time = payload.time
            end
            if payload.state ~= nil then
                status.state = payload.state
            end
            Televisions[index].ptv_status = status
            Televisions[index].update_time = os.time()
        end
    end
    TriggerClientEvent("ptelevision:playerSync", -1, _source, payload)
end)

AddEventHandler('playerDropped', function(reason)
    local _source = source
    SetChannel(_source, nil)
end)

RegisterNetEvent("ptelevision:setGlobalVolume", function(data, volumeValue)
    local _source = source
    
    if not IsAdmin(_source) then
        local user_id = vRP.getUserId({_source})
        if user_id then
            vRPclient.notify(_source, {"~r~관리자만 전체 볼륨을 조절할 수 있습니다."})
        end
        return
    end
    
    SetTelevision(data.coords, "volume", volumeValue, true)
end)
