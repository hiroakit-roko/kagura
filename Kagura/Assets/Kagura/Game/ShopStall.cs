using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 市の屋台：波を越えたあと稀に上から流れてくる。自機が触れると市が開く（ShopView）。
    /// 絵は Resources/Art/shop/stall.png（透過）があればそれを、無ければ提灯の屋台を描く。
    /// </summary>
    public class ShopStall : MonoBehaviour
    {
        public Vector2 pos;
        public bool Active;
        public const float R = 46f;
        private float _t;
        private Vec _vec, _vecTop;
        private SpriteRenderer _spr;
        private static Sprite _sprite; private static bool _spriteTried;

        public static ShopStall Create(Transform parent)
        {
            var go = new GameObject("shop_stall");
            go.transform.SetParent(parent, false);
            var s = go.AddComponent<ShopStall>();
            s._vec = Vec.Create(go.transform, "vec", Gd.ZEnemy - 1);
            var sgo = new GameObject("spr"); sgo.transform.SetParent(go.transform, false);
            s._spr = sgo.AddComponent<SpriteRenderer>(); s._spr.sortingOrder = Gd.ZEnemy; s._spr.enabled = false;
            s._vecTop = Vec.Create(go.transform, "vec_top", Gd.ZEnemy + 1);
            go.SetActive(false);
            return s;
        }

        private static Sprite Art()
        {
            if (_spriteTried) return _sprite;
            _spriteTried = true;
            var tex = Resources.Load<Texture2D>("Art/shop/stall");
            _sprite = tex != null ? Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f), 1f) : null;
            return _sprite;
        }

        public void Spawn(Vector2 p)
        {
            pos = p; _t = 0f; Active = true;
            gameObject.SetActive(true);
            var sp = Art();
            _spr.enabled = sp != null;
            if (sp != null)
            {
                _spr.sprite = sp;
                float sc = R * 2.6f / Mathf.Max(sp.rect.height, 1f);
                _spr.transform.localScale = new Vector3(sc, sc, 1f);
            }
            transform.position = Gd.ToWorld(pos);
            Draw();
        }

        public void Despawn() { Active = false; gameObject.SetActive(false); }

        public void Tick(float dt)
        {
            _t += dt;
            pos.y += 34f * dt;                      // ゆっくり流れて下へ
            pos.x += Mathf.Sin(_t * 0.6f) * 12f * dt;
            if (pos.y > Gd.H + 90f) { Despawn(); return; }
            transform.position = Gd.ToWorld(pos);
            Draw();
        }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            var gold = Gd.C_GOLD;
            v.Glow(Vector2.zero, R * 2.4f, Gd.WithA(new Color(1f, 0.75f, 0.45f), 0.35f + 0.1f * Mathf.Sin(_t * 3f)));
            if (!_spr.enabled)
            {
                // 屋台：柱・屋根・提灯・のれん
                var wood = new Color(0.30f, 0.16f, 0.10f);
                var roof = new Color(0.55f, 0.12f, 0.16f);
                v.DrawRect(new Rect(-34, -6, 6, 44), wood); v.DrawRect(new Rect(28, -6, 6, 44), wood);
                v.DrawColoredPolygon(new[] { new Vector2(-46, -8), new Vector2(46, -8), new Vector2(36, -30), new Vector2(-36, -30) }, roof);
                v.DrawRect(new Rect(-46, -10, 92, 4), new Color(0.85f, 0.75f, 0.4f));
                v.DrawRect(new Rect(-30, 4, 60, 20), new Color(0.12f, 0.10f, 0.25f, 0.95f));   // のれん
                for (int i = 0; i < 3; i++) v.DrawLine(new Vector2(-30 + 20 * (i + 0.5f), 4), new Vector2(-30 + 20 * (i + 0.5f), 24), new Color(0, 0, 0, 0.35f), 1f);
                v.DrawRect(new Rect(-40, 24, 80, 10), wood);
                foreach (float x in new[] { -40f, 40f })
                {
                    float sway = Mathf.Sin(_t * 2.2f + x) * 2f;
                    v.DrawLine(new Vector2(x, -30), new Vector2(x + sway, -20), new Color(0.2f, 0.1f, 0.05f), 1.5f);
                    v.DrawCircle(new Vector2(x + sway, -12), 9f, new Color(1f, 0.35f, 0.25f));
                    v.DrawArc(new Vector2(x + sway, -12), 9f, 0, Gd.TAU, 16, new Color(0.5f, 0.1f, 0.1f), 1.2f);
                    v.DrawCircle(new Vector2(x + sway - 2, -15), 3f, new Color(1f, 0.85f, 0.6f, 0.8f));
                }
            }
            v.End();
            var t = _vecTop;
            t.Begin();
            // 「市」の札と、触れる範囲の輪
            t.DrawRect(new Rect(-14, -52, 28, 22), Gd.C_PAPER);
            t.DrawRect(new Rect(-14, -52, 28, 22), Gd.WithA(gold, 0.95f), false, 1.5f);
            t.DrawArc(Vector2.zero, R, 0, Gd.TAU, 40, Gd.WithA(gold, 0.25f + 0.15f * Mathf.Sin(_t * 4f)), 1.5f);
            t.End();
        }

        /// <summary>「市」の文字（WorldText はここでは使わないので HUD 側が描く）。</summary>
        public Vector2 LabelPos => pos + new Vector2(0, -41f);
    }
}
