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
-- 확장된 URL 리졸버 - nooo8.tv와 tvmon.site 지원
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
-- tvmon.site 전용 리졸버
-- ============================================================
local function ResolveTvmonUrl(url, cb)
    if not url or type(url) ~= "string" then
        cb(nil)
        return
    end
    
    local base = string.match(url, "^(https?://[^/]+)")
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        ["Referer"] = url,
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
    }
    
    print("[ptelevision] tvmon.site URL 분석 중: " .. url)
    
    PerformHttpRequest(url, function(statusCode, body, resHeaders)
        if statusCode ~= 200 or not body then
            print("[ptelevision] ❌ HTTP 요청 실패: " .. tostring(statusCode))
            cb(nil)
            return
        end
        
        -- tvmon.site iframe 패턴 찾기 (다양한 패턴 지원)
        local iframeSrc = 
            string.match(body, '<iframe[^>]+src="(https?://[^"]+)"') or
            string.match(body, "<iframe[^>]+src='(https?://[^']+)'") or
            string.match(body, 'data%-src="(https?://[^"]+)"') or
            string.match(body, "data%-src='(https?://[^']+)'")
        
        if iframeSrc then
            print("[ptelevision] ✅ iframe URL 추출: " .. iframeSrc)
            
            -- 임베드 페이지에서 직접 소스 추출 시도
            if string.find(iframeSrc, "fvideostream%.com") or 
               string.find(iframeSrc, "streamtape%.com") or
               string.find(iframeSrc, "doodstream%.com") or
               string.find(iframeSrc, "mixdrop%.") then
                ResolveEmbedToDirect(iframeSrc, url, function(direct)
                    if direct then
                        print("[ptelevision] ✅ 임베드에서 직접 소스 추출: " .. direct)
                        cb(direct)
                    else
                        print("[ptelevision] ⚠️ 직접 소스 추출 실패, iframe URL 사용")
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
-- nooo8.tv 전용 리졸버 (기존 코드)
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
-- 통합 URL 리졸버 - nooo8.tv와 tvmon.site 자동 감지
-- ============================================================
local function ResolveStreamingUrl(url, cb)
    if not url or type(url) ~= "string" then
        cb(nil)
        return
    end
    
    local lower = string.lower(url)
    
    -- tvmon.site 감지
    if string.find(lower, "tvmon%.site/") then
        print("[ptelevision] 🎬 tvmon.site 감지")
        ResolveTvmonUrl(url, cb)
        return
    end
    
    -- nooo8.tv 감지
    if string.find(lower, "nooo8%.tv/") then
        print("[ptelevision] 🎬 nooo8.tv 감지")
        ResolveNooo8Mp4(url, cb)
        return
    end
    
    -- 기타 URL은 nooo8 리졸버로 처리 (범용)
    ResolveNooo8Mp4(url, cb)
end

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
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        ["Accept-Language"] = "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
        ["Referer"] = url,
        ["Connection"] = "keep-alive"
    }
    
    print("[ptelevision] 📺 tvroom URL 분석 중: " .. url)
    
    PerformHttpRequest(url, function(statusCode, body, resHeaders)
        if statusCode ~= 200 or not body then
            print("[ptelevision] ❌ HTTP 요청 실패: " .. tostring(statusCode))
            cb(nil)
            return
        end
        
        print("[ptelevision] ✅ HTTP 응답 수신 (길이: " .. string.len(body) .. " bytes)")
        
        -- 디버깅: HTML 일부 출력 (처음 500자)
        local preview = string.sub(body, 1, 500)
        print("[ptelevision] 📄 HTML 미리보기:")
        print(preview)
        
        -- 방법 1: data-m3u8 속성 찾기 (따옴표 변형 모두 시도)
        local m3u8Url = string.match(body, 'data%-m3u8="([^"]+)"') or
                       string.match(body, "data%-m3u8='([^']+)'") or
                       string.match(body, 'data%-m3u8=([^%s>]+)')
        
        if m3u8Url then
            -- HTML 엔티티 디코딩
            m3u8Url = string.gsub(m3u8Url, "&amp;", "&")
            m3u8Url = string.gsub(m3u8Url, "&quot;", '"')
            m3u8Url = string.gsub(m3u8Url, "&#39;", "'")
            m3u8Url = string.gsub(m3u8Url, "&lt;", "<")
            m3u8Url = string.gsub(m3u8Url, "&gt;", ">")
            
            print("[ptelevision] ✅ data-m3u8 URL 추출: " .. m3u8Url)
            cb(m3u8Url)
            return
        end
        
        -- 방법 2: JavaScript 변수에서 찾기
        local jsM3u8 = string.match(body, 'm3u8["%s:=]+["\'](https?://[^"\']+%.m3u8[^"\']*)["\']')
        if jsM3u8 then
            jsM3u8 = string.gsub(jsM3u8, "\\/", "/")
            print("[ptelevision] ✅ JavaScript m3u8 URL 추출: " .. jsM3u8)
            cb(jsM3u8)
            return
        end
        
        -- 방법 3: player.bcbc.red 패턴 찾기 (사용자가 제공한 HTML에서 발견)
        local bcbcUrl = string.match(body, '(https?://player[^%s"\'<>]+%.m3u8[^%s"\'<>]*)')
        if bcbcUrl then
            bcbcUrl = string.gsub(bcbcUrl, "\\/", "/")
            bcbcUrl = string.gsub(bcbcUrl, "&amp;", "&")
            print("[ptelevision] ✅ player URL 추출: " .. bcbcUrl)
            cb(bcbcUrl)
            return
        end
        
        -- 방법 4: 모든 m3u8 URL 찾기 (가장 넓은 범위)
        local anyM3u8 = string.match(body, '(https?://[^%s"\'<>]+%.m3u8[^%s"\'<>]*)')
        if anyM3u8 then
            anyM3u8 = string.gsub(anyM3u8, "\\/", "/")
            anyM3u8 = string.gsub(anyM3u8, "&amp;", "&")
            print("[ptelevision] ✅ 일반 m3u8 URL 추출: " .. anyM3u8)
            cb(anyM3u8)
            return
        end
        
        -- 방법 5: video src 속성
        local videoSrc = string.match(body, '<video[^>]+src="([^"]+%.m3u8[^"]*)"') or
                        string.match(body, '<video[^>]+src="([^"]+%.mp4[^"]*)"') or
                        string.match(body, "<video[^>]+src='([^']+%.m3u8[^']*)'") or
                        string.match(body, "<video[^>]+src='([^']+%.mp4[^']*)'")
        
        if videoSrc then
            videoSrc = string.gsub(videoSrc, "&amp;", "&")
            print("[ptelevision] ✅ video src URL 추출: " .. videoSrc)
            cb(videoSrc)
            return
        end
        
        -- 방법 6: source 태그
        local sourceSrc = string.match(body, '<source[^>]+src="([^"]+%.m3u8[^"]*)"') or
                         string.match(body, '<source[^>]+src="([^"]+%.mp4[^"]*)"') or
                         string.match(body, "<source[^>]+src='([^']+%.m3u8[^']*)'") or
                         string.match(body, "<source[^>]+src='([^']+%.mp4[^']*)'")
        
        if sourceSrc then
            sourceSrc = string.gsub(sourceSrc, "&amp;", "&")
            print("[ptelevision] ✅ source src URL 추출: " .. sourceSrc)
            cb(sourceSrc)
            return
        end
        
        -- 디버깅: 'player', 'm3u8', 'video' 키워드 검색
        if string.find(body, "player") then
            print("[ptelevision] 🔍 'player' 키워드 발견")
        end
        if string.find(body, "m3u8") then
            print("[ptelevision] 🔍 'm3u8' 키워드 발견")
            -- m3u8 주변 텍스트 추출
            local pos = string.find(body, "m3u8")
            if pos then
                local context = string.sub(body, math.max(1, pos-100), math.min(string.len(body), pos+100))
                print("[ptelevision] 📄 m3u8 주변 컨텍스트:")
                print(context)
            end
        end
        if string.find(body, "video") then
            print("[ptelevision] 🔍 'video' 키워드 발견")
        end
        
        print("[ptelevision] ❌ tvroom: 비디오 소스를 찾을 수 없습니다")
        print("[ptelevision] 💡 전체 HTML을 확인하세요 (F8 콘솔)")
        cb(nil)
    end, "GET", "", headers)
end

local function ResolveTvroomApi(url, cb)
    -- URL에서 비디오 ID 추출
    local videoId = string.match(url, "id=(%d+)")
    if not videoId then
        print("[ptelevision] ❌ 비디오 ID를 찾을 수 없습니다")
        cb(nil)
        return
    end
    
    print("[ptelevision] 🎯 비디오 ID: " .. videoId)
    
    -- API 엔드포인트 시도 (추측)
    local apiUrls = {
        "https://tvroom11.org/api/video/" .. videoId,
        "https://tvroom11.org/api/video/info/" .. videoId,
        "https://tvroom11.org/video/stream/" .. videoId,
    }
    
    local function tryNextApi(index)
        if index > #apiUrls then
            print("[ptelevision] ❌ 모든 API 엔드포인트 실패")
            cb(nil)
            return
        end
        
        local apiUrl = apiUrls[index]
        print("[ptelevision] 🔍 API 시도 #" .. index .. ": " .. apiUrl)
        
        local headers = {
            ["User-Agent"] = "Mozilla/5.0",
            ["Accept"] = "application/json",
            ["Referer"] = url
        }
        
        PerformHttpRequest(apiUrl, function(statusCode, body, resHeaders)
            if statusCode == 200 and body then
                print("[ptelevision] ✅ API 응답: " .. body)
                
                -- JSON에서 m3u8 URL 찾기
                local m3u8Url = string.match(body, '"m3u8"%s*:%s*"([^"]+)"') or
                               string.match(body, '"url"%s*:%s*"([^"]+%.m3u8[^"]*)"') or
                               string.match(body, '"stream"%s*:%s*"([^"]+)"')
                
                if m3u8Url then
                    m3u8Url = string.gsub(m3u8Url, "\\/", "/")
                    print("[ptelevision] ✅ API에서 URL 추출: " .. m3u8Url)
                    cb(m3u8Url)
                    return
                end
            end
            
            -- 다음 API 시도
            tryNextApi(index + 1)
        end, "GET", "", headers)
    end
    
    tryNextApi(1)
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
    
    -- URL 타입 판별
    local lower = string.lower(url)
    
    -- tvroom 처리 (HTML 파싱 실패 시 API도 시도)
    if string.find(lower, "tvroom") then
        print("[ptelevision] 🎬 tvroom 리졸버 사용")
        
        ResolveTvroomUrl(url, function(resolved)
            if resolved then
                -- HTML 파싱 성공
                print("[ptelevision] ✅ URL 리졸빙 성공 (HTML)")
                print("[ptelevision] 📺 재생 모드: play")
                print("[ptelevision] 🔗 최종 URL: " .. resolved)
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                SetTelevision(data.coords, "ptv_status", {
                    type = "play",
                    url = resolved,
                    time = 0,
                    state = "playing"
                }, true)
                
                local user_id = vRP.getUserId({_source})
                if user_id then
                    vRPclient.notify(_source, {"~g~영상 재생 시작"})
                end
            else
                -- HTML 파싱 실패, API 시도
                print("[ptelevision] ⚠️ HTML 파싱 실패, API 시도...")
                
                ResolveTvroomApi(url, function(apiResolved)
                    if apiResolved then
                        print("[ptelevision] ✅ URL 리졸빙 성공 (API)")
                        print("[ptelevision] 📺 재생 모드: play")
                        print("[ptelevision] 🔗 최종 URL: " .. apiResolved)
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        
                        SetTelevision(data.coords, "ptv_status", {
                            type = "play",
                            url = apiResolved,
                            time = 0,
                            state = "playing"
                        }, true)
                        
                        local user_id = vRP.getUserId({_source})
                        if user_id then
                            vRPclient.notify(_source, {"~g~영상 재생 시작 (API)"})
                        end
                    else
                        -- 모든 방법 실패
                        print("[ptelevision] ❌ URL 리졸빙 완전 실패")
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        
                        local user_id = vRP.getUserId({_source})
                        if user_id then
                            vRPclient.notify(_source, {"~r~영상 URL 추출에 실패했습니다. 다른 URL을 시도하세요."})
                        end
                    end
                end)
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
