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
            if (t._callback) {
                t._callback()
                t._callback = null
            }
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

