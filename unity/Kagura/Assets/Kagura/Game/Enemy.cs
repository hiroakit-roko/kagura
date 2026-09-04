using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>雑魚。種類ごとの動きと射撃。数値は Godot 版 enemy.gd に合わせる（1 単位 = 100px）。</summary>
    public class Enemy : MonoBehaviour
    {
        public string kind;
        public int wave;
        public float hp, maxHp, radius = 0.16f, speed = 0.6f, score = 10, xp = 6;
        public bool Active;

        private float _t, _fireT, _phase, _dir;
        private Color _col;
        private SpriteRenderer _sr, _glow;
        private float _flash;

        private void Awake()
        {
            _sr = gameObject.AddComponent<SpriteRenderer>();
            _sr.sortingOrder = 9;
            var g = new GameObject("glow");
            g.transform.SetParent(transform, false);
            _glow = g.AddComponent<SpriteRenderer>();
            _glow.sprite = SpriteFactory.Glow();
            _glow.sortingOrder = 8;
        }

        public void Setup(string k, int w, Vector3 pos)
        {
            kind = k; wave = w; _t = 0f; _fireT = 0f; _flash = 0f;
            _phase = Random.value * Mathf.PI * 2f;
            _dir = Random.value < 0.5f ? 1f : -1f;
            float hs = Enemies.HpScale(w);
            float ss = Enemies.SpeedScale(w);
            _sr.sprite = SpriteFactory.Circle();
            _col = new Color(1f, 0.36f, 0.5f);
            switch (k)
            {
                case "grunt":   maxHp = 22f * hs; speed = 0.9f * ss; radius = 0.16f; score = 10; xp = 6; break;
                case "weaver":  maxHp = 30f * hs; speed = 0.8f * ss; radius = 0.17f; score = 15; xp = 8; _col = new Color(0.72f, 0.45f, 1f); break;
                case "charger": maxHp = 26f * hs; speed = 2.2f * ss; radius = 0.15f; score = 15; xp = 8; _col = new Color(1f, 0.68f, 0.26f); _sr.sprite = SpriteFactory.Diamond(); break;
                case "turret":  maxHp = 70f * hs; speed = 0.35f * ss; radius = 0.22f; score = 30; xp = 14; _col = new Color(1f, 0.68f, 0.26f); _sr.sprite = SpriteFactory.Diamond(); break;
                case "splitter":maxHp = 60f * hs; speed = 0.6f * ss; radius = 0.22f; score = 25; xp = 12; break;
                case "mini":    maxHp = 10f * hs; speed = 1.4f * ss; radius = 0.10f; score = 5; xp = 2; break;
                case "spirit":  maxHp = 8f * hs; speed = 1.1f * ss; radius = 0.11f; score = 5; xp = 3; _col = new Color(0.6f, 0.85f, 1f); break;
                case "lantern": maxHp = 45f * hs; speed = 0.5f * ss; radius = 0.19f; score = 20; xp = 10; _col = new Color(1f, 0.8f, 0.4f); break;
                case "kite":    maxHp = 18f * hs; speed = 1.6f * ss; radius = 0.14f; score = 12; xp = 6; _col = new Color(0.9f, 0.9f, 1f); _sr.sprite = SpriteFactory.Diamond(); break;
                case "oni":     maxHp = 120f * hs; speed = 0.45f * ss; radius = 0.26f; score = 45; xp = 20; _col = new Color(1f, 0.3f, 0.3f); break;
                case "caster":  maxHp = 55f * hs; speed = 0.5f * ss; radius = 0.18f; score = 35; xp = 15; _col = new Color(0.8f, 0.5f, 1f); break;
                case "bomber":  maxHp = 28f * hs; speed = 1.0f * ss; radius = 0.16f; score = 15; xp = 8; _col = new Color(1f, 0.5f, 0.2f); break;
                default:        maxHp = 22f * hs; speed = 0.9f * ss; break;
            }
            hp = maxHp;
            transform.position = pos;
            transform.localScale = Vector3.one * (radius * 2f * 1.6f);
            _glow.transform.localScale = Vector3.one * 2.6f;
            _glow.color = new Color(_col.r, _col.g, _col.b, 0.35f);
            _sr.color = _col;
            Active = true;
            gameObject.SetActive(true);
        }

        public void Tick(float dt, GameManager g)
        {
            _t += dt;
            _flash = Mathf.Max(0f, _flash - dt * 6f);
            var p = transform.position;
            var pl = g.PlayerPos;
            switch (kind)
            {
                case "charger":
                    if (_t < 0.8f) p.y -= speed * 0.3f * dt;
                    else
                    {
                        Vector2 d = ((Vector2)(pl - p)).normalized;
                        p += (Vector3)(d * speed * dt);
                    }
                    break;
                case "kite":
                    p.x += _dir * speed * dt;
                    p.y -= 0.15f * dt + Mathf.Sin(_t * 3f + _phase) * 0.6f * dt;
                    break;
                case "turret":
                case "lantern":
                case "caster":
                    if (p.y > g.Bounds.yMax - 2.6f) p.y -= speed * dt;
                    else p.x += Mathf.Sin(_t * 1.2f + _phase) * 0.4f * dt;
                    break;
                default:
                    p.y -= speed * dt;
                    p.x += Mathf.Sin(_t * 2.2f + _phase) * 0.7f * dt;
                    break;
            }
            transform.position = p;

            // 射撃：画面の上 3/4 にいる間、間隔は Godot 版 _cool に合わせる
            _fireT -= dt;
            if (_fireT <= 0f && p.y < g.Bounds.yMax - 0.4f && p.y > g.Bounds.yMin + g.Bounds.height * 0.25f)
            {
                _fireT = Cool(2.4f, 3.8f);
                Vector2 dir = ((Vector2)(pl - p)).normalized;
                float spd = 1.6f + wave * 0.025f;
                var c = new Color(1f, 0.45f, 0.75f);
                switch (kind)
                {
                    case "spirit": case "mini": case "kite": _fireT = 99f; break;   // 撃たない
                    case "turret":
                        for (int i = 0; i < 8; i++) { float a = Mathf.PI * 2f * i / 8f + _t; g.SpawnEnemyBullet(p, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * spd * 0.8f, 10f, c); }
                        break;
                    case "caster":
                        for (int i = -1; i <= 1; i++) { var d2 = Rotate(dir, i * 0.25f); g.SpawnEnemyBullet(p, d2 * spd, 10f, c); }
                        break;
                    default:
                        g.SpawnEnemyBullet(p, dir * spd, 10f, c);
                        break;
                }
            }

            if (p.y < g.Bounds.yMin - 0.9f || p.y > g.Bounds.yMax + 4.2f || p.x < g.Bounds.xMin - 1.5f || p.x > g.Bounds.xMax + 1.5f)
                Despawn();

            _sr.color = Color.Lerp(_col, Color.white, _flash);
        }

        private float Cool(float lo, float hi) => Random.Range(lo, hi) * 1.18f * Mathf.Clamp(0.88f - wave * 0.012f, 0.62f, 1f);

        private static Vector2 Rotate(Vector2 v, float a)
        {
            float c = Mathf.Cos(a), s = Mathf.Sin(a);
            return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
        }

        /// <summary>ダメージ。倒したら true。</summary>
        public bool TakeDamage(float d)
        {
            hp -= d;
            _flash = 1f;
            if (hp <= 0f) { Despawn(); return true; }
            return false;
        }

        public void Despawn()
        {
            Active = false;
            gameObject.SetActive(false);
        }
    }
}
