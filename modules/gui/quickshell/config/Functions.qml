pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    //SetTimeout
    property var timerPool: []
    function getTimer() {
        for (var i = 0; i < timerPool.length; i++) {
            if (!timerPool[i].running) return timerPool[i]
        }
        var t = Qt.createQmlObject(
            'import QtQuick 2.0; Timer { repeat: false; property var _callback: null }',
            root
        );
        t.triggered.connect(function() {
            var cb = t._callback   // 先取出來
            t._callback = null     // 先清空，讓這顆 timer 可以被下一次重用
            if (cb) cb()           // 最後才執行，就算 cb() 裡面又搶到同一顆 timer 也不會被清掉
        });
        timerPool.push(t)
        return t
    }
    function setTimeout(cb, delayTime) {
        var t = getTimer()
        t._callback = cb
        t.interval = delayTime
        t.start()
        return t
    }
    //SetTimeout

    //FetchWithDelayRetry
    function fetchWithDelayRetry(url, delay) {
        return new Promise(function(resolve) {
            let req = new XMLHttpRequest();

            function attempt() {
                req.onreadystatechange = function() {
                    if (req.readyState === XMLHttpRequest.DONE) {
                        if (req.status === 200) {
                            resolve(req.response);
                        } else {
                            setTimeout(attempt, delay);
                        }
                    }
                }
                req.open("GET", url);
                req.send();
            }

            attempt();
        });
    }
    //FetchWithDelayRetry

    //CurrentPath
    function currentPath(baseUrl) {
        return function (dir) {
            return baseUrl.toString().replace(/^file:\/\//, "") + dir
        }
    }
    //CurrentPath
    // Usage:     property var currentPath: Functions.currentPath(Qt.resolvedUrl("."))
}

