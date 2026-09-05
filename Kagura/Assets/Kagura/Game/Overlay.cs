using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Kagura.Game
{
    /// <summary>題目・討たれた・踏破の画面（Godot 版 OverlayView の移植）。</summary>
    public class Overlay : MonoBehaviour
    {
        public int mode;   // 0 題目 1 討たれた 2 踏破
        public bool visible;
        public List<(string, string)> statsLines = new List<(string, string)>();
        public string tip = "";
        private float _t;
        private UiLayer _layer;
        private Texture2D _title;
        // 題目のアニメ：GIF を逆再生した連番をアトラスに詰めたもの（Art/title_anime）。最後のフレームでこちらを見る
        private Texture2D[] _anime;
        private Texture2D _final;       // 最後のコマの高解像度版（Art/title_final）。GIF のコマはぼやけるので着いたら差し替える
        private int _animeN, _fw, _fh, _cols, _rows;
        private const float FrameDt = 1f / 24f;
        private float _introT;          // アニメの経過秒
        private float _afterT;          // 最後のフレームに着いてからの秒
        private bool _introSkipped;
        /// <summary>最初の操作待ち（ブラウザは操作前に音を鳴らせない）。タップで曲とアニメが始まる。</summary>
        public bool gate;
        private float IntroLen => _animeN * FrameDt;
        /// <summary>アニメがまだ最後のフレームに着いていない（タップで飛ばせる）。</summary>
        public bool IntroPlaying => _anime != null && _introT < IntroLen;
        private class Petal { public Vector2 pos, vel; public float rot, spin, size; }
        private readonly List<Petal> _petals = new List<Petal>();
        public string versionLabel = "";

        public static Overlay Create(Transform parent)
        {
            var go = new GameObject("overlay");
            go.transform.SetParent(parent, false);
            var o = go.AddComponent<Overlay>();
            o._layer = UiLayer.Create(go.transform, "overlay_layer", Gd.ZHud + 20);
            o._title = Resources.Load<Texture2D>("Art/title");
            o.LoadAnime();
            o._final = Resources.Load<Texture2D>("Art/title_final");
            for (int i = 0; i < 40; i++)
                o._petals.Add(new Petal { pos = new Vector2(Random.value * Gd.W, Random.value * Gd.H), vel = new Vector2(Gd.Rand(-20, 20), Gd.Rand(40, 110)), rot = Random.value * Gd.TAU, spin = Gd.Rand(-3, 3), size = Gd.Rand(2.5f, 5f) });
            var ver = Resources.Load<TextAsset>("version");
            if (ver != null) { var lines = ver.text.Split('\n'); o.versionLabel = lines[0].Trim() + (lines.Length > 1 ? " (" + lines[1].Trim() + ")" : ""); }
            else o.versionLabel = "vdev (local)";
            return o;
        }

        private void LoadAnime()
        {
            var info = Resources.Load<TextAsset>("Art/title_anime/info");
            if (info == null) return;
            var f = info.text.Trim().Split(' ');
            if (f.Length < 5) return;
            _animeN = int.Parse(f[0]); _fw = int.Parse(f[1]); _fh = int.Parse(f[2]); _cols = int.Parse(f[3]); _rows = int.Parse(f[4]);
            var list = new List<Texture2D>();
            for (int i = 0; ; i++)
            {
                var t = Resources.Load<Texture2D>($"Art/title_anime/atlas_{i:00}");
                if (t == null) break;
                list.Add(t);
            }
            if (list.Count == 0) { _animeN = 0; return; }
            _anime = list.ToArray();
            _animeN = Mathf.Min(_animeN, _anime.Length * _cols * _rows);
        }

        /// <summary>題目を開く：アニメを頭から流す。</summary>
        public void StartIntro(bool waitForTap = false) { _introT = 0f; _afterT = 0f; _introSkipped = false; gate = waitForTap; }
        public void PassGate() { gate = false; _introT = 0f; _afterT = 0f; }

        /// <summary>タップで飛ばす：最後のフレームへ飛び、題目を手早く出す。</summary>
        public void SkipIntro() { if (!IntroPlaying) return; _introT = IntroLen; _afterT = 0f; _introSkipped = true; }

        private void Update()
        {
            float dt = Time.unscaledDeltaTime;
            _t += dt;
            if (visible && mode == 0 && _anime != null && !gate)
            {
                if (_introT < IntroLen) { _introT += dt; if (_introT >= IntroLen) { _introT = IntroLen; _afterT = 0f; } }
                else _afterT += dt;
            }
            foreach (var p in _petals)
            {
                p.pos += p.vel * dt;
                p.pos.x += Mathf.Sin(_t + p.rot) * 20f * dt;
                p.rot += p.spin * dt;
                if (p.pos.y > Gd.H + 10f) p.pos = new Vector2(Random.value * Gd.W, -10f);
            }
            if (!visible) { _layer.Clear(); return; }
            _layer.Begin();
            if (mode == 0) DrawTitle();
            else if (mode == 2) DrawClear();
            else DrawOver();
            _layer.End();
        }

        // ---------- 題目 ----------

        private const float BlockX = 56f;
        private static float BlockW => Gd.W - BlockX * 2f;

        public Rect MenuRect(int i)
        {
            // 記録表と同じ幅で揃える（BlockX / BlockW）
            float h = i == 0 ? 58f : 48f;
            float y = Gd.H - 62f - 48f - 48f - 58f - 12f * 2f;
            for (int j = 0; j < i; j++) y += (j == 0 ? 58f : 48f) + 12f;
            return new Rect(BlockX, y, BlockW, h);
        }

        public int MenuAt(Vector2 px)
        {
            for (int i = 0; i < 3; i++) if (MenuRect(i).Contains(px)) return i;
            return -1;
        }

        /// <summary>アニメの 1 コマを画面いっぱいに敷く（cover、顔のある上寄せ）。</summary>
        private void DrawAnimeFrame(int i)
        {
            int per = _cols * _rows;
            var tex = _anime[Mathf.Clamp(i / per, 0, _anime.Length - 1)];
            int k = i % per;
            float sx = (k % _cols) * _fw, sy = (k / _cols) * _fh;
            DrawCoverPart(tex, sx, sy, _fw, _fh, 1f);
            // 最後のコマに着いたら、同じ構図の高解像度の絵へ溶かし込む
            if (i >= _animeN - 1 && _final != null)
                DrawCoverPart(_final, 0, 0, _final.width, _final.height, Mathf.Clamp01(_afterT / 0.6f));
        }

        /// <summary>テクスチャの一部（左上 sx,sy・大きさ fw×fh）を画面いっぱいに敷く（cover、顔のある上寄せ）。</summary>
        private void DrawCoverPart(Texture2D tex, float sx, float sy, float fw, float fh, float a)
        {
            if (a <= 0f) return;
            float scale = Mathf.Max(Gd.W / fw, Gd.H / fh);
            float sw = Gd.W / scale, sh = Gd.H / scale;
            _layer.img.Draw(tex, new Rect(0, 0, Gd.W, Gd.H), new Rect(sx + (fw - sw) * 0.5f, sy + (fh - sh) * 0.3f, sw, sh), new Color(1, 1, 1, a));
        }

        private void DrawTitle()
        {
            var l = _layer; var v = l.front;
            // 題目とメニューの現れ方：自然に最後まで見たら 2 秒かけてゆっくり、飛ばしたときは手早く
            float ta = 1f, ma = 1f;
            if (_anime != null)
            {
                if (IntroPlaying) { ta = 0f; ma = 0f; }
                else if (_introSkipped) { ta = Mathf.Clamp01(_afterT / 0.5f); ma = Mathf.Clamp01((_afterT - 0.15f) / 0.5f); }
                else { ta = Mathf.Clamp01((_afterT - 0.4f) / 2.2f); ma = Mathf.Clamp01((_afterT - 1.6f) / 2f); }
            }
            if (_anime != null)
            {
                DrawAnimeFrame(Mathf.Clamp(Mathf.FloorToInt(_introT / FrameDt), 0, _animeN - 1));
                if (gate)
                {
                    v.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.02f, 0.01f, 0.04f, 0.55f));
                    float ga = 0.55f + 0.35f * Mathf.Sin(_t * 2.2f);
                    UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, Gd.H * 0.5f), "tap to begin", 22, new Color(1, 1, 1, ga), TextAnchor.MiddleCenter, Gd.W);
                    return;
                }
                if (IntroPlaying)
                {   // 題目が出るまで、ゆっくり点滅する案内
                    float blinkA = 0.30f + 0.30f * Mathf.Sin(_t * 2.2f);
                    UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H - 44f), "tap to skip", 13, new Color(1, 1, 1, blinkA), TextAnchor.MiddleCenter, Gd.W);
                }
                if (ta <= 0f) return;   // まだ絵だけ
            }
            else if (_title != null)
            {
                float tw = _title.width, th = _title.height;
                float scale = Gd.H / th;
                float srcW = Gd.W / scale;
                float srcX = Mathf.Clamp(1100f - srcW * 0.5f, 0f, tw - srcW);
                l.img.Draw(_title, new Rect(0, 0, Gd.W, Gd.H), new Rect(srcX, 0, srcW, th), new Color(0.92f, 0.88f, 1f));
            }
            else l.back.DrawRect(new Rect(0, 0, Gd.W, Gd.H), Gd.C_BG);
            // 下だけ暗くしてメニューを載せる（上は絵の顔を隠さない）。段差が見えないよう細かく刻む
            const int steps = 40;
            for (int i = 0; i < steps; i++)
            {
                float k = (float)i / steps;
                v.DrawRect(new Rect(0, Gd.H - 360f + k * 360f, Gd.W, 360f / steps + 1f), new Color(0.05f, 0.02f, 0.10f, 0.9f * k * k * ma));
            }
            foreach (var p in _petals)
            {
                Vector2 d = Gd.Dir(p.rot), n = Gd.Orth(d);
                float s = p.size;
                v.DrawColoredPolygon(new[] { p.pos + d * s * 1.5f, p.pos + n * s * 0.7f, p.pos - d * s * 1.5f, p.pos - n * s * 0.7f }, new Color(0.9f, 0.7f, 1f, 0.5f * ta));
            }
            float bob = Mathf.Sin(_t * 1.6f) * 3f;
            float rise = (1f - ta) * 14f;   // 現れながら少し浮き上がる
            if (_anime != null)
            {
                // 絵の左の黒地に縦書き：顔（右上）を隠さない
                UiKit.Vtxt(l, WorldText.Face.Display, new Vector2(104, 150 + bob + rise), "神楽", 118, new Color(0.98f, 0.94f, 1f, ta));
                // 縦書きは右の行から読む
                UiKit.Vtxt(l, WorldText.Face.Display, new Vector2(222, 158 + bob + rise), "八百万の加護を纏いて", 15, new Color(1, 0.9f, 0.75f, 0.95f * ta));
                UiKit.Vtxt(l, WorldText.Face.Display, new Vector2(196, 158 + bob + rise), "穢れを祓え", 15, new Color(1, 0.9f, 0.75f, 0.95f * ta));
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(46, 432 + bob + rise), "KAGURA  ASCENT", 13, new Color(0.85f, 0.6f, 1f, ta), TextAnchor.MiddleLeft, 200f);
            }
            else
            {
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 178 + bob + rise), "神楽", 122, new Color(0.98f, 0.94f, 1f, ta), TextAnchor.MiddleCenter, Gd.W);
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, 214 + bob + rise), "K A G U R A   A S C E N T", 17, new Color(0.85f, 0.6f, 1f, ta), TextAnchor.MiddleCenter, Gd.W);
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 252 + bob + rise), "八百万の加護を纏いて、穢れを祓え", 17, new Color(1, 0.9f, 0.75f, 0.95f * ta), TextAnchor.MiddleCenter, Gd.W);
            }
            if (ma <= 0f) return;

            bool touch = GameManager.I != null && GameManager.I.IsTouch;
            var rows = Records.Entries;
            int cnt3 = Mathf.Min(rows.Count, 3);
            float rh = 26f + 20f * Mathf.Max(cnt3, 1);
            float ry = MenuRect(0).yMin - rh - 24f;
            DrawRecords(ry, 3, -1, 0.95f * ma);
            if (Records.Best.clears > 0)
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, ry - 8f), $"踏破 {Records.Best.clears} 回　最高功徳 {Records.Best.score}", 11, Gd.WithA(Gd.C_GOLD, 0.9f * ma), TextAnchor.MiddleCenter, Gd.W);
            string[] labels = { "はじめる", "記録を見る", Records.PlayerName.Trim() == "" ? "名を刻む" : $"名を変える（{Records.DisplayName()}）" };
            for (int i = 0; i < 3; i++)
            {
                var r = MenuRect(i);
                bool main = i == 0;
                Color col = main ? Gd.C_GOLD : new Color(0.8f, 0.8f, 0.95f);
                v.DrawRect(UiKit.Grow(r, 3f), new Color(0, 0, 0, 0.45f * ma));
                v.DrawRect(r, main ? new Color(0.16f, 0.11f, 0.08f, 0.95f * ma) : new Color(0.09f, 0.06f, 0.14f, 0.92f * ma));
                v.DrawRect(r, Gd.WithA(col, (main ? 0.85f : 0.55f) * ma), false, 1.2f);
                foreach (float cx in new[] { r.xMin + 6f, r.xMax - 6f }) v.DrawCircle(new Vector2(cx, r.center.y), 2f, Gd.WithA(col, 0.9f * ma));
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(r.xMin, r.center.y + 9f), labels[i], main ? 24 : 19, main ? Gd.WithA(Gd.C_GOLD, ma) : Gd.WithA(col, 0.95f * ma), TextAnchor.MiddleCenter, r.width);
            }
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H - 12), versionLabel, 10, new Color(1, 1, 1, 0.45f * ma), TextAnchor.MiddleRight, Gd.W - 12f);
        }

        /// <summary>記録表（上位 n 件）。</summary>
        private float DrawRecords(float y0, int n, int highlightRun, float a = 1f)
        {
            var l = _layer; var v = l.front;
            var rows = Records.Entries;
            int cnt = Mathf.Min(rows.Count, n);
            float x0 = BlockX, w = BlockW;
            float h = 26f + 20f * Mathf.Max(cnt, 1);
            UiKit.Panel(v, new Rect(x0, y0, w, h), Gd.C_GOLD, a, 0.78f);
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(x0 + 12, y0 + 17), "この端末の記録", 12, Gd.WithA(Gd.C_GOLD, a));
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0 + 110, y0 + 16), $"巫女 {Records.DisplayName()}", 10, new Color(1, 1, 1, 0.75f * a));
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 16), "功徳", 9, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleRight, w - 250f);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 16), "到達", 9, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleRight, w - 130f);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 16), "神々", 9, new Color(1, 1, 1, 0.5f * a), TextAnchor.MiddleRight, w - 12f);
            if (cnt == 0) UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y0 + 40), "まだ記録がない。参道を登り、名を刻め", 11, new Color(1, 1, 1, 0.55f * a), TextAnchor.MiddleCenter, w);
            float y = y0 + 40f;
            for (int i = 0; i < cnt; i++)
            {
                var e = rows[i];
                bool mine = e.run == highlightRun && highlightRun >= 0;
                Color col = mine ? Gd.C_GOLD : new Color(0.92f, 0.92f, 1f);
                if (mine) v.DrawRect(new Rect(x0 + 4, y - 14, w - 8, 19), Gd.WithA(Gd.C_GOLD, 0.14f * a));
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(x0 + 12, y), (i + 1).ToString(), 11, Gd.WithA(col, a * (i < 3 ? 1f : 0.7f)));
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0 + 34, y), e.name, 11, Gd.WithA(col, a));
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(x0, y), e.score.ToString(), 11, Gd.WithA(col, a), TextAnchor.MiddleRight, w - 250f);
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y), Records.ReachText(e), 10, Gd.WithA(col, a * 0.9f), TextAnchor.MiddleRight, w - 130f);
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(x0, y), Records.GodsText(e), 10, Gd.WithA(col, a * 0.8f), TextAnchor.MiddleRight, w - 12f);
                y += 20f;
            }
            return y0 + h;
        }

        // ---------- 結果 ----------

        private void DrawClear()
        {
            var l = _layer; var v = l.front; var b = l.back;
            b.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.03f, 0.02f, 0.06f, 0.82f));
            var tex = UiKit.Art("scene/clear");
            if (tex != null)
            {
                l.img.DrawCover(tex, new Rect(0, 0, Gd.W, Gd.H), 0.55f, 0.3f);
                for (int gi = 0; gi < 10; gi++) { float kk = gi / 10f; v.DrawRect(new Rect(0, 260f + kk * (Gd.H - 260f), Gd.W, (Gd.H - 260f) / 10f + 1f), new Color(0.03f, 0.02f, 0.06f, 0.85f * Mathf.Min(1f, kk * 2f))); }
            }
            UiKit.Pattern(v, new Rect(0, 0, Gd.W, Gd.H), Gd.WithA(Gd.C_GOLD, 0.06f), 52f, _t);
            var win = UiKit.Art("cutin/clear");
            if (win != null)
            {
                var wr = new Rect(0, 40, Gd.W, 170);
                l.img.DrawCover(win, wr, 0.95f, 0.3f);
                for (int gi = 0; gi < 6; gi++) { float kk = gi / 6f; v.DrawRect(new Rect(0, wr.yMax - 60f + kk * 60f, Gd.W, 60f / 6f + 1f), new Color(0.03f, 0.02f, 0.06f, 0.9f * kk)); }
                v.DrawRect(new Rect(0, wr.yMin, Gd.W, 2), Gd.WithA(Gd.C_GOLD, 0.9f));
                var sm = UiKit.Art("portrait/smile");
                if (sm != null) { float sh = 250f, sw = sh * sm.width / (float)sm.height; l.img.Draw(sm, new Rect(Gd.W - sw + 30f, 10f, sw, sh), new Color(1, 1, 1, 0.95f)); }
            }
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 250), "踏破", 66, Gd.C_GOLD, TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, 284), "奥宮の穢れは祓われ、参道に朝日が差した", 13, new Color(1, 0.95f, 0.85f, 0.9f), TextAnchor.MiddleCenter, Gd.W);
            float y = DrawStats(340f, new Color(0.85f, 0.8f, 0.65f));
            y = DrawRank(y);
            var g = GameManager.I;
            if (g != null && g.player != null) g.hud.DrawBuild(l, g.player, y + 16f);
            float blink = 0.55f + 0.45f * Mathf.Sin(_t * 4f);
            bool touch = g != null && g.IsTouch;
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, Gd.H - 96f), touch ? "タップで更に登る（祟りの参道）" : "タップ / ENTER で更に登る（祟りの参道）", 20, new Color(1, 1, 1, blink), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, Gd.H - 66f), touch ? "右上の「休」から題目へ戻れる" : "R で最初から　　ESC で題目へ", 13, new Color(0.9f, 0.9f, 1f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
        }

        private void DrawOver()
        {
            var l = _layer; var v = l.front; var b = l.back;
            b.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.02f, 0.01f, 0.05f, 0.8f));
            var tex = UiKit.Art("scene/gameover");
            if (tex != null)
            {
                l.img.DrawCover(tex, new Rect(0, 0, Gd.W, Gd.H), 0.5f, 0.3f);
                for (int gi = 0; gi < 10; gi++) { float kk = gi / 10f; v.DrawRect(new Rect(0, 240f + kk * (Gd.H - 240f), Gd.W, (Gd.H - 240f) / 10f + 1f), new Color(0.02f, 0.01f, 0.05f, 0.88f * Mathf.Min(1f, kk * 2f))); }
            }
            UiKit.Pattern(v, new Rect(0, 0, Gd.W, Gd.H), new Color(1, 0.3f, 0.4f, 0.04f), 52f, _t);
            var pain = UiKit.Art("portrait/pain");
            if (pain != null) { float ph = 300f, pw = ph * pain.width / (float)pain.height; l.img.Draw(pain, new Rect(Gd.W - pw + 40f, 20f, pw, ph), new Color(1, 1, 1, 0.9f)); }
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, 200), "討たれた", 58, new Color(1, 0.3f, 0.4f), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(l, WorldText.Face.Body, new Vector2(0, 234), "神楽は途切れ、参道は闇に沈んだ", 13, new Color(0.9f, 0.8f, 0.85f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
            float y = DrawStats(290f, new Color(0.65f, 0.75f, 0.9f));
            if (tip != "")
            {
                UiKit.Panel(v, new Rect(50, y + 4, Gd.W - 100, 48), Gd.C_GOLD, 1f, 0.8f);
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(62, y + 22), "次の一手", 11, Gd.C_GOLD);
                UiKit.Para(l, WorldText.Face.Body, new Vector2(62, y + 40), tip, Gd.W - 124, 11, 2, new Color(0.95f, 0.95f, 1f, 0.95f));
                y += 60f;
            }
            y = DrawRank(y);
            var g = GameManager.I;
            if (g != null && g.player != null) g.hud.DrawBuild(l, g.player, y + 16f);
            float blink = 0.55f + 0.45f * Mathf.Sin(_t * 4f);
            bool touch = g != null && g.IsTouch;
            UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, Gd.H - 96f), touch ? "タップで題目へ" : "タップ / ENTER で題目へ", 20, new Color(1, 1, 1, blink), TextAnchor.MiddleCenter, Gd.W);
        }

        private float DrawStats(float y, Color labelCol)
        {
            foreach (var row in statsLines)
            {
                UiKit.Txt(_layer, WorldText.Face.Body, new Vector2(0, y), row.Item1, 15, labelCol, TextAnchor.MiddleRight, Gd.W * 0.5f - 14f);
                UiKit.Txt(_layer, WorldText.Face.Display, new Vector2(Gd.W * 0.5f + 14f, y), row.Item2, 18, Color.white);
                y += 30f;
            }
            return y;
        }

        public int rank, globalRank;
        private float DrawRank(float y)
        {
            if (globalRank != 0)
            {
                string gtxt = globalRank > 0 ? $"世界の記録　第 {globalRank} 位" : globalRank == -2 ? "世界の記録　送れなかった" : "世界の記録　送信中…";
                UiKit.Txt(_layer, WorldText.Face.Display, new Vector2(0, y + 2), gtxt, 17, globalRank > 0 ? new Color(0.75f, 0.9f, 1f) : new Color(0.8f, 0.8f, 0.9f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
                y += 22f;
            }
            if (rank > 0)
            {
                UiKit.Txt(_layer, WorldText.Face.Display, new Vector2(0, y + 18), $"この端末の記録　第 {rank} 位に刻まれた", 17, Gd.C_GOLD, TextAnchor.MiddleCenter, Gd.W);
                y += 40f;
            }
            // 名を刻む（結果画面）：順位の下の札
            string label = Records.PlayerName.Trim() == "" ? "名を刻む" : $"名を変える（{Records.DisplayName()}）";
            float bw = Mathf.Max(150f, label.Length * 13f + 40f);
            nameBtn = new Rect(Gd.W * 0.5f - bw * 0.5f, y + 2f, bw, 32f);
            nameBtnShown = true;
            UiKit.Panel(_layer.back, nameBtn, Gd.C_GOLD, 1f, 0.8f);
            UiKit.Txt(_layer, WorldText.Face.Bold, new Vector2(nameBtn.x, nameBtn.y + 21f), label, 12, Gd.C_GOLD, TextAnchor.MiddleCenter, nameBtn.width);
            return y + 40f;
        }
        public Rect nameBtn; public bool nameBtnShown;
    }
}
