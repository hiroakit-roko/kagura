using System.Collections.Generic;
using UnityEngine;
using Kagura.Core;
using Face = Kagura.Game.WorldText.Face;

namespace Kagura.Game
{
    /// <summary>市の品：団子・時限の札（item）か神宝（relic）。</summary>
    public class ShopOffer
    {
        public string type;          // "item" | "relic"
        public ShopItemDef item;
        public RelicDef relic;
        public int price;
        public bool sold;
        public string Id => type == "item" ? item.id : relic.id;
        public string Name => type == "item" ? item.name : relic.name;
        public string Desc => type == "item" ? item.desc : relic.desc;
    }

    /// <summary>市（ショップ）の画面：上の段に団子と札、下の段に神宝。両で買う。</summary>
    public class ShopView : ChoiceView
    {
        public List<ShopOffer> offers = new List<ShopOffer>();
        public int ryo;
        private const float IW = 210f, IH = 192f, IY = 150f, RW = 176f, RH = 262f, RY = 372f;
        public const int LEAVE = 99;
        public ShopView(Transform parent) : base(parent, "shop") { }

        public void Open(List<ShopOffer> o, int money) { offers = o; ryo = money; Show(); }
        public override int Count() => offers.Count;
        public override Rect RectOf(int i) => i < 2 ? Row(i, 2, IW, IH, IY, 16f) : Row(i - 2, 3, RW, RH, RY, 10f);
        public Rect LeaveRect => new Rect(Gd.W * 0.5f - 110f, RY + RH + 26f, 220f, 50f);
        public override int CardAt(Vector2 p) { if (LeaveRect.Contains(p)) return LEAVE; return base.CardAt(p); }

        public static string RarName(int rar) => rar >= 3 ? "秘" : rar == 2 ? "稀" : "並";
        public static Color RarColor(int rar) => rar >= 3 ? new Color(0.85f, 0.55f, 1f) : rar == 2 ? new Color(0.55f, 0.8f, 1f) : new Color(0.9f, 0.9f, 0.9f);

        protected override void Draw()
        {
            Backdrop(Gd.C_GOLD);
            float a = anim;
            Txt(Face.Display, new Vector2(0, 92), "市", 52, Gd.WithA(Gd.C_GOLD, a), TextAnchor.MiddleCenter, Gd.W);
            // 手持ちの両
            var coin = new Vector2(Gd.W - 96f, 70f);
            UiKit.Coin(L.front, coin, 9f, a);
            Txt(Face.Display, new Vector2(coin.x + 14f, coin.y + 8f), ryo + " 両", 22, Gd.WithA(Gd.C_GOLD, a));
            for (int i = 0; i < offers.Count; i++)
            {
                var o = offers[i];
                var r = RectOf(i);
                bool sel = i == hover && !o.sold;
                float pop = Mathf.Clamp01(a * 1.5f - i * 0.08f);
                if (pop <= 0f) continue;
                bool can = !o.sold && ryo >= o.price;
                float dim = o.sold ? 0.35f : can ? 1f : 0.55f;
                Color col = o.type == "relic" ? RarColor(o.relic.rar) : Gd.C_GOLD;
                var rr = UiKit.Grow(r, (sel ? 3f : 0f) - (1f - pop) * 20f);
                CardBg(rr, col, sel, pop * dim);
                bool isItem = o.type == "item";
                float artH = isItem ? 84f : 120f;
                var tex = UiKit.Art((isItem ? "item/" : "relic/") + o.Id);
                var pr = new Rect(rr.x + 4, rr.y + 4, rr.width - 8, artH);
                if (tex != null) { L.img.DrawCover(tex, pr, pop * dim, 0.5f); Fade(pr, 26f, pop * dim, 5); }
                else
                {
                    var c = pr.center;
                    L.back.DrawCircle(c, 30f, Gd.WithA(col, 0.12f * pop * dim));
                    L.front.DrawArc(c, 26f, 0, Gd.TAU, 32, Gd.WithA(col, 0.9f * pop * dim), 2f);
                    Txt(Face.Display, new Vector2(c.x - 30, c.y + 10), o.type == "relic" ? (o.relic.mark ?? "") : o.Name.Substring(0, 1), 26, new Color(1, 0.96f, 0.85f, pop * dim), TextAnchor.MiddleCenter, 60, false);
                }
                if (o.type == "relic")
                    Txt(Face.Bold, new Vector2(rr.x + 8, rr.y + 16), RarName(o.relic.rar), 12, Gd.WithA(col, pop * dim));
                Txt(Face.Display, new Vector2(rr.x, rr.y + artH + 24f), o.Name, isItem ? 19 : 18, new Color(1, 1, 1, pop * dim), TextAnchor.MiddleCenter, rr.width);
                Para(Face.Body, new Vector2(rr.x + 10, rr.y + artH + 44f), o.Desc, rr.width - 20, 12, isItem ? 2 : 3, new Color(0.92f, 0.94f, 1f, pop * dim * 0.95f), TextAnchor.MiddleCenter);
                // 値札
                var tag = new Rect(rr.x + 8, rr.yMax - 30f, rr.width - 16, 22f);
                L.front.DrawRect(tag, new Color(0, 0, 0, 0.4f * pop));
                if (o.sold) Txt(Face.Display, new Vector2(tag.x, tag.center.y + 7f), "売切", 15, new Color(1, 1, 1, 0.6f * pop), TextAnchor.MiddleCenter, tag.width);
                else
                {
                    Color pc = can ? Gd.C_GOLD : new Color(1f, 0.45f, 0.45f);
                    UiKit.Coin(L.front, new Vector2(tag.center.x - 24f, tag.center.y), 6f, pop);
                    Txt(Face.Display, new Vector2(tag.center.x - 14f, tag.center.y + 7f), o.price + " 両", 15, Gd.WithA(pc, pop));
                }
            }
            var lr = LeaveRect;
            bool lsel = hover == LEAVE;
            L.front.DrawRect(UiKit.Grow(lr, 3f), new Color(0, 0, 0, 0.4f * a));
            L.front.DrawRect(lr, new Color(0.09f, 0.06f, 0.14f, 0.92f * a));
            L.front.DrawRect(lr, Gd.WithA(Gd.C_GOLD, (lsel ? 1f : 0.6f) * a), false, 1.2f);
            Txt(Face.Display, new Vector2(lr.x, lr.center.y + 8f), "去る", 20, new Color(1, 1, 1, a), TextAnchor.MiddleCenter, lr.width);
        }
    }
}
