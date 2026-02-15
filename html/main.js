var player;
var playerData;
var lastSyncAt = 0;
var lastSyncState = null;
var webVolume = 1.0;
var hls = null;

$(document).ready(function() {
    $.post("https://"+GetParentResourceName()+"/pageLoaded", JSON.stringify({}))
    startWebVolumeControl();
    startPlayerSync();
    observeMediaElements();
})

// 웹 브라우저의 모든 비디오/오디오 요소 볼륨 조절
function setWebBrowserVolume(volume) {
    webVolume = volume;
    
    var videos = document.getElementsByTagName('video');
    for(var i = 0; i < videos.length; i++) {
        videos[i].volume = volume;
    }
    
    var audios = document.getElementsByTagName('audio');
    for(var i = 0; i < audios.length; i++) {
        audios[i].volume = volume;
    }
    
    var iframes = document.getElementsByTagName('iframe');
    for(var i = 0; i < iframes.length; i++) {
        try {
            var iframeDoc = iframes[i].contentDocument || iframes[i].contentWindow.document;
            var iframeVideos = iframeDoc.getElementsByTagName('video');
            for(var j = 0; j < iframeVideos.length; j++) {
                iframeVideos[j].volume = volume;
            }
            var iframeAudios = iframeDoc.getElementsByTagName('audio');
            for(var j = 0; j < iframeAudios.length; j++) {
                iframeAudios[j].volume = volume;
            }
        } catch(e) {
            // Cross-origin iframe은 접근 불가
        }
    }
}

function startWebVolumeControl() {
    setInterval(function() {
        if(webVolume !== 1.0) {
            setWebBrowserVolume(webVolume);
        }
    }, 1000);
}

function observeMediaElements() {
    var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if(node.tagName === 'VIDEO' || node.tagName === 'AUDIO') {
                    node.volume = webVolume;
                }
                if(node.tagName === 'IFRAME') {
                    setTimeout(function() {
                        try {
                            var iframeDoc = node.contentDocument || node.contentWindow.document;
                            var videos = iframeDoc.getElementsByTagName('video');
                            for(var i = 0; i < videos.length; i++) {
                                videos[i].volume = webVolume;
                            }
                        } catch(e) {}
                    }, 1000);
                }
            });
        });
    });
    
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
}

function IsDirectMediaUrl(url) {
    if (!url) return false;
    return /\.mp4(\?|$)/i.test(url) || /\.m3u8(\?|$)/i.test(url);
}

function GetURLID(link) {
    if (link == null) return;
    let url = link.toString();
    var regExp = /^.*(youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
    var match = url.match(regExp);
    if (match && match[2].length == 11) {
        return {type: "youtube", id: match[2]};
    } 
    else if (url.split("twitch.tv/").length > 1) {
        return {type: "twitch", id: url.split("twitch.tv/")[1]};
    }
    else if (IsDirectMediaUrl(url)) {
        return {type: "file", url: url};
    }
    return {type: "browser", url: url};
}

function ChannelDisplay(channel, channelFound) {
    if (channel) {
        var temp = 'CH<span style="font-size: 18pt !important;"> </span>'
        if (channel > 9) {
            temp += channel
        }
        else {
            temp += ("0" + channel)
        }
        $("#overlay span").show()
        $("#overlay span").html(temp)
    }
    else {
        $("#overlay span").show()
        $("#overlay span").html("")
    }
    if (channelFound) {
        $("#tv-container").hide()
    }
    else {
        $("#tv-container").show()
    }
}

function SetVideo(video_data) {
    var url = video_data.url;
    var channel = video_data.channel;
    
    // video_data.type이 명시적으로 있으면 그것을 사용, 없으면 URL에서 추측
    var inferred = GetURLID(url);
    var data = video_data.type ? {type: video_data.type, url: url} : inferred;
    if (data.type == "play") {
        data.type = "file";
    }
    if (data.type == "browser" && IsDirectMediaUrl(url)) {
        data.type = "file";
    }
    
    playerData = data
    
    // 기존 플레이어 정리
    if (player) {
        if (player.destroy) {
            player.destroy()
        }
        player = null;
    }
    if (hls) {
        try { hls.destroy(); } catch (e) {}
        hls = null;
    }
    
    // twitch-embed div 초기화
    $("#twitch-embed").empty();
    
    if (data) {
        if (data.type == "youtube") {
            player = new YT.Player('twitch-embed', {
                height: '100%',
                width: '100%',
                videoId: data.id,
                playerVars: {
                    'playsinline': 1,
                    'autoplay': 1,
                    'controls': 1,
                    'rel': 0
                },
                events: {
                    'onReady': function(event) {
                        if (video_data.time !== undefined && video_data.time !== null) {
                            event.target.seekTo(video_data.time)
                        }
                        if (video_data.state == "paused") {
                            event.target.pauseVideo();
                        } else {
                            event.target.playVideo();
                        }
                        event.target.unMute();
                    },
                    'onStateChange': function(event) {
                        if (event.data == YT.PlayerState.PLAYING) {
                            event.target.unMute();
                            sendPlayerSync("playing", event.target.getCurrentTime(), true);
                        }
                        else if (event.data == YT.PlayerState.PAUSED) {
                            sendPlayerSync("paused", event.target.getCurrentTime(), true);
                        }
                    }
                }
            });
        }
        else if (data.type == "twitch") {
            player = new Twitch.Player("twitch-embed", {
                width: "100%",
                height: "100%",
                channel: data.id,
                volume: 1.0,
                autoplay: true,
                muted: false
            });
            player.addEventListener(Twitch.Embed.VIDEO_READY, function() {
                player.setMuted(false);
                if (video_data.state == "paused" && player.pause) {
                    player.pause();
                } else if (player.play) {
                    player.play();
                }
            });
        }
        else if (data.type == "file") {
            // 직접 비디오(mp4/m3u8) 재생
            console.log("[TV] 파일 재생 모드:", data.url);
            
            var video = $('<video>', {
                controls: true,
                autoplay: true,
                muted: false,
                playsinline: true,
                css: {
                    position: 'absolute',
                    top: '0',
                    left: '0',
                    width: '100%',
                    height: '100%',
                    background: '#000'
                }
            });
            
            $("#twitch-embed").html(video);
            
            var el = video.get(0);
            if (/\.m3u8(\?|$)/i.test(data.url) && window.Hls && Hls.isSupported()) {
                hls = new Hls();
                hls.loadSource(data.url);
                hls.attachMedia(el);
            } else {
                el.src = data.url;
            }
            
            el.volume = webVolume;

            if (video_data.time !== undefined && video_data.time !== null) {
                var startTime = video_data.time;
                el.addEventListener('loadedmetadata', function() {
                    try { el.currentTime = startTime; } catch (e) {}
                });
            }
            if (video_data.state == "paused") {
                el.pause();
            } else {
                var p = el.play();
                if (p && p.catch) { p.catch(function() {}); }
            }
        }
        else if (data.type == "browser") {
            // 브라우저 모드: iframe으로 직접 로드
            console.log("[TV] 브라우저 모드 로딩:", data.url);
            
            // iframe을 동적으로 생성
            var iframe = $('<iframe>', {
                src: data.url,
                frameborder: '0',
                allowfullscreen: true,
                scrolling: 'no',
                css: {
                    position: 'absolute',
                    top: '0',
                    left: '0',
                    width: '100%',
                    height: '100%',
                    border: 'none'
                }
            });
            
            // iframe 속성 추가
            iframe.attr('allow', 'autoplay; fullscreen; picture-in-picture');
            iframe.attr('sandbox', 'allow-same-origin allow-scripts allow-forms allow-popups allow-presentation');
            
            $("#twitch-embed").html(iframe);
            
            console.log("[TV] iframe 삽입 완료");
            
            // iframe 내부 볼륨 조절 시도
            setTimeout(function() {
                console.log("[TV] iframe 볼륨 설정 시도");
                setWebBrowserVolume(webVolume);
            }, 2000);
            
            // iframe 로드 이벤트
            iframe.on('load', function() {
                console.log("[TV] iframe 로드 완료");
            });
            
            iframe.on('error', function() {
                console.error("[TV] iframe 로드 실패");
            });
        }
        
        $("#overlay span").hide()
        $("#tv-container").hide()
    }
    
    if (channel) {
        ChannelDisplay(channel, url)
    }
}

function SetVolume(volume) {
    if (player && playerData && player.setVolume) {
        if (playerData.type == "twitch") {
            player.setMuted(false);
            player.setVolume(volume / 100.0);
        }
        else if (playerData.type == "youtube") {
            player.unMute();
            player.setVolume(volume);
        }
    }
    if (playerData && playerData.type == "file") {
        var el = $("#twitch-embed video").get(0);
        if (el) {
            el.volume = volume / 100.0;
        }
    }
    
    setWebBrowserVolume(volume / 100.0);
}

function ShowNotification(channel, data) {
    $("#tv-container").addClass("notify")
    $("#tv-container div").addClass("notify")
    var display = $('#tv-container').is(':visible')
    $('#tv-container').show()
    $("#tv-container div").html("Channel #" + channel + (data ? (" ("+data.name+")") : "") + " is now " + (data ? "live!" : "offline."))

    setTimeout(function() {
        $("#tv-container").removeClass("notify")
        $("#tv-container div").removeClass("notify")
        $("#tv-container div").html("NO SIGNAL")
        if (!display) {
            $('#tv-container').hide()
        }
    }, 3500)
}

window.addEventListener("message", function(ev) {
    if (ev.data.setVideo) {
        SetVideo(ev.data.data)
    }
    else if (ev.data.setVolume) {
        SetVolume(ev.data.data)
    }
    else if (ev.data.showNotification) {
        ShowNotification(ev.data.channel, ev.data.data)
    }
    else if (ev.data.syncPlayer) {
        ApplySync(ev.data.data)
    }
    else if (ev.data.seekBy !== undefined && ev.data.seekBy !== null) {
        var delta = parseFloat(ev.data.seekBy);
        if (!playerData) return;
        try {
            if (playerData.type == "file") {
                var el = $("#twitch-embed video").get(0);
                if (el) {
                    var target = (el.currentTime || 0) + delta;
                    if (target < 0) target = 0;
                    el.currentTime = target;
                    sendPlayerSync(el.paused ? "paused" : "playing", el.currentTime, true);
                }
            } else if (playerData.type == "youtube" && player && player.seekTo) {
                var cur = player.getCurrentTime ? player.getCurrentTime() : 0;
                var t = cur + delta;
                if (t < 0) t = 0;
                player.seekTo(t, true);
                sendPlayerSync(null, t, true);
            } else if (playerData.type == "twitch" && player && player.seek) {
                var cur2 = player.getCurrentTime ? player.getCurrentTime() : 0;
                var t2 = cur2 + delta;
                if (t2 < 0) t2 = 0;
                player.seek(t2);
                sendPlayerSync(null, t2, true);
            }
        } catch (e) {}
    }
    else if (ev.data.seekTo !== undefined && ev.data.seekTo !== null) {
        var tAbs = parseFloat(ev.data.seekTo);
        if (!playerData) return;
        try {
            if (playerData.type == "file") {
                var el2 = $("#twitch-embed video").get(0);
                if (el2) {
                    if (tAbs < 0) tAbs = 0;
                    el2.currentTime = tAbs;
                    sendPlayerSync(el2.paused ? "paused" : "playing", el2.currentTime, true);
                }
            } else if (playerData.type == "youtube" && player && player.seekTo) {
                if (tAbs < 0) tAbs = 0;
                player.seekTo(tAbs, true);
                sendPlayerSync(null, tAbs, true);
            } else if (playerData.type == "twitch" && player && player.seek) {
                if (tAbs < 0) tAbs = 0;
                player.seek(tAbs);
                sendPlayerSync(null, tAbs, true);
            }
        } catch (e) {}
    }
})

$(document).ready(function() {
    ChannelDisplay()
})

function sendPlayerSync(state, time, force) {
    var now = Date.now();
    if (!force) {
        if ((now - lastSyncAt) < 1000 && state === lastSyncState) {
            return;
        }
    }
    lastSyncAt = now;
    if (state !== undefined && state !== null) {
        lastSyncState = state;
    }
    $.post("https://"+GetParentResourceName()+"/playerSync", JSON.stringify({
        type: playerData ? playerData.type : null,
        state: state,
        time: time,
        force: !!force
    }));
}

function startPlayerSync() {
    setInterval(function() {
        if (!player || !playerData) return;
        if (playerData.type == "browser") return; // 브라우저 모드는 동기화 안함
        
        try {
            if (playerData.type == "youtube") {
                if (player.getCurrentTime) {
                    var t = player.getCurrentTime();
                    var st = null;
                    if (player.getPlayerState) {
                        var ytState = player.getPlayerState();
                        if (ytState == YT.PlayerState.PLAYING) st = "playing";
                        else if (ytState == YT.PlayerState.PAUSED) st = "paused";
                    }
                    sendPlayerSync(st, t, false);
                }
            } else if (playerData.type == "twitch") {
                var t2 = null;
                if (player.getCurrentTime) {
                    t2 = player.getCurrentTime();
                }
                var st2 = null;
                if (player.getPaused) {
                    st2 = player.getPaused() ? "paused" : "playing";
                } else if (player.isPaused) {
                    st2 = player.isPaused() ? "paused" : "playing";
                }
                sendPlayerSync(st2, t2, false);
            } else if (playerData.type == "file") {
                var el = $("#twitch-embed video").get(0);
                if (el) {
                    var st3 = el.paused ? "paused" : "playing";
                    sendPlayerSync(st3, el.currentTime || 0, false);
                }
            }
        } catch (e) {
        }
    }, 1000);
}

function ApplySync(data) {
    if (!data || !player || !playerData) return;
    if (playerData.type == "browser") return; // 브라우저 모드는 동기화 안함
    if (data.type && playerData.type && data.type != playerData.type) return;
    
    if (playerData.type == "file") {
        var el = $("#twitch-embed video").get(0);
        if (!el) return;
        if (data.time != null) {
            try {
                if (Math.abs(el.currentTime - data.time) > 0.75) {
                    el.currentTime = data.time;
                }
            } catch (e) {}
        }
        if (data.state == "playing") {
            var p = el.play();
            if (p && p.catch) { p.catch(function() {}); }
        } else if (data.state == "paused") {
            el.pause();
        }
        return;
    }

    try {
        var current = null;
        if (player.getCurrentTime) {
            current = player.getCurrentTime();
        }
        if (data.time != null && current != null) {
            if (Math.abs(current - data.time) > 1.5) {
                if (player.seekTo) {
                    player.seekTo(data.time, true);
                } else if (player.seek) {
                    player.seek(data.time);
                }
            }
        } else if (data.time != null) {
            if (player.seekTo) {
                player.seekTo(data.time, true);
            } else if (player.seek) {
                player.seek(data.time);
            }
        }
        if (data.state == "playing") {
            if (player.playVideo) player.playVideo();
            else if (player.play) player.play();
        } else if (data.state == "paused") {
            if (player.pauseVideo) player.pauseVideo();
            else if (player.pause) player.pause();
        }
    } catch (e) {
    }
}
