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
-- 공통 헬퍼 함수들
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

-- ============================================================
-- tvroom11.org 전용 리졸버 (개선됨)
-- ============================================================
local function ResolveTvroomUrl(url, cb)
    if not url or type(url) ~= "string" then
        cb(nil)
        return
    end
    
    -- 이미 처리된 URL은 그대로 반환
    if string.match(url, "%.mp4") or string.match(url, "%.m3u8") then
        cb(url)
        return
    end
    
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ["Referer"] = url
    }
    
    print("[ptelevision] 📺 tvroom 1단계: 페이지 분석 중...")
    
    -- tvroom 페이지에서 player iframe URL 추출
    PerformHttpRequest(url, function(statusCode, body, resHeaders)
        if statusCode ~= 200 or not body then
            print("[ptelevision] ❌ 1단계 실패: HTTP " .. tostring(statusCode))
            cb(nil)
            return
        end
        
        -- HTML 정규화
        local cleaned = string.gsub(body, "\\/", "/")
        cleaned = string.gsub(cleaned, "\\u002f", "/")
        cleaned = string.gsub(cleaned, "&amp;", "&")
        
        -- player iframe URL 찾기
        local playerUrl = string.match(cleaned, '<iframe[^>]+src=["\']([^"\']+player[^"\']+)["\']')
        
        if not playerUrl then
            print("[ptelevision] ❌ player iframe을 찾을 수 없습니다")
            cb(nil)
            return
        end
        
        -- 상대 경로 처리
        if string.sub(playerUrl, 1, 2) == "//" then
            playerUrl = "https:" .. playerUrl
        elseif string.sub(playerUrl, 1, 1) == "/" then
            local base = string.match(url, "^(https?://[^/]+)")
            playerUrl = base .. playerUrl
        end
        
        print("[ptelevision] ✅ 1단계 완료: player URL 추출")
        print("[ptelevision] 🔗 Player: " .. playerUrl)
        print("[ptelevision] 📺 player를 iframe으로 표시 (브라우저 모드)")
        
        -- player URL을 브라우저 모드로 반환
        -- m3u8 추출하지 않고 player iframe을 직접 표시
        cb({url = playerUrl, mode = "browser"})
        
    end, "GET", "", headers)
end

-- ============================================================
-- nooo8.tv 전용 리졸버 (기존 유지)
-- ============================================================
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

-- ============================================================
-- 메인 URL 리졸버 이벤트
-- ============================================================
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
    
    local lower = string.lower(url)
    
    -- tvroom 처리
    if string.find(lower, "tvroom") then
        print("[ptelevision] 🎬 tvroom 리졸버 사용")
        
        ResolveTvroomUrl(url, function(resolved)
            if resolved then
                local finalUrl, finalMode
                
                -- 리졸버가 테이블(mode 정보 포함)을 반환한 경우
                if type(resolved) == "table" then
                    finalUrl = resolved.url
                    finalMode = resolved.mode or "browser"
                else
                    -- 문자열로 반환한 경우 (backward compatibility)
                    finalUrl = resolved
                    finalMode = "play"
                end
                
                print("[ptelevision] ✅ URL 리졸빙 성공")
                print("[ptelevision] 📺 재생 모드: " .. finalMode)
                print("[ptelevision] 🔗 최종 URL: " .. finalUrl)
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                SetTelevision(data.coords, "ptv_status", {
                    type = finalMode,
                    url = finalUrl,
                    time = 0,
                    state = "playing"
                }, true)
                
                local user_id = vRP.getUserId({_source})
                if user_id then
                    vRPclient.notify(_source, {"~g~영상 재생 시작"})
                end
            else
                print("[ptelevision] ❌ URL 리졸빙 실패")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                local user_id = vRP.getUserId({_source})
                if user_id then
                    vRPclient.notify(_source, {"~r~영상 URL 추출에 실패했습니다."})
                end
            end
        end)
        return
    end
    
    -- nooo8.tv 처리
    if string.find(lower, "nooo8%.tv/") then
        print("[ptelevision] 🎬 nooo8 리졸버 사용")
        
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
            
            local mode = "play"
            if not (string.match(resolved, "%.mp4") or string.match(resolved, "%.m3u8")) then
                mode = "browser"
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
                vRPclient.notify(_source, {"~g~영상 재생 시작"})
            end
        end)
        return
    end
    
    -- 기본 리졸버 (직접 mp4/m3u8 URL이거나 기타 사이트)
    print("[ptelevision] 🎬 기본 리졸버 사용")
    
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
        
        local mode = "play"
        if not (string.match(resolved, "%.mp4") or string.match(resolved, "%.m3u8")) then
            mode = "browser"
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
            vRPclient.notify(_source, {"~g~영상 재생 시작"})
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