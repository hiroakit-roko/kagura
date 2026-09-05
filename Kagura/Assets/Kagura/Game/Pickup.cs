using UnityEngine;

namespace Kagura.Game
{
    /// <summary>勾玉（経験値）／団子（HP 回復）／詠唱の札。マグネット範囲で吸い寄せる（Godot 版 pickup.gd）。</summary>
    public class Pickup : MonoBehaviour
    {
        public const int XP = 0, HEAL = 1, MIKI = 2, ORB = 3, COIN = 4;

        public int kind;
        public float value = 3f;
        public Vector2 pos, vel;
        public float life = 14f;
        public bool Active;
        private float _t;
        private bool _pulled;
        private Vec _vec;

        private void Awake() { _vec = Vec.Create(transform, "vec", Gd.ZPickup); }

        public void Setup(Vector2 p, int k, float v)
        {
            pos = p; kind = k; value = v; _t = 0f; _pulled = false;
            vel = new Vector2(Gd.Rand(-70, 70), Gd.Rand(-130, -50));
            life = 14f;
            if (k == ORB) { life = 9999f; vel = new Vector2(Gd.Rand(-40, 40), Gd.Rand(-60, -20)); }
            if (k == COIN) life = 18f;
            Active = true;
            gameObject.SetActive(true);
            transform.position = Gd.ToWorld(pos);
            Draw();
        }

        public float Radius => kind != MIKI ? 11f : 16f;

        public void Tick(float dt, Player pl)
        {
            _t += dt;
            life -= dt;
            if (life <= 0f) { Fx.Burst(pos, ColorOf(), 4, 60f, 2f, 0.3f, true); Despawn(); return; }
            if (pl != null && pl.alive)
            {
                float d = Vector2.Distance(pos, pl.pos);
                float rangeR = pl.MagnetRange();
                if (kind == ORB) rangeR *= 1.6f;
                if (_pulled || d < rangeR || pos.y > pl.pos.y + 40f)
                {
                    _pulled = true;
                    Vector2 dir = (pl.pos - pos).normalized;
                    vel = Vector2.Lerp(vel, dir * (560f + (rangeR - d) * 2.4f), Mathf.Clamp01(12f * dt));   // 敵弾に紛れないよう速めに引き寄せる
                }
            }
            else vel = Vector2.Lerp(vel, new Vector2(0, 60f), Mathf.Clamp01(2f * dt));
            if (!_pulled)
            {
                vel.y += 190f * dt;
                vel.x = Mathf.Lerp(vel.x, 0f, Mathf.Clamp01(2f * dt));
                vel.y = Mathf.Min(vel.y, kind != MIKI ? 85f : 55f);
            }
            pos += vel * dt;
            pos.x = Mathf.Clamp(pos.x, 8f, Gd.W - 8f);
            if (pos.y > Gd.H + 30f)
            {
                if (kind == ORB) { pos = new Vector2(Mathf.Clamp(pos.x + Gd.Rand(-80, 80), 20f, Gd.W - 20f), -20f); vel = new Vector2(0, 60f); _pulled = false; }
                else { Despawn(); return; }
            }
            transform.position = Gd.ToWorld(pos);
            float rot = kind != XP ? Mathf.Sin(_t * 2.2f) * 0.35f : _t * 1.6f;
            transform.rotation = Quaternion.Euler(0, 0, -rot * Mathf.Rad2Deg);
            Draw();
        }

        public Color ColorOf()
        {
            switch (kind)
            {
                case XP: return Gd.C_XP;
                case HEAL: return Gd.C_HP;
                case ORB:
                    {
                        var pl = GameManager.I != null ? GameManager.I.player : null;
                        return pl != null && pl.MainGod() != "" ? pl.KamiColor(pl.MainGod()) : new Color(0.8f, 0.85f, 1f);
                    }
                default: return Gd.C_GOLD;
            }
        }

        public void Despawn() { Active = false; gameObject.SetActive(false); }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            Color c = ColorOf();
            float pulse = 1f + 0.12f * Mathf.Sin(_t * 7f);
            v.Glow(Vector2.zero, (kind != MIKI ? 20f : 30f) * pulse, Gd.WithA(c, 0.6f));
            UiKit.PickupShape(v, kind, c, _t, pulse);
            v.End();
        }
    }
}
