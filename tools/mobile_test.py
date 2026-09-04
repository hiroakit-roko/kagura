#!/usr/bin/env python3
"""ヘッドレス Chrome を iPhone 相当（タッチあり・縦画面・DPR 3）でエミュレートし、Web ビルドを開いて
スクリーンショットとタッチ操作の検証を行う。実機が無いときのスマホ表示・操作の確認用。

  python3 tools/mobile_test.py http://127.0.0.1:8792/index.html out_dir [--autoplay]

出力: out_dir/01_title.png（読み込み後）, 02_after_tap.png（はじめる をタップ）, 03_drag.png（なぞって移動）, console.txt
"""
import asyncio, base64, json, os, subprocess, sys, time, urllib.request

import websockets

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT = 9333
W, H, DPR = 393, 852, 3   # iPhone 16 Pro 相当（CSS px）
UA = ("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) "
      "CriOS/129.0.0.0 Mobile/15E148 Safari/604.1")


class CDP:
    def __init__(self, ws):
        self.ws = ws; self.i = 0; self.pending = {}; self.events = []

    async def send(self, method, **params):
        self.i += 1
        await self.ws.send(json.dumps({"id": self.i, "method": method, "params": params}))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == self.i:
                if "error" in msg: raise RuntimeError(msg["error"])
                return msg.get("result", {})
            if "method" in msg: self.events.append(msg)

    async def pump(self, sec):
        end = time.time() + sec
        while time.time() < end:
            try:
                msg = json.loads(await asyncio.wait_for(self.ws.recv(), timeout=max(0.05, end - time.time())))
                if "method" in msg: self.events.append(msg)
            except asyncio.TimeoutError:
                break


async def shot(cdp, path):
    r = await cdp.send("Page.captureScreenshot", format="png")
    open(path, "wb").write(base64.b64decode(r["data"]))
    print("shot ->", path)


async def tap(cdp, x, y):
    pts = [{"x": x, "y": y, "radiusX": 2, "radiusY": 2, "force": 1}]
    await cdp.send("Input.dispatchTouchEvent", type="touchStart", touchPoints=pts)
    await asyncio.sleep(0.08)
    await cdp.send("Input.dispatchTouchEvent", type="touchEnd", touchPoints=[])


async def drag(cdp, x0, y0, x1, y1, steps=20, dur=0.6):
    await cdp.send("Input.dispatchTouchEvent", type="touchStart", touchPoints=[{"x": x0, "y": y0}])
    for i in range(1, steps + 1):
        k = i / steps
        await cdp.send("Input.dispatchTouchEvent", type="touchMove", touchPoints=[{"x": x0 + (x1 - x0) * k, "y": y0 + (y1 - y0) * k}])
        await asyncio.sleep(dur / steps)
    await cdp.send("Input.dispatchTouchEvent", type="touchEnd", touchPoints=[])


async def main(url, out, autoplay):
    os.makedirs(out, exist_ok=True)
    prof = os.path.join(out, "profile")
    proc = subprocess.Popen([CHROME, "--headless=new", f"--remote-debugging-port={PORT}", f"--user-data-dir={prof}",
                             "--no-first-run", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                             "--autoplay-policy=no-user-gesture-required", "about:blank"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                ver = json.load(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/version")); break
            except Exception:
                await asyncio.sleep(0.2)
        async with websockets.connect(ver["webSocketDebuggerUrl"], max_size=None) as bws:
            b = CDP(bws)
            t = await b.send("Target.createTarget", url="about:blank")
            tid = t["targetId"]
        info = json.load(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json"))
        wsurl = [p for p in info if p.get("id") == tid][0]["webSocketDebuggerUrl"]
        async with websockets.connect(wsurl, max_size=None) as ws:
            cdp = CDP(ws)
            await cdp.send("Page.enable"); await cdp.send("Runtime.enable"); await cdp.send("Log.enable")
            await cdp.send("Emulation.setUserAgentOverride", userAgent=UA, platform="iPhone")
            await cdp.send("Emulation.setDeviceMetricsOverride", width=W, height=H, deviceScaleFactor=DPR, mobile=True)
            await cdp.send("Emulation.setTouchEmulationEnabled", enabled=True, maxTouchPoints=5)
            await cdp.send("Emulation.setEmitTouchEventsForMouse", enabled=True, configuration="mobile")
            await cdp.send("Page.navigate", url=url + ("&autoplay" if autoplay else ""))
            await cdp.pump(40)
            await shot(cdp, os.path.join(out, "01_title.png"))
            # はじめる（画面下の枡）をタップ → 開幕の物語 → タップで進む
            await tap(cdp, W * 0.5, H * 0.845)
            await cdp.pump(3)
            await shot(cdp, os.path.join(out, "02_story.png"))
            await tap(cdp, W * 0.5, H * 0.5)
            await cdp.pump(3)
            # 使い魔の 1 枚目をタップ（3 枚並び：左）
            await tap(cdp, W * 0.2, H * 0.36)
            await cdp.pump(3)
            await shot(cdp, os.path.join(out, "03_play.png"))
            # なぞって移動（左へ）→ 自機が左に動くか
            await drag(cdp, W * 0.5, H * 0.6, W * 0.2, H * 0.6)
            await cdp.pump(1.0)
            await shot(cdp, os.path.join(out, "04_drag_left.png"))
            # フリック（疾走）
            await drag(cdp, W * 0.3, H * 0.6, W * 0.6, H * 0.6, steps=4, dur=0.12)
            await cdp.pump(0.6)
            await shot(cdp, os.path.join(out, "05_flick.png"))
            await cdp.pump(10)
            await shot(cdp, os.path.join(out, "06_later.png"))
            with open(os.path.join(out, "console.txt"), "w") as f:
                for e in cdp.events:
                    m = e["method"]
                    if m == "Runtime.consoleAPICalled":
                        f.write(" ".join(str(a.get("value", a.get("description", ""))) for a in e["params"]["args"]) + "\n")
                    elif m == "Runtime.exceptionThrown":
                        f.write("EXC " + json.dumps(e["params"]["exceptionDetails"])[:500] + "\n")
                    elif m == "Log.entryAdded":
                        f.write("LOG " + e["params"]["entry"].get("text", "")[:300] + "\n")
            print("done")
    finally:
        proc.terminate()


if __name__ == "__main__":
    url = sys.argv[1]; out = sys.argv[2]
    asyncio.run(main(url, out, "--autoplay" in sys.argv))
