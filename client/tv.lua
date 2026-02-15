TelevisionsLocal = {}

local function GetUrlMode(url)
    if not url then return "browser" end
    local lower = string.lower(url)
    if string.find(lower, "youtu%.be/") or string.find(lower, "youtube%.com/") then
        return "play"
    end
    if string.find(lower, "twitch%.tv/") then
        return "play"
    end
    return "browser"
end

local function IsResolverTarget(url)
    if not url then return false end
    local lower = string.lower(url)
    if string.find(lower, "nooo8%.tv/") then
        return true
    end
    if string.find(lower, "tvroom11%.org/") then
        return true
    end

    return false
end

function SetChannel(index)
    TriggerServerEvent("ptelevision:event", CURRENT_SCREEN, "ptv_status", {
        type = "play",
        channel = index,
    })
end

function GetChannelList()
    if not Channels then return {} end
    local channel_list = {}
    local menu_list = {}
    local current = 1
    local screen = CURRENT_SCREEN
    local ent = screen.entity
    local _, status = GetTelevision(screen.coords)
    local channel = nil
    if (status) then 
        channel = status.channel
    end
    for index,value in pairs(Channels) do 
        table.insert(channel_list, {index = index, url = value.url})
        table.insert(menu_list, "채널 #" .. index .. " (".. value.name ..")")
        if channel ~= nil and channel == index then 
            current = #channel_list
        end
    end
    return {list = channel_list, display = menu_list, current = current}
end

function BroadcastMenu() 
    local _source = GetPlayerServerId(PlayerId())
    for k,v in pairs(Channels) do 
        if (v.source == _source) then 
            TriggerServerEvent("ptelevision:broadcast", nil)
            return
        end
    end 
    local input = lib.inputDialog('라이브 방송', {'채널 이름:', '방송 URL:'})
    if (input[1] and input[2]) then 
        TriggerServerEvent("ptelevision:broadcast", {name = input[1], url = input[2]})
    end
end 

function WebBrowserMenu()
    lib.hideMenu()
    local input = lib.inputDialog('웹 브라우저', {'URL:'})

    if input then 
        local url = input[1]
        if IsResolverTarget(url) then
            TriggerServerEvent("ptelevision:resolveUrl", CURRENT_SCREEN, url)
            Citizen.Wait(300)
            OpenTVMenu()
            return
        end
        local mode = GetUrlMode(url)
        TriggerServerEvent("ptelevision:event", CURRENT_SCREEN, "ptv_status", {
            type = mode,
            url = url
        })
    end
    Citizen.Wait(300) 
    OpenTVMenu() 
end

function VideoMenu()
    lib.hideMenu()
    local input = lib.inputDialog('비디오 재생기', {'URL:'})
    if input then 
        local url = input[1]
        if IsResolverTarget(url) then
            TriggerServerEvent("ptelevision:resolveUrl", CURRENT_SCREEN, url)
            Citizen.Wait(300)
            OpenTVMenu()
            return
        end
        local mode = GetUrlMode(url)
        TriggerServerEvent("ptelevision:event", CURRENT_SCREEN, "ptv_status", {
            type = mode,
            url = url
        })
    end
    Citizen.Wait(300) 
    OpenTVMenu()
end

function VolumeMenu()
    lib.hideMenu()
    
    local screen = CURRENT_SCREEN
    local _, status = GetTelevision(screen.coords)
    local contentType = "unknown"
    
    if status and status["ptv_status"] then
        contentType = status["ptv_status"].type
    end
    
    local warningMsg = ""
    if contentType == "browser" then
        warningMsg = "\n✅ 웹 브라우저의 HTML5 비디오/오디오 볼륨이 조절됩니다."
    end
    
    local input = lib.inputDialog('볼륨 설정' .. warningMsg, {
        '볼륨 (0-100):',
        {
            type = 'checkbox',
            label = '모든 사람에게 적용 (관리자만)',
            checked = false
        }
    })
    
    if input and tonumber(input[1]) then 
        local coords = CURRENT_SCREEN.coords
        local applyToAll = input[2] or false
        
        if applyToAll then
            TriggerServerEvent("ptelevision:setGlobalVolume", CURRENT_SCREEN, tonumber(input[1])/100)
        else
            SetVolume(coords, tonumber(input[1])/100)
        end
    end
    Citizen.Wait(300) 
    OpenTVMenu()
end

function OpenTVMenu() 
    local screen = CURRENT_SCREEN
    if not screen then return end
    lib.hideMenu()
    local ChannelList = GetChannelList()
    lib.registerMenu({
        id = 'ptelevision-menu',
        title = '텔레비전',
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
            if (selected == 3) then 
                SetChannel(ChannelList.list[scrollIndex].index)
            end
        end,
        onSelected = function(selected, scrollIndex, args) 
        end,
        onClose = function(keyPressed)
        end,
        options = {
            {label = '비디오', description = '화면에서 비디오 또는 스트림 재생.'},
            {label = '웹 브라우저', description = 'TV로 웹에 접근합니다.'},
            {label = 'TV 채널', values = ChannelList.display, description = '샌 안드레아스의 라이브 TV 채널!', defaultIndex = ChannelList.current},
            {label = '화면과 상호작용', description = '화면 요소를 제어합니다.'},
            {label = '볼륨 설정', description = 'TV의 음량을 설정합니다.'},
            {label = '메뉴 닫기', close = true},
        }
    }, function(selected, scrollIndex, args)
        if (selected == 1) then
            VideoMenu()
        elseif (selected == 2) then
            WebBrowserMenu()
        elseif (selected == 3) then 
            SetChannel(ChannelList.list[scrollIndex].index)
            OpenTVMenu()
        elseif selected == 4 then 
            SetInteractScreen(true)
        elseif selected == 5 then 
            VolumeMenu()
        end
    end)
    lib.showMenu('ptelevision-menu')
end

function PlayBrowser(data)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("[ptelevision-client] 🌐 PlayBrowser 호출됨!")
    print("[ptelevision-client] 📍 URL: " .. tostring(data.url))
    print("[ptelevision-client] 🔍 DUI 객체: " .. tostring(duiObj))
    
    if not duiObj then
        print("[ptelevision-client] ❌ 오류: DUI 객체가 없습니다!")
        return
    end
    
    local waitCount = 0
    while not IsDuiAvailable(duiObj) do 
        waitCount = waitCount + 1
        print("[ptelevision-client] ⏳ DUI 대기 중... (" .. waitCount .. ")")
        Wait(10) 
        if waitCount > 100 then
            print("[ptelevision-client] ❌ DUI 타임아웃!")
            return
        end
    end
    
    print("[ptelevision-client] ✅ DUI 사용 가능!")
    
    local messageData = {
        setVideo = true,
        data = {
            url = data.url,
            type = "browser"
        }
    }
    
    local jsonMessage = json.encode(messageData)
    print("[ptelevision-client] 📤 전송할 메시지: " .. jsonMessage)
    
    SendDuiMessage(duiObj, jsonMessage)
    
    print("[ptelevision-client] ✅ 브라우저 모드 메시지 전송 완료!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

function PlayVideo(data)
    print("[ptelevision-client] ▶️ PlayVideo 호출")
    print("[ptelevision-client] 📍 URL: " .. tostring(data.url))
    
    while not IsDuiAvailable(duiObj) do Wait(10) end
    if (getDuiURL() ~= DEFAULT_URL) then 
        waitForLoad = true
        setDuiURL(DEFAULT_URL)
        while waitForLoad do Wait(10) end
    end
    SendDuiMessage(duiObj, json.encode({
        setVideo = true,
        data = data
    }))
    print("[ptelevision-client] ✅ PlayVideo 메시지 전송 완료")
end

function ResetDisplay()
    setDuiURL(DEFAULT_URL)
end

function GetTelevisionLocal(coords)
    for k,v in pairs(TelevisionsLocal) do 
        if #(v3(v.coords) - v3(coords)) < 0.01 then
            return k, v
        end
    end
end

function SetTelevisionLocal(coords, key, value)
    local index, data = GetTelevisionLocal(coords)
    if (index ~= nil) then 
        if (TelevisionsLocal[index] == nil) then 
            TelevisionsLocal[index] = {}
        end
        TelevisionsLocal[index][key] = value
    else
        index = GetGameTimer()
        while TelevisionsLocal[index] do 
            index = index + 1
            Citizen.Wait(0)
        end
        if (TelevisionsLocal[index] == nil) then 
            TelevisionsLocal[index] = {}
        end
        TelevisionsLocal[index][key] = value
    end
    TelevisionsLocal[index].coords = coords
    return index
end

RegisterNetEvent("ptelevision:event", function(data, index, key, value) 
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("[ptelevision-client] 🎯 ptelevision:event 수신!")
    print("[ptelevision-client] 🔑 key: " .. tostring(key))
    print("[ptelevision-client] 📊 value type: " .. type(value))
    if type(value) == "table" then
        print("[ptelevision-client] 📦 value.type: " .. tostring(value.type))
        print("[ptelevision-client] 🔗 value.url: " .. tostring(value.url))
    end
    
    Televisions = data
    local tvData = Televisions[index]
    local screen = CURRENT_SCREEN
    
    if not screen then
        print("[ptelevision-client] ⚠️ CURRENT_SCREEN이 없습니다")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        return
    end
    
    -- 볼륨 동기화 처리
    if key == "volume" and screen and #(v3(screen.coords) - v3(tvData.coords)) < 0.001 then
        print("[ptelevision-client] 🔊 볼륨 이벤트")
        SetVolume(screen.coords, value)
        SetTelevisionLocal(tvData.coords, "start_time", GetGameTimer())
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        return
    end
    
    -- ptv_status 이벤트 처리
    if key == "ptv_status" and screen and #(v3(screen.coords) - v3(tvData.coords)) < 0.001 then 
        print("[ptelevision-client] 📺 ptv_status 이벤트 처리 시작")
        
        local tvIndex, tvStatus = GetTelevision(screen.coords)
        if (tvIndex) then 
            local event = value
            
            print("[ptelevision-client] 🎬 event.type: " .. tostring(event.type))
            print("[ptelevision-client] 🔗 event.url: " .. tostring(event.url))
            
            if (event.type == "play") then 
                local videoData = { url = event.url }
                if (event.channel) then
                    videoData = Channels[event.channel]
                    videoData.channel = event.channel
                end
                print("[ptelevision-client] ▶️ PlayVideo 호출 예정")
                PlayVideo(videoData)
            elseif (event.type == "browser") then 
                print("[ptelevision-client] 🌐 PlayBrowser 호출 예정")
                PlayBrowser({ url = event.url })
            else
                print("[ptelevision-client] ❓ 알 수 없는 타입: " .. tostring(event.type))
            end 
        else
            print("[ptelevision-client] ⚠️ tvIndex를 찾을 수 없습니다")
        end
    end
    
    SetTelevisionLocal(tvData.coords, "start_time", GetGameTimer())
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end)

RegisterNetEvent("ptelevision:broadcast", function(data, index)
    Channels = data
    if getDuiURL() == DEFAULT_URL then 
        local screen = CURRENT_SCREEN
        local tvObj = screen.entity
        local _, status = GetTelevision(screen.coords)
        if (status and status.channel == index and data[index] == nil) then 
            ResetDisplay()
            Citizen.Wait(10)
        end
        SendDuiMessage(duiObj, json.encode({
            showNotification = true,
            channel = index,
            data = data[index]
        }))
    end
end)

RegisterNetEvent("ptelevision:inputSync", function(sourceId, payload)
    if not payload or not payload.coords then return end
    local mySource = GetPlayerServerId(PlayerId())
    if sourceId == mySource then return end
    local screen = CURRENT_SCREEN
    if not screen or #(v3(screen.coords) - v3(payload.coords)) > 0.001 then return end
    if not duiObj then return end

    if payload.type == "move" then
        SendDuiMouseMove(duiObj, payload.x, payload.y)
    elseif payload.type == "wheel" then
        SendDuiMouseWheel(duiObj, payload.dy or 0, payload.dx or 0)
    elseif payload.type == "down" then
        SendDuiMouseDown(duiObj, payload.button or "left")
    elseif payload.type == "up" then
        SendDuiMouseUp(duiObj, payload.button or "left")
    end
end)

RegisterNetEvent("ptelevision:openMenu", function(hasPermission)
    if hasPermission then
        OpenTVMenu()
    end
end)

RegisterNetEvent("ptelevision:openBroadcast", function(hasPermission)
    if hasPermission then
        BroadcastMenu()
    end
end)

RegisterCommand('tv', function()
    TriggerServerEvent("ptelevision:checkPermission")
end)

RegisterCommand("broadcast", function(source, args, raw)
    TriggerServerEvent("ptelevision:checkBroadcastPermission")
end)