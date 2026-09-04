mergeInto(LibraryManager.library, {
  // ブラウザの入力ダイアログ（名の刻印）。取り消しは先頭に  を付けて返す
  KaguraPrompt: function (msgPtr, defPtr) {
    var msg = UTF8ToString(msgPtr), def = UTF8ToString(defPtr);
    var r = null;
    try { r = window.prompt(msg, def); } catch (e) { r = null; }
    if (r === null) r = "cancel";
    var len = lengthBytesUTF8(r) + 1;
    var buf = _malloc(len);
    stringToUTF8(r, buf, len);
    return buf;
  },
  // ページが一度でも操作された（クリック・タップ・キー）か。未操作だとブラウザは音を鳴らさない
  // Unity の Web Audio が鳴らせる状態か（AudioContext が running）。未操作のページでは suspended
  KaguraAudioReady: function () {
    try { if (typeof WEBAudio !== "undefined" && WEBAudio.audioContext) return WEBAudio.audioContext.state === "running" ? 1 : 0; } catch (e) {}
    try { return (navigator.userActivation && navigator.userActivation.hasBeenActive) ? 1 : 0; } catch (e) { return 0; }
  },
  KaguraUserActive: function () { try { return (navigator.userActivation && navigator.userActivation.hasBeenActive) ? 1 : 0; } catch (e) { return 0; } },
  KaguraTouchPoints: function () { try { return navigator.maxTouchPoints || 0; } catch (e) { return 0; } },
  KaguraUserAgent: function () {
    var ua = (navigator && navigator.userAgent) ? navigator.userAgent : "";
    var len = lengthBytesUTF8(ua) + 1;
    var buf = _malloc(len);
    stringToUTF8(ua, buf, len);
    return buf;
  }
});
