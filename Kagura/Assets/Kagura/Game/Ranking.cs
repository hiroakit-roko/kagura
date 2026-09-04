using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using Kagura.Core;
using Face = Kagura.Game.WorldText.Face;

namespace Kagura.Game
{
    /// <summary>記録の一覧（この端末／世界）。行を選ぶとその走りの中身（神々・神宝・版）が見える。Godot 版 RankingView。</summary>
    public class RankingView
    {
        public bool visible;
        public int tab, sel;
        public List<Records.Entry> rows = new List<Records.Entry>();
        public string status = "";
        private float _t;
        private readonly UiLayer L;
        private const float ROW_H = 26f, LIST_Y = 150f, DETAIL_H = 330f;
        private const int MAX_ROWS = 12;

        public RankingView(Transform parent) { L = UiLayer.Create(parent, "ranking", Gd.ZHud + 30); L.Clear(); }

        public void Open() { visible = true; sel = 0; SetTab(0); }
        public void Close() { visible = false; L.Clear(); }

        private void SetTab(int t)
        {
            tab = t; sel = 0;
            if (tab == 0)
            {
                rows = new List<Records.Entry>(Records.Entries);
                status = rows.Count > 0 ? "" : "まだ記録がない";
                return;
            }
            var net = Net.I;
            if (net == null || !net.Configured) { rows = new List<Records.Entry>(); status = "世界の記録はまだ繋がっていない"; return; }
            rows = new List<Records.Entry>();
            status = "読み込み中…";
            net.FetchTop(MAX_ROWS, (ok, got) =>
            {
                if (tab != 1) return;
                if (!ok) { status = "読み込めなかった"; return; }
                rows = got;
                status = rows.Count > 0 ? "" : "まだ誰の記録もない";
            });
        }

        private Rect TabRect(int i) => new Rect(Gd.W * 0.5f - 150f + i * 150f, 96f, 140f, 34f);
        private Rect CloseRect() => new Rect(Gd.W - 96f, 20f, 76f, 32f);
        private Rect RowRect(int i) => new Rect(24f, LIST_Y + i * ROW_H, Gd.W - 48f, ROW_H);
        private int RowsShown() { float avail = Gd.H - LIST_Y - DETAIL_H - 40f; return Mathf.Clamp((int)(avail / ROW_H), 4, Mathf.Min(rows.Count, MAX_ROWS)); }

        /// <summary>入力。閉じたら true。</summary>
        public bool HandleInput(bool tap, Vector2 tapPx)
        {
            var kb = Keyboard.current;
            if (kb != null)
            {
                if (kb.leftArrowKey.wasPressedThisFrame || kb.aKey.wasPressedThisFrame) SetTab(0);
                else if (kb.rightArrowKey.wasPressedThisFrame || kb.dKey.wasPressedThisFrame) SetTab(1);
                else if (kb.upArrowKey.wasPressedThisFrame || kb.wKey.wasPressedThisFrame) sel = Mathf.Max(0, sel - 1);
                else if (kb.downArrowKey.wasPressedThisFrame || kb.sKey.wasPressedThisFrame) sel = Mathf.Min(Mathf.Max(RowsShown() - 1, 0), sel + 1);
                else if (kb.escapeKey.wasPressedThisFrame || kb.rKey.wasPressedThisFrame || kb.enterKey.wasPressedThisFrame || kb.spaceKey.wasPressedThisFrame) { Close(); return true; }
            }
            if (tap)
            {
                if (CloseRect().Contains(tapPx)) { Sfx.Play("select", -10f); Close(); return true; }
                for (int i = 0; i < 2; i++) if (TabRect(i).Contains(tapPx)) { Sfx.Play("select", -12f); SetTab(i); return false; }
                for (int i = 0; i < RowsShown(); i++) if (RowRect(i).Contains(tapPx)) { sel = i; return false; }
            }
            return false;
        }

        public void Tick(float dt)
        {
            if (!visible) return;
            _t += dt;
            L.Begin();
            Draw();
            L.End();
        }

        private void Txt(Face f, Vector2 pos, string s, float size, Color col, TextAnchor align = TextAnchor.MiddleLeft, float width = -1f) => UiKit.Txt(L, f, pos, s, size, col, align, width);

        private void Draw()
        {
            L.back.DrawRect(new Rect(0, 0, Gd.W, Gd.H), new Color(0.03f, 0.02f, 0.06f, 0.94f));
            UiKit.Pattern(L.back, new Rect(0, 0, Gd.W, Gd.H), Gd.WithA(Gd.C_GOLD, 0.05f), 52f, _t);
            Txt(Face.Display, new Vector2(0, 66), "記録", 40, Gd.C_GOLD, TextAnchor.MiddleCenter, Gd.W);
            var cr = CloseRect();
            UiKit.Panel(L.back, cr, Gd.C_GOLD, 1f, 0.8f);
            Txt(Face.Bold, new Vector2(cr.x, cr.y + 21), "閉じる", 13, Color.white, TextAnchor.MiddleCenter, cr.width);
            string[] tabs = { "この端末", "世界" };
            for (int i = 0; i < 2; i++)
            {
                var r = TabRect(i); bool on = i == tab;
                UiKit.Panel(L.back, r, on ? Gd.C_GOLD : new Color(0.5f, 0.5f, 0.6f), 1f, on ? 0.85f : 0.5f);
                Txt(Face.Bold, new Vector2(r.x, r.y + 22), tabs[i], 14, on ? Color.white : new Color(1, 1, 1, 0.55f), TextAnchor.MiddleCenter, r.width);
            }
            float hx = 24f, w = Gd.W - 48f;
            Txt(Face.Body, new Vector2(hx + 34, LIST_Y - 8), "名", 10, new Color(1, 1, 1, 0.5f));
            Txt(Face.Body, new Vector2(hx, LIST_Y - 8), "功徳", 10, new Color(1, 1, 1, 0.5f), TextAnchor.MiddleRight, w - 250f);
            Txt(Face.Body, new Vector2(hx, LIST_Y - 8), "到達", 10, new Color(1, 1, 1, 0.5f), TextAnchor.MiddleRight, w - 130f);
            Txt(Face.Body, new Vector2(hx, LIST_Y - 8), "版", 10, new Color(1, 1, 1, 0.5f), TextAnchor.MiddleRight, w - 12f);
            if (status != "") Txt(Face.Body, new Vector2(0, LIST_Y + 40), status, 13, new Color(1, 1, 1, 0.6f), TextAnchor.MiddleCenter, Gd.W);
            int shown = RowsShown();
            for (int i = 0; i < shown; i++)
            {
                var e = rows[i];
                var r = RowRect(i);
                bool on = i == sel;
                if (on) { L.back.DrawRect(r, Gd.WithA(Gd.C_GOLD, 0.16f)); L.front.DrawRect(r, Gd.WithA(Gd.C_GOLD, 0.6f), false, 1f); }
                var col = on ? Gd.C_GOLD : new Color(0.92f, 0.92f, 1f);
                float ty = r.y + 18f;
                Txt(Face.Bold, new Vector2(hx + 8, ty), (i + 1).ToString(), 12, Gd.WithA(col, i < 3 ? 1f : 0.7f));
                Txt(Face.Body, new Vector2(hx + 34, ty), e.name, 13, col);
                Txt(Face.Bold, new Vector2(hx, ty), e.score.ToString(), 13, col, TextAnchor.MiddleRight, w - 250f);
                Txt(Face.Body, new Vector2(hx, ty), Records.ReachText(e), 12, Gd.WithA(col, 0.9f), TextAnchor.MiddleRight, w - 130f);
                Txt(Face.Body, new Vector2(hx, ty), e.version != "" ? "v" + e.version : "-", 11, Gd.WithA(col, 0.8f), TextAnchor.MiddleRight, w - 12f);
            }
            if (sel >= 0 && sel < rows.Count) DrawDetail(rows[sel], LIST_Y + shown * ROW_H + 16f);
        }

        private void DrawDetail(Records.Entry e, float y0)
        {
            float x0 = 24f, w = Gd.W - 48f, h = DETAIL_H;
            if (y0 + h > Gd.H - 16f) y0 = Gd.H - 16f - h;
            UiKit.Panel(L.back, new Rect(x0, y0, w, h), Gd.C_GOLD, 1f, 0.88f);
            float y = y0 + 24f;
            Txt(Face.Display, new Vector2(x0 + 14, y), e.name + "　" + e.score, 18, Color.white);
            Txt(Face.Body, new Vector2(x0, y), e.date + "　" + Records.ReachText(e) + "　位 " + e.lv, 11, new Color(1, 1, 1, 0.75f), TextAnchor.MiddleRight, w - 14f);
            y += 14f;
            var gods = e.GodList(); var klv = e.KamiLvMap(); var boons = e.BoonMap();
            var duos = new List<string>();
            for (int gi = 0; gi < gods.Count; gi++)
            {
                string gid = gods[gi];
                var k = Data.KamiOf(gid);
                if (k == null) continue;
                y += 22f;
                var kc = Data.ColorOf(k.color);
                UiKit.Emblem(L.front, k.emblem, new Vector2(x0 + 26f, y + 2f), 11f, kc, Data.ColorOf(k.color2), _t, 1f);
                Txt(Face.Bold, new Vector2(x0 + 42f, y + 6f), (gi == 0 ? "主神 " : "副神 ") + k.name + "　神格 " + (klv.TryGetValue(gid, out var lv0) ? lv0 : 1), 12, Gd.WithA(kc, 0.95f));
                var parts = new List<string>();
                foreach (var kv in boons)
                {
                    var b = Data.Boon(kv.Key);
                    if (b == null || b.kami != gid) continue;
                    if (!string.IsNullOrEmpty(b.kami2)) { if (!duos.Contains(kv.Key)) duos.Add(kv.Key); continue; }
                    string tag = b.IsLegendary ? "伝説 " : "";
                    parts.Add(tag + b.name + (kv.Value.lv > 1 && tag == "" ? " Lv" + kv.Value.lv : ""));
                }
                y += 18f;
                Txt(Face.Body, new Vector2(x0 + 42f, y + 4f), parts.Count > 0 ? string.Join("・", parts) : "能力なし", 11, new Color(0.92f, 0.94f, 1f, 0.9f), TextAnchor.MiddleLeft, w - 56f);
            }
            if (gods.Count == 0) { y += 22f; Txt(Face.Body, new Vector2(x0 + 14, y + 6f), "神なし", 12, new Color(1, 1, 1, 0.6f)); }
            var extra = new List<string>();
            foreach (var did in duos) { var b = Data.Boon(did); if (b != null) extra.Add("双神 " + b.name); }
            foreach (var cid in e.CurseList()) { var cu = Data.Curse(cid); if (cu != null) extra.Add("禍 " + cu.name); }
            if (extra.Count > 0) { y += 20f; Txt(Face.Body, new Vector2(x0 + 14, y + 6f), string.Join("・", extra), 11, new Color(1, 0.85f, 0.9f, 0.9f), TextAnchor.MiddleLeft, w - 28f); }
            y += 22f;
            var fam = Familiar.InfoOf(e.familiar);
            var names = e.RelicList().Select(id => Data.Relic(id)).Where(r => r != null).Select(r => r.name).ToList();
            Txt(Face.Body, new Vector2(x0 + 14, y + 6f), "使い魔 " + (fam != null ? fam.name : "なし") + "　　神宝 " + (names.Count > 0 ? string.Join("・", names) : "なし"), 11, new Color(0.92f, 0.94f, 1f, 0.9f), TextAnchor.MiddleLeft, w - 28f);
            string dur = e.duration > 0f ? $"{(int)e.duration / 60} 分 {(int)e.duration % 60:00} 秒" : "";
            string vtxt = e.version != "" ? $"版 v{e.version}（{e.commit}）" : "版 不明（古い記録）";
            Txt(Face.Body, new Vector2(x0 + 14, y0 + h - 12f), vtxt + "　" + e.platform + "　" + dur, 11, new Color(1, 1, 1, 0.6f), TextAnchor.MiddleLeft, w - 28f);
        }
    }
}
