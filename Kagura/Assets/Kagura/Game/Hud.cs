using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>
    /// HUD（Godot 版 HudView の移植）。命の帯、位の帯、迎えた神々、詠唱・疾走・神招き、上部の段と波、ボスの帯、告知、カットイン。
    /// </summary>
    public class Hud : MonoBehaviour
    {
        public const float CALL_T = 1.9f, CUTIN_T = 1.6f;
        public string bannerText = "", bannerSub = "";
        public Color bannerCol = Color.white;
        public int bannerIcon = -1;
        public float bannerT, cutinT, callT, smallT, introT;
        public string callKami = ""; public bool callGreater;
        public string cutinKey = ""; public Color cutinCol = Color.white; public float cutinLen = 1.6f;
        public string smallText = ""; public Color smallCol = Color.white;
        public string introName = "", introTitle = "", introKey = ""; public bool introFinal;
        private float _t, _hpShown = 1f;
        public UiLayer layer;

        public static Hud Create(Transform parent)
        {
            var go = new GameObject("hud");
            go.transform.SetParent(parent, false);
            var h = go.AddComponent<Hud>();
            h.layer = UiLayer.Create(go.transform, "hud_layer", Gd.ZHud);
            return h;
        }

        public void Banner(string text, string sub = "", Color? col = null, int icon = -1)
        {
            bannerText = text; bannerSub = sub; bannerCol = col ?? Color.white; bannerIcon = icon;
            bannerT = icon < 0 ? 2.4f : 3.2f;
        }
        public void Small(string text, Color col) { smallText = text; smallCol = col; smallT = 2.2f; }
        public void Cutin(string key, Color col, float len = 1.6f) { cutinKey = key; cutinCol = col; cutinLen = len; cutinT = len; }
        public void CallCutin(string kami, bool greater) { callKami = kami; callGreater = greater; callT = CALL_T; }
        public void BossIntro(string name, string title, bool final, string key) { introName = name; introTitle = title; introFinal = final; introKey = key; introT = 3.2f; }

        private void Update()
        {
            float dt = Time.unscaledDeltaTime;
            _t += dt;
            bannerT = Mathf.Max(0, bannerT - dt); smallT = Mathf.Max(0, smallT - dt); introT = Mathf.Max(0, introT - dt);
            cutinT = Mathf.Max(0, cutinT - dt); callT = Mathf.Max(0, callT - dt);
            Draw();
        }

        private void Draw()
        {
            var g = GameManager.I;
            var l = layer;
            l.Begin();
            if (g != null)
            {
                var p = g.player;
                bool inGame = g.State == GameState.Play || g.State == GameState.Choice || g.State == GameState.Pause || g.State == GameState.Clear;
                if (inGame)
                {
                    if (p != null)
                    {
                        DrawHp(p); DrawXp(p); DrawGods(p);
                        if (!g.IsTouch) DrawSkills(p);
                    }
                    DrawTop(g); DrawBoss(g);
                    if (g.State == GameState.Play || g.State == GameState.Pause) PauseMenu.DrawGear(l.front, _t, g.State == GameState.Pause);
                }
                if (cutinT > 0f) DrawCutin();
                if (callT > 0f) DrawCallCutin();
                if (bannerT > 0f && callT <= 0f) DrawBanner();
                if (introT > 0f) DrawIntro();
                if (smallT > 0f)
                {
                    float a = Mathf.Clamp01(smallT * 2f);
                    UiKit.Txt(l, WorldText.Face.Display, new Vector2(0, Gd.H - 150f), smallText, 20, Gd.WithA(smallCol, a), TextAnchor.MiddleCenter, Gd.W);
                }
            }
            l.End();
        }

        private void DrawHp(Player p)
        {
            var v = layer.front;
            float k = p.hp / Mathf.Max(1f, p.maxHp);
            _hpShown = Mathf.Lerp(_hpShown, k, 0.15f);
            var r = new Rect(44, 16, 224, 14);
            UiKit.Panel(v, new Rect(12, 8, 270, 32), UiKit.GOLD, 1f, 0.7f);
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(20, 30), "命", 18, UiKit.GOLD);
            Color col = Color.Lerp(Gd.C_HP, new Color(1, 0.35f, 0.35f), Mathf.Clamp01(1f - k * 1.6f));
            if (_hpShown > k + 0.005f) v.DrawRect(new Rect(r.xMin + r.width * k, r.yMin, r.width * (_hpShown - k), r.height), new Color(1, 1, 1, 0.55f));
            UiKit.Bar(v, r, k, col, _t, 5);
            UiKit.Txt(layer, WorldText.Face.Bold, new Vector2(r.xMin, r.yMin + 11), $"{Mathf.CeilToInt(p.hp)} / {(int)p.maxHp}", 11, new Color(1, 1, 1, 0.95f), TextAnchor.MiddleRight, r.width - 6f);
            if (p.shield > 0)
            {
                v.DrawCircle(new Vector2(292, 24), 8f, Gd.WithA(Gd.C_GOLD, 0.9f));
                v.DrawArc(new Vector2(292, 24), 10.5f, 0, Gd.TAU, 16, new Color(1, 1, 1, 0.5f), 1f);
                UiKit.Txt(layer, WorldText.Face.Display, new Vector2(284, 29), "鏡", 11, Gd.C_INK, TextAnchor.MiddleCenter, 16, false);
            }
        }

        private void DrawXp(Player p)
        {
            var v = layer.front;
            var r = new Rect(70, Gd.H - 22, Gd.W - 90, 8);
            UiKit.Panel(v, new Rect(10, Gd.H - 34, Gd.W - 20, 30), UiKit.GOLD, 1f, 0.6f);
            Vector2 mp = new Vector2(28, Gd.H - 19);
            v.DrawCircle(mp, 7f, Gd.C_XP);
            v.DrawCircle(mp + new Vector2(-2, -2), 2f, new Color(1, 1, 1, 0.9f));
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(40, Gd.H - 13), $"位 {p.level}", 14, new Color(0.9f, 0.97f, 1f));
            UiKit.Bar(v, r, p.xp / Mathf.Max(1f, p.xpNext), Gd.C_XP, _t, 8);
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(0, Gd.H - 25), $"{(int)p.xp} / {(int)p.xpNext}", 10, new Color(0.7f, 0.85f, 1f, 0.85f), TextAnchor.MiddleRight, Gd.W - 22);
        }

        private void DrawGods(Player p)
        {
            var v = layer.front;
            float y = 52f;
            for (int i = 0; i < p.gods.Count; i++)
            {
                string id = p.gods[i];
                var k = Data.KamiOf(id);
                if (k == null) continue;
                bool main = i == 0;
                float r = main ? 17f : 13f;
                Vector2 c = new Vector2(14f + 24f, y + r + 6f);
                float w = main ? 176f : 150f;
                Color kc = Data.ColorOf(k.color);
                UiKit.Panel(v, new Rect(12, y, w, r * 2f + 14f), kc, 0.9f, 0.55f);
                UiKit.KamiRing(layer, p, id, c, r, _t, 1f, true);
                UiKit.Txt(layer, WorldText.Face.Body, new Vector2(c.x + r + 12f, y + 14f), main ? "主神" : "副神", 9, Gd.WithA(main ? new Color(1, 0.9f, 0.7f) : new Color(0.85f, 0.85f, 1f), 0.8f));
                UiKit.Txt(layer, WorldText.Face.Display, new Vector2(c.x + r + 12f, y + 30f), k.name, main ? 14 : 12, Gd.WithA(kc, 0.95f));
                UiKit.Txt(layer, WorldText.Face.Body, new Vector2(c.x + r + 12f, main ? y + 43f : y + 40f), k.weapon, 9, new Color(1, 1, 1, 0.7f));
                y += r * 2f + 22f;
            }
            int nxt = Progression.NextRecruitLevel(p);
            if (nxt > 0)
            {
                string lbl = $"位 {nxt} で{(p.gods.Count == 0 ? "主神" : "副神")}";
                v.DrawRect(new Rect(12, y - 6f, 110, 20), new Color(0.5f, 0.5f, 0.65f, 0.18f));
                v.DrawRect(new Rect(12, y - 6f, 110, 20), new Color(0.7f, 0.7f, 0.85f, 0.35f), false, 1f);
                UiKit.Txt(layer, WorldText.Face.Body, new Vector2(20, y + 8f), lbl, 11, new Color(0.9f, 0.9f, 1f, 0.75f));
                y += 20f;
            }
            DrawChips(p, y + 2f);
        }

        private void DrawChips(Player p, float y0)
        {
            var v = layer.front;
            float x = 16f, y = y0;
            foreach (var rid in p.relics)
            {
                var rl = Data.Relic(rid);
                if (rl == null) continue;
                v.DrawRect(new Rect(x, y, 20, 20), new Color(0.6f, 0.45f, 0.1f, 0.45f));
                v.DrawRect(new Rect(x, y, 20, 20), Gd.WithA(Gd.C_GOLD, 0.95f), false, 1.5f);
                UiKit.Txt(layer, WorldText.Face.Display, new Vector2(x, y + 15), rl.mark, 12, new Color(1, 0.95f, 0.8f), TextAnchor.MiddleCenter, 20);
                y += 24f;
                if (y > Gd.H - 200f) { y = y0; x += 24f; }
            }
            foreach (var kv in p.boons)
            {
                var b = Data.Boon(kv.Key);
                if (b == null)
                {
                    if (Data.Curse(kv.Key) == null) continue;
                    v.DrawRect(new Rect(x, y, 20, 20), new Color(0.6f, 0.1f, 0.2f, 0.5f));
                    v.DrawRect(new Rect(x, y, 20, 20), new Color(1, 0.4f, 0.5f, 0.9f), false, 1.5f);
                    UiKit.Txt(layer, WorldText.Face.Display, new Vector2(x, y + 15), "禍", 12, new Color(1, 0.85f, 0.9f), TextAnchor.MiddleCenter, 20);
                    y += 24f;
                    continue;
                }
                Color col = Data.ColorOf(RarityTable.Colors[Mathf.Clamp(kv.Value.rar, 0, 5)]);
                Color kc = Data.KamiColor(b.kami);
                v.DrawRect(new Rect(x, y, 20, 20), Gd.WithA(kc, 0.22f));
                v.DrawRect(new Rect(x, y, 20, 20), Gd.WithA(col, 0.85f), false, 1.5f);
                UiKit.Txt(layer, WorldText.Face.Display, new Vector2(x, y + 15), b.name.Substring(0, 1), 12, new Color(1, 1, 1, 0.95f), TextAnchor.MiddleCenter, 20);
                if (kv.Value.lv > 1) UiKit.Txt(layer, WorldText.Face.Bold, new Vector2(x + 11, y + 22), kv.Value.lv.ToString(), 9, Gd.C_GOLD);
                y += 24f;
                if (y > Gd.H - 200f) { y = y0; x += 24f; }
            }
        }

        private void DrawSkills(Player p)
        {
            var v = layer.front;
            string main = p.MainGod();
            Color mc = main != "" ? p.KamiColor(main) : new Color(0.6f, 0.6f, 0.7f);
            float gx = Gd.W - 44f, gy = Gd.H - 270f, gw = 26f, gh = 150f;
            UiKit.Panel(v, new Rect(gx - 6, gy - 30, gw + 12, gh + 60), main != "" ? mc : UiKit.GOLD, 0.95f, 0.75f);
            float k = p.callGauge;
            if (main != "" && k >= 0.999f) UiKit.FlamesRect(v, new Rect(gx, gy, gw, gh), _t);   // 満ちた：紫の炎がめらめら
            v.DrawRect(new Rect(gx, gy, gw, gh), new Color(0.05f, 0.03f, 0.08f, 0.9f));
            if (k > 0f)
            {
                float fh = gh * k;
                float pulse = k < 0.999f ? 1f : 0.75f + 0.25f * Mathf.Sin(_t * 8f);
                v.DrawRect(new Rect(gx, gy + gh - fh, gw, fh), Gd.WithA(Gd.Darkened(mc, 0.3f), pulse));
                v.DrawRect(new Rect(gx + 4, gy + gh - fh, gw - 8, fh), Gd.WithA(mc, pulse));
                for (int i = 0; i < 3; i++)
                {
                    float fx = gx + 4f + i * (gw - 8f) * 0.5f;
                    float fh2 = 6f + 5f * Mathf.Sin(_t * 9f + i * 2f);
                    v.DrawColoredPolygon(new[] { new Vector2(fx - 4, gy + gh - fh), new Vector2(fx + 4, gy + gh - fh), new Vector2(fx, gy + gh - fh - fh2) }, Gd.WithA(Gd.Lightened(mc, 0.4f), 0.8f * pulse));
                }
            }
            v.DrawRect(new Rect(gx, gy, gw, gh), Gd.WithA(UiKit.GOLD, 0.5f), false, 1f);
            bool ready = main != "" && k >= 0.999f;
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(gx - 6, gy - 8), "招", 20, Gd.WithA(main != "" ? mc : new Color(1, 1, 1, 0.3f), 0.7f + 0.3f * (ready ? 1f : 0f) * (0.5f + 0.5f * Mathf.Sin(_t * 6f))), TextAnchor.MiddleCenter, gw + 12);
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(gx - 6, gy + gh + 18), "X", 11, new Color(1, 1, 1, 0.6f), TextAnchor.MiddleCenter, gw + 12);

            float px = Gd.W - 150f, py = Gd.H - 88f;
            UiKit.Panel(v, new Rect(px - 8, py - 22, 108, 54), UiKit.GOLD, 0.95f, 0.7f);
            for (int i = 0; i < p.castMax; i++)
            {
                Vector2 c = new Vector2(px + 10f + i * 22f, py);
                if (i < p.castCharges && main != "")
                {
                    v.DrawRect(new Rect(c.x - 7, c.y - 11, 14, 22), Gd.WithA(mc, 0.35f));
                    v.DrawRect(new Rect(c.x - 6, c.y - 10, 12, 20), Gd.C_PAPER);
                    v.DrawRect(new Rect(c.x - 6, c.y - 10, 12, 20), Gd.WithA(mc, 0.95f), false, 1.2f);
                    v.DrawRect(new Rect(c.x - 4, c.y - 7, 8, 2.5f), Gd.WithA(mc, 0.9f));
                    v.DrawLine(c + new Vector2(0, -3), c + new Vector2(0, 5), Gd.C_INK, 1.5f);
                    v.DrawCircle(c + new Vector2(0, 7), 1.8f, new Color(0.85f, 0.2f, 0.25f, 0.95f));
                }
                else v.DrawRect(new Rect(c.x - 6, c.y - 10, 12, 20), Gd.WithA(mc, 0.35f + 0.15f * Mathf.Sin(_t * 4f)), false, 1.2f);
            }
            bool hasCast = p.castCharges > 0 || main == "";
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(px, py + 24), hasCast ? "詠唱 Z" : "札を拾え", 10, hasCast ? new Color(1, 1, 1, 0.6f) : Gd.WithA(mc, 0.6f + 0.4f * Mathf.Sin(_t * 5f)));
            float dx = px + 84f;
            float dk = 1f - p.dashCool / Mathf.Max(0.01f, p.DashCdTime());
            v.DrawArc(new Vector2(dx, py), 9f, 0, Gd.TAU, 20, new Color(1, 1, 1, 0.25f), 1.5f);
            v.DrawArc(new Vector2(dx, py), 9f, -Mathf.PI * 0.5f, -Mathf.PI * 0.5f + Gd.TAU * dk, 20, dk >= 1f ? new Color(1, 1, 1, 0.9f) : new Color(0.8f, 0.85f, 1f, 0.7f), 2.5f);
            if (dk >= 1f) v.DrawCircle(new Vector2(dx, py), 3f, new Color(1, 1, 1, 0.8f));
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(dx - 20, py + 24), "疾走", 10, new Color(1, 1, 1, 0.6f), TextAnchor.MiddleCenter, 40);
        }

        private void DrawTop(GameManager g)
        {
            var v = layer.front;
            float cx = Gd.W * 0.5f;
            int st = Stages.StageOf(Mathf.Max(g.Wave, 1));
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(0, 14), $"第{Gd.STAGE_KANJI[st - 1]}の段　{Gd.STAGE_NAME[st - 1]}", 10, Gd.WithA(UiKit.GOLD, 0.85f), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(0, 38), $"第 {g.Wave} 波", 22, new Color(1, 1, 1, 0.95f), TextAnchor.MiddleCenter, Gd.W);
            v.DrawLine(new Vector2(cx - 96, 27), new Vector2(cx - 58, 27), Gd.WithA(UiKit.GOLD, 0.7f), 1f);
            v.DrawLine(new Vector2(cx + 58, 27), new Vector2(cx + 96, 27), Gd.WithA(UiKit.GOLD, 0.7f), 1f);
            v.DrawColoredPolygon(new[] { new Vector2(cx - 54, 27), new Vector2(cx - 50, 23), new Vector2(cx - 46, 27), new Vector2(cx - 50, 31) }, Gd.WithA(UiKit.GOLD, 0.9f));
            v.DrawColoredPolygon(new[] { new Vector2(cx + 46, 27), new Vector2(cx + 50, 23), new Vector2(cx + 54, 27), new Vector2(cx + 50, 31) }, Gd.WithA(UiKit.GOLD, 0.9f));
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(0, 22), "功徳", 10, new Color(0.85f, 0.8f, 0.95f, 0.85f), TextAnchor.MiddleRight, Gd.W - 18);
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(0, 42), g.Score.ToString(), 18, new Color(1, 1, 1, 0.95f), TextAnchor.MiddleRight, Gd.W - 18);
            var pl = g.player;
            if (pl != null)
            {
                UiKit.Coin(v, new Vector2(Gd.W - 62f, 62f), 6f);
                UiKit.Txt(layer, WorldText.Face.Display, new Vector2(0, 68), pl.ryo + " 両", 14, Gd.WithA(Gd.C_GOLD, 0.95f), TextAnchor.MiddleRight, Gd.W - 18);
                // 市の札の効き目（残り秒）
                float by = 150f;
                void Buff(string name, float sec) { if (sec <= 0f) return; UiKit.Txt(layer, WorldText.Face.Body, new Vector2(0, by), $"{name} {Mathf.CeilToInt(sec)}", 11, Gd.WithA(Gd.C_GOLD, 0.9f), TextAnchor.MiddleRight, Gd.W - 14); by += 15f; }
                Buff("御神酒", pl.buffDmgT); Buff("早矢", pl.buffRateT); Buff("韋駄天", pl.buffSpeedT);
                if (g.stall != null && g.stall.Active)
                    UiKit.Txt(layer, WorldText.Face.Display, new Vector2(g.stall.LabelPos.x - 14f, g.stall.LabelPos.y + 7f), "市", 16, Gd.C_INK, TextAnchor.MiddleCenter, 28f, false);
            }
        }

        private void DrawBoss(GameManager g)
        {
            var b = g.boss;
            if (b == null || !b.Active) return;
            var v = layer.front;
            var r = new Rect(110, 82, Gd.W - 220, 10);
            UiKit.Panel(v, new Rect(92, 60, Gd.W - 184, 40), new Color(1, 0.4f, 0.5f), 0.95f, 0.7f);
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(0, 77), b.bossName, 13, new Color(1, 0.75f, 0.8f), TextAnchor.MiddleCenter, Gd.W);
            UiKit.Bar(v, r, b.hp / b.maxHp, new Color(1, 0.3f, 0.4f), _t, 3, new Color(1, 0.5f, 0.6f));
            for (int i = 0; i < b.Phase(); i++) v.DrawCircle(new Vector2(Gd.W - 108 + i * 10, 74), 3.5f, new Color(1, 0.85f, 0.4f));
        }

        private void DrawBanner()
        {
            var v = layer.front;
            float k = bannerT / (bannerIcon < 0 ? 2.4f : 3.2f);
            float a = Mathf.Clamp01(Mathf.Sin(k * Mathf.PI) * 2.2f);
            float y = 300f - (1f - k) * 16f;
            Color c = bannerCol; c.a = a;
            v.DrawRect(new Rect(0, y - 44, Gd.W, 82), new Color(0, 0, 0, 0.45f * a));
            v.DrawRect(new Rect(0, y - 44, Gd.W, 2), new Color(c.r, c.g, c.b, a * 0.8f));
            v.DrawRect(new Rect(0, y + 36, Gd.W, 2), new Color(c.r, c.g, c.b, a * 0.8f));
            v.DrawRect(new Rect(0, y - 41, Gd.W, 1), new Color(1, 1, 1, a * 0.25f));
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(0, y), bannerText, 32, c, TextAnchor.MiddleCenter, Gd.W);
            if (bannerIcon >= 0)
            {
                float tw = bannerText.Length * 32f;
                Vector2 ip = new Vector2(Gd.W * 0.5f - tw * 0.5f - 40f, y - 12f);
                string[] names = { "xp", "heal", "miki", "orb" };
                var itex = bannerIcon < 4 ? UiKit.Art("item/" + names[bannerIcon]) : null;
                if (itex != null)
                {
                    layer.img.Draw(itex, new Rect(ip.x - 30, ip.y - 30, 60, 60), new Color(1, 1, 1, a));
                    v.DrawRect(new Rect(ip.x - 30, ip.y - 30, 60, 60), Gd.WithA(c, 0.8f * a), false, 1.5f);
                }
                else
                {
                    v.DrawCircle(ip, 22f, Gd.WithA(c, 0.18f));
                    v.SetTransform(ip, 0f, new Vector2(1.7f, 1.7f));
                    UiKit.PickupShape(v, bannerIcon, c, _t, 1f);
                    v.SetTransform(Vector2.zero, 0f, Vector2.one);
                }
            }
            if (bannerSub != "") UiKit.Txt(layer, WorldText.Face.Body, new Vector2(0, y + 26), bannerSub, 15, new Color(1, 1, 1, a * 0.85f), TextAnchor.MiddleCenter, Gd.W);
        }

        private void DrawCutin()
        {
            var tex = UiKit.Art("cutin/" + cutinKey);
            if (tex == null) return;
            var v = layer.back; var f = layer.front;
            float k = 1f - cutinT / Mathf.Max(0.1f, cutinLen);
            float a = Mathf.Clamp01(Mathf.Min(k * 8f, (1f - k) * 5f));
            float slide = (1f - Mathf.Min(1f, k * 6f)) * 120f;
            var band = new Rect(0, 96f, Gd.W, 156f);
            v.DrawRect(UiKit.Grow(band, 6f), new Color(0, 0, 0, 0.6f * a));
            v.DrawRect(band, new Color(0.03f, 0.02f, 0.06f, 0.85f * a));
            layer.img.DrawCover(tex, new Rect(slide, band.yMin, Gd.W, band.height), a, 0.4f);
            for (int gi = 0; gi < 6; gi++) { float kk = gi / 6f; f.DrawRect(new Rect(kk * 60f, band.yMin, 10f, band.height), new Color(0.03f, 0.02f, 0.06f, 0.6f * (1f - kk) * a)); }
            f.DrawRect(new Rect(0, band.yMin, Gd.W, 3), Gd.WithA(cutinCol, a));
            f.DrawRect(new Rect(0, band.yMax - 3, Gd.W, 3), Gd.WithA(cutinCol, a));
            for (int i = 0; i < 5; i++) { float ang = -0.3f + i * 0.15f; float x = 40f + i * 130f + slide * 0.5f; f.DrawLine(new Vector2(x, band.yMin), new Vector2(x + 60f * ang, band.yMax), new Color(1, 1, 1, 0.12f * a), 6f); }
        }

        private void DrawCallCutin()
        {
            var kk = Data.KamiOf(callKami);
            if (kk == null) return;
            var v = layer.back; var f = layer.front;
            float k = 1f - callT / CALL_T;
            float a = Mathf.Clamp01(Mathf.Min(k * 10f, (1f - k) * 6f));
            Color col = Data.ColorOf(kk.color);
            v.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.02f, 0.01f, 0.05f, 0.78f * a));
            float cy = Gd.H * 0.42f;
            v.DrawColoredPolygon(new[] { new Vector2(-40, cy - 150), new Vector2(Gd.W + 40, cy - 230), new Vector2(Gd.W + 40, cy + 230), new Vector2(-40, cy + 150) }, Gd.WithA(col, 0.22f * a));
            for (int i = 0; i < 7; i++) { float x0 = -60f + i * 120f + (1f - a) * 80f; v.DrawLine(new Vector2(x0, cy + 240), new Vector2(x0 + 140, cy - 240), new Color(1, 1, 1, 0.10f * a), 10f); }
            var tex = UiKit.Art("cutin/call");
            var pr = new Rect(0, cy - 240f, Gd.W, 440f);
            if (tex != null)
            {
                float slide = (1f - Mathf.Min(1f, k * 5f)) * 90f;
                float tw = tex.width, th = tex.height;
                float sw = Mathf.Min(tw, th * pr.width / pr.height);
                float sx = Mathf.Clamp(tw - sw - 40f + slide, 0f, tw - sw);
                v.DrawRect(UiKit.Grow(pr, 3f), new Color(0, 0, 0, 0.6f * a));
                layer.img.Draw(tex, pr, new Rect(sx, 0f, sw, th), new Color(1, 1, 1, a));
                for (int gi = 0; gi < 10; gi++) { float gk = gi / 10f; f.DrawRect(new Rect(pr.xMin, pr.yMax - 170f + gk * 170f, pr.width, 18f), new Color(0.03f, 0.02f, 0.06f, 0.92f * gk * a)); }
                f.DrawRect(new Rect(0, pr.yMin, Gd.W, 2), Gd.WithA(col, a));
                f.DrawRect(new Rect(0, pr.yMax - 2, Gd.W, 2), Gd.WithA(col, a));
            }
            float nameY = pr.yMax - 92f;
            UiKit.Txt(layer, WorldText.Face.Body, new Vector2(22, nameY - 34), kk.name + (callGreater ? "　大神招き" : "　神招き"), 13, Gd.WithA(col, a));
            UiKit.Txt(layer, WorldText.Face.Display, new Vector2(20, nameY + 4), kk.call, 36, new Color(1, 1, 1, a), TextAnchor.MiddleLeft, Gd.W * 0.6f);
            f.DrawRect(new Rect(20, nameY + 14, Gd.W * 0.5f, 3), Gd.WithA(col, a));
            if (!string.IsNullOrEmpty(kk.call_line)) UiKit.Para(layer, WorldText.Face.Display, new Vector2(24, nameY + 48), "「" + kk.call_line + "」", Gd.W - 48, 18, 2, new Color(1, 0.97f, 0.9f, a));
            if (!string.IsNullOrEmpty(kk.call_desc))
            {
                f.DrawRect(new Rect(0, pr.yMax + 6, Gd.W, 34), new Color(0.03f, 0.02f, 0.06f, 0.85f * a));
                UiKit.Txt(layer, WorldText.Face.Body, new Vector2(20, pr.yMax + 29), kk.call_desc, 15, Gd.WithA(Color.Lerp(col, Color.white, 0.35f), a), TextAnchor.MiddleCenter, Gd.W - 40);
            }
        }

        private void DrawIntro()
        {
            var v = layer.back; var f = layer.front;
            float k = introT / 3.2f;
            float a = Mathf.Clamp01(Mathf.Min(k * 6f, (1f - k) * 6f));
            Color col = introFinal ? new Color(1, 0.3f, 0.35f) : new Color(1, 0.6f, 0.65f);
            var tex = UiKit.Art("boss/" + introKey);
            if (tex != null)
            {
                var pr = new Rect(0, 100, Gd.W, 300);
                v.DrawRect(UiKit.Grow(pr, 4f), new Color(0, 0, 0, 0.5f * a));
                layer.img.DrawCover(tex, pr, a, 0.3f);
                for (int gi = 0; gi < 8; gi++) { float kk = gi / 8f; f.DrawRect(new Rect(0, pr.yMax - 120f + kk * 120f, Gd.W, 16f), new Color(0.03f, 0.02f, 0.06f, 0.9f * kk * a)); }
                f.DrawRect(new Rect(0, pr.yMin, Gd.W, 2), Gd.WithA(col, a));
                f.DrawRect(new Rect(0, pr.yMax - 2, Gd.W, 2), Gd.WithA(col, a));
            }
            var hero = UiKit.Art("portrait/calm");
            if (hero != null)
            {
                float hh = 230f, hw = hh * hero.width / (float)hero.height;
                layer.img.Draw(hero, new Rect(-10f - (1f - a) * 60f, 400f, hw, hh), new Color(1, 1, 1, a));
            }
            float x = Gd.W - 90f;
            f.DrawRect(new Rect(x - 46, 110, 92, 330), new Color(0, 0, 0, 0.55f * a));
            f.DrawRect(new Rect(x - 46, 110, 92, 330), Gd.WithA(col, 0.7f * a), false, 1.5f);
            f.DrawRect(new Rect(x - 40, 116, 80, 318), Gd.WithA(col, 0.25f * a), false, 1f);
            UiKit.Vtxt(layer, WorldText.Face.Display, new Vector2(x + 10, 150), introName, introName.Length <= 4 ? 34 : 30, new Color(1, 1, 1, a));
            UiKit.Vtxt(layer, WorldText.Face.Body, new Vector2(x - 24, 136), introTitle, 13, Gd.WithA(col, a));
        }

        /// <summary>現在の構成（小休止・結果画面）：神々と神器、能力。</summary>
        public void DrawBuild(UiLayer l, Player p, float y0)
        {
            float y = y0;
            foreach (var id in p.gods)
            {
                var k = Data.KamiOf(id);
                if (k == null) continue;
                UiKit.KamiRing(l, p, id, new Vector2(90, y + 4), 14f, _t, 1f, true);
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(116, y), k.name + (p.IsMain(id) ? "（主神）" : "（副神）"), 14, Gd.WithA(Data.ColorOf(k.color), 0.95f));
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(116, y + 16), $"{k.weapon}　神格 Lv.{p.KamiLv(id)}　威力 ×{p.KamiPower(id):F2}", 11, new Color(0.9f, 0.92f, 1f, 0.85f));
                y += 42f;
            }
            y += 6f;
            foreach (var kv in p.boons)
            {
                var b = Data.Boon(kv.Key);
                if (b == null) continue;
                Color col = Data.ColorOf(RarityTable.Colors[Mathf.Clamp(kv.Value.rar, 0, 5)]);
                UiKit.Txt(l, WorldText.Face.Bold, new Vector2(70, y), RarityTable.Names[Mathf.Clamp(kv.Value.rar, 0, 5)], 11, col);
                UiKit.Txt(l, WorldText.Face.Display, new Vector2(92, y), b.name + (kv.Value.lv > 1 ? $" Lv{kv.Value.lv}" : ""), 13, new Color(1, 1, 1, 0.95f));
                UiKit.Txt(l, WorldText.Face.Body, new Vector2(92, y + 15), Boons.Describe(b, kv.Value.rar, kv.Value.lv), 10, new Color(0.85f, 0.88f, 1f, 0.8f));
                y += 32f;
            }
        }
    }
}
