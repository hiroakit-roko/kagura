using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 自機弾／敵弾（Godot 版 bullet.gd）。貫通・追尾・反射・消弾・押し戻し・領域・分裂・往復・渦・雷雲に対応。
    /// 座標は Godot px。当たりは GameManager が距離で取り、OnHitEnemy / OnTouchEnemyBullet を呼ぶ。
    /// </summary>
    public class Bullet : MonoBehaviour
    {
        public Vector2 pos, vel, prevPos;
        public float damage = 10f, radius = 4f, life = 5f, trailLen = 14f;
        public bool friendly = true, Active;
        public Color color = Gd.C_PBULLET;
        public int shapeKind;            // 0 弾 1 御札 2 詠唱の珠 3 狐火 4 大波 5 光鏡 6 渦 7 敵弾 8 舞扇 9 瓢箪 10 氷柱 11 風の刃 12 式神
        public int pierce;
        public float homing;             // 追尾の旋回速度 (rad/s)
        public float critChance = -1f;
        public bool isCrit;
        public string kami = "", tag = "attack";
        public bool eraser, reflect, charmed;
        public float eraseChance = 1f;
        public string zoneKind = "";
        public float zoneR = 60f, zoneLife = 2f, zoneDmg = 10f;
        public float kb;
        public string mode = "";         // cloud / vortex / boomerang
        public int splitOnHit;
        public float doom, charmChance;
        public float turnDist = 330f, returnMult = 1f;
        public Enemy target;
        public string source = "敵の弾";
        public bool grazed;              // かすり判定済み（敵弾）

        private float _t, _travel, _speed, _retarget;
        private bool _returning;
        private readonly HashSet<Enemy> _hit = new HashSet<Enemy>();
        private readonly HashSet<Bullet> _touchedEb = new HashSet<Bullet>();   // 消弾・反射の判定を済ませた敵弾（触れている間に振り直さない）
        private Vec _vec;

        private void Awake() { _vec = Vec.Create(transform, "vec", Gd.ZPBullet); }

        public void Fire(Vector2 p, Vector2 v, float dmg, bool isFriendly, Color col, float r, int kind = -1)
        {
            pos = p; prevPos = p; vel = v; damage = dmg; friendly = isFriendly; radius = r; color = col;
            shapeKind = kind >= 0 ? kind : (isFriendly ? 0 : 7);
            life = 5f;
            _t = 0f; _travel = 0f; _speed = v.magnitude; _returning = false; _retarget = 0f; _why = "";
            if (!isFriendly) DiagSpawned++;
            _hit.Clear(); _touchedEb.Clear(); grazed = false;
            pierce = 0; homing = 0f; critChance = -1f; isCrit = false; kami = ""; tag = isFriendly ? "attack" : "enemy";
            eraser = false; reflect = false; charmed = false; eraseChance = 1f; zoneKind = ""; zoneR = 60f; zoneLife = 2f; zoneDmg = 10f;
            kb = 0f; mode = ""; splitOnHit = 0; doom = 0f; charmChance = 0f; turnDist = 330f; returnMult = 1f; target = null; trailLen = 14f;
            Active = true;
            _vec.SortingOrder = isFriendly ? Gd.ZPBullet : Gd.ZEBullet;
            gameObject.SetActive(true);
            Apply();
            Draw();
        }

        public bool HasHit(Enemy e) => _hit.Contains(e);
        public bool Returning => _returning;

        public void Tick(float dt)
        {
            var g = GameManager.I;
            _t += dt;
            life -= dt;
            if (life <= 0f) { _why = "expire"; Expire(); return; }

            if (homing > 0f)
            {
                _retarget -= dt;
                if (_retarget <= 0f || target == null || !target.Active) { _retarget = 0.12f; target = FindTarget(); }
                if (target != null && target.Active)
                {
                    float want = Gd.Angle(target.pos - pos), cur = Gd.Angle(vel);
                    float diff = Mathf.DeltaAngle(cur * Mathf.Rad2Deg, want * Mathf.Rad2Deg) * Mathf.Deg2Rad;
                    float na = cur + Mathf.Clamp(diff, -homing * dt, homing * dt);
                    vel = Gd.Dir(na) * vel.magnitude;
                }
            }
            Vector2 v = vel;
            if (!friendly)
            {
                if (g.enemyBulletSlow > 0f) v *= Mathf.Max(0.35f, 1f - g.enemyBulletSlow);
                var pl = g.player;
                if (pl != null && pl.Has("tsuki_u8") && (pos - pl.pos).sqrMagnitude <= Player.VEIL_R * Player.VEIL_R) v *= 1f - Mathf.Min(pl.Val("tsuki_u8") * 0.01f, 0.6f);
            }
            prevPos = pos;
            pos += v * dt;
            _travel += v.magnitude * dt;

            if (mode == "vortex") VortexPull(dt);
            else if (mode == "cloud" && _travel > 300f) { BecomeCloud(); return; }
            else if (mode == "boomerang")
            {
                var pl = g.player;
                if (!_returning && _travel > turnDist) { _returning = true; _hit.Clear(); Sfx.Play("clap", -18f, 1.6f, 0.1f); }
                if (_returning && pl != null)
                {
                    float cur = vel.magnitude > 1f ? Gd.Angle(vel) : Gd.Angle(pl.pos - pos);
                    float wantA = Gd.Angle(pl.pos - pos);
                    float diff = Mathf.DeltaAngle(cur * Mathf.Rad2Deg, wantA * Mathf.Rad2Deg) * Mathf.Deg2Rad;
                    vel = Gd.Dir(cur + Mathf.Clamp(diff, -9f * dt, 9f * dt)) * _speed;
                    if (Vector2.Distance(pos, pl.pos) < 26f) { Combat.OnFanReturn(this); _why = "return"; Despawn(); return; }
                }
            }
            if (Gd.OffScreen(pos, shapeKind == 4 ? 200f : 60f)) { _why = "offscreen"; Despawn(); return; }
            // 自機弾の消え方の内訳（検証用）
            
            Apply();
            Draw();
        }

        private void Apply()
        {
            transform.position = Gd.ToWorld(pos);
            float rot = mode == "boomerang" ? _t * 14f : Gd.Angle(vel) + Mathf.PI * 0.5f;
            transform.rotation = Quaternion.Euler(0, 0, -rot * Mathf.Rad2Deg);
        }

        private Enemy FindTarget()
        {
            Enemy best = null; float bd = float.MaxValue;
            foreach (var e in GameManager.I.EnemyList())
            {
                if (!e.Active || _hit.Contains(e)) continue;
                float d = (pos - e.pos).sqrMagnitude;
                if (d < bd) { bd = d; best = e; }
            }
            return best;
        }

        private void VortexPull(float dt)
        {
            foreach (var e in GameManager.I.EnemyList())
            {
                if (!e.Active || e.isBoss) continue;
                float d = Vector2.Distance(e.pos, pos);
                if (d < 140f && d > 4f) { e.pos += (pos - e.pos).normalized * 260f * dt; e.AddRupture(2f); }
            }
        }

        private void BecomeCloud()
        {
            GameManager.I.SpawnZone(pos, "cloud", 170f, zoneLife > 2f ? zoneLife : 3f, zoneDmg, color);
            Despawn();
        }

        private void Expire()
        {
            if (zoneKind != "" && friendly) GameManager.I.SpawnZone(pos, zoneKind, zoneR, zoneLife, zoneDmg, color);
            Despawn();
        }

        /// <summary>自機弾が敵に触れた（GameManager が呼ぶ）。</summary>
        public void OnHitEnemy(Enemy e)
        {
            if (!Active || _hit.Contains(e)) return;
            _hit.Add(e);
            bool crit = isCrit || (critChance >= 0f && Random.value < critChance);
            Combat.Hit(e, damage * (_returning ? returnMult : 1f), pos, new HitOpts { tag = tag, kami = kami, crit = crit, dir = vel.normalized, kb = kb, doom = doom, charmChance = charmChance });
            if (mode == "cloud") { BecomeCloud(); return; }
            if (zoneKind != "") { GameManager.I.SpawnZone(pos, zoneKind, zoneR, zoneLife, zoneDmg, color); zoneKind = ""; }
            if (splitOnHit > 0) { Split(splitOnHit); splitOnHit = 0; }
            Fx.Cone(pos, -vel.normalized, color, 4, 150f, 0.9f, 2.5f, 0.22f);
            if (shapeKind == 4) pierce = 999;
            if (pierce > 0) pierce--; else { _why = "hit"; Despawn(); }
        }

        /// <summary>自機弾が敵弾に触れた：反射／消弾。</summary>
        public void OnTouchEnemyBullet(Bullet eb)
        {
            // Godot 版は area_entered（重なり始めに 1 回）で判定していた。毎フレーム振り直すと「32% で消す」が事実上 100% になる
            if (_touchedEb.Contains(eb)) return;
            _touchedEb.Add(eb);
            if (GameManager.I != null && GameManager.I.diag) DiagWhy["roll"] = DiagWhy.TryGetValue("roll", out var rn) ? rn + 1 : 1;
            if (reflect) { eb.ReflectToFriendly(damage); Sfx.Play("deflect", -14f, Gd.Rand(0.95f, 1.15f), 0.03f); }
            else if (eraser && Random.value < eraseChance) { eb.Vanish("eraser:" + kami + ":" + tag); Combat.OnErase(this); }
        }

        private void Split(int n)
        {
            Fx.Burst(pos, new Color(0.85f, 0.95f, 1f), 8, 200f, 3f, 0.35f);
            Sfx.Play("hit_ice", -10f, 1.2f, 0.05f);
            for (int i = 0; i < n; i++)
            {
                float a = -Mathf.PI * 0.5f + (i - (n - 1) * 0.5f) * (Mathf.PI / n) + Gd.Rand(-0.15f, 0.15f);
                var b = GameManager.I.SpawnPlayerBullet(pos, Gd.Dir(a) * 420f, damage * 0.4f, new Color(0.85f, 0.95f, 1f), 4f, 0);
                b.kami = kami; b.tag = "attack"; b.trailLen = 10f; b.life = 0.7f; b.critChance = critChance;
            }
        }

        public void ReflectToFriendly(float newDmg)
        {
            if (friendly) return;
            Fx.Sparks(pos, -vel.normalized, new Color(1f, 0.9f, 0.6f), 5, 300f);
            var target = Combat.NearestEnemy(pos, 9999f);
            Vector2 dir = target != null ? (target.pos - pos).normalized : -vel.normalized;
            var b = GameManager.I.SpawnPlayerBullet(pos, dir * Mathf.Max(vel.magnitude, 420f), newDmg, new Color(1f, 0.9f, 0.6f), radius, 0);
            b.tag = "deflect"; b.kami = "ama"; b.trailLen = 16f;
            Despawn();
        }

        public void Vanish(string why = "vanish")
        {
            if (!Active) return;
            _why = why;
            Fx.Burst(pos, Gd.WithA(color, 0.7f), 3, 80f, 2f, 0.2f, true);
            Despawn();
        }

        /// <summary>検証用：敵弾が消えた理由の集計（?diag のときだけ意味を持つ）。</summary>
        public static readonly Dictionary<string, int> DiagWhy = new Dictionary<string, int>();
        public static int DiagSpawned;
        private string _why = "";
        public void Despawn()
        {
            if (!Active) return;
            if (GameManager.I != null && GameManager.I.diag)
            {
                string k = (friendly ? "p" + shapeKind + ":" : "") + (_why == "" ? "despawn" : _why);
                DiagWhy[k] = DiagWhy.TryGetValue(k, out var n) ? n + 1 : 1;
            }
            _why = "";
            Active = false; gameObject.SetActive(false);
        }

        // ---------- 描画（Godot 版 _draw） ----------

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            float r = radius;
            Color c = color;
            switch (shapeKind)
            {
                case 1:
                    v.Glow(Vector2.zero, r * 3f, Gd.WithA(c, 0.75f));
                    v.DrawRect(new Rect(-4.5f, -9, 9, 18), Gd.C_PAPER);
                    v.DrawRect(new Rect(-4.5f, -9, 9, 18), c, false, 1.2f);
                    v.DrawRect(new Rect(-2.5f, -5, 5, 6), new Color(0.85f, 0.2f, 0.25f, 0.95f));
                    v.DrawLine(new Vector2(0, 3), new Vector2(0, 7), Gd.C_INK, 1.2f);
                    break;
                case 2:
                    v.Glow(Vector2.zero, r * 3.4f, Gd.WithA(c, 0.6f));
                    v.DrawCircle(Vector2.zero, r * 1.4f, Gd.WithA(c, 0.55f));
                    v.DrawCircle(Vector2.zero, r * 0.9f, c);
                    v.DrawCircle(new Vector2(-r * 0.3f, -r * 0.3f), r * 0.35f, new Color(1, 1, 1, 0.9f));
                    for (int i = 0; i < 3; i++) v.DrawCircle(Gd.Dir(_t * 5f + Gd.TAU * i / 3f) * r * 1.6f, 2f, new Color(1, 1, 1, 0.7f));
                    break;
                case 3:
                    {
                        v.Glow(Vector2.zero, r * 3.2f, Gd.WithA(c, 0.75f));
                        float fl = 1f + 0.2f * Mathf.Sin(_t * 30f);
                        v.DrawColoredPolygon(new[] { new Vector2(0, -r * 2.4f * fl), new Vector2(r * 1.1f, 0), new Vector2(0, r * 1.2f), new Vector2(-r * 1.1f, 0) }, c);
                        v.DrawColoredPolygon(new[] { new Vector2(0, -r * 1.3f * fl), new Vector2(r * 0.5f, 0), new Vector2(0, r * 0.7f), new Vector2(-r * 0.5f, 0) }, new Color(1, 1, 0.85f, 0.95f));
                        break;
                    }
                case 4:
                    {
                        float w = r; var cw = new Vector2(0, w * 0.6f);
                        v.DrawArc(cw, w, Mathf.PI + 0.35f, Gd.TAU - 0.35f, 26, Gd.WithA(c, 0.25f), 18f);
                        v.DrawArc(cw, w, Mathf.PI + 0.35f, Gd.TAU - 0.35f, 26, c, 6f);
                        v.DrawArc(cw, w * 0.92f, Mathf.PI + 0.5f, Gd.TAU - 0.5f, 26, new Color(1, 1, 1, 0.8f), 2f);
                        for (int i = 0; i < 7; i++) { float a = Mathf.PI + 0.4f + (Gd.TAU - Mathf.PI - 0.8f) * i / 6f; v.DrawCircle(cw + Gd.Dir(a) * w + new Vector2(0, -4f - 3f * Mathf.Sin(_t * 12f + i)), 3f, new Color(1, 1, 1, 0.8f)); }
                        break;
                    }
                case 5:
                    v.Glow(Vector2.zero, r * 1.8f, Gd.WithA(c, 0.5f));
                    v.DrawCircle(Vector2.zero, r, Gd.WithA(new Color(1, 1, 0.95f), 0.35f));
                    v.DrawArc(Vector2.zero, r, 0, Gd.TAU, 40, c, 3f);
                    v.DrawArc(Vector2.zero, r * 0.7f, _t * 2f, _t * 2f + 2.5f, 20, new Color(1, 1, 1, 0.8f), 2f);
                    for (int i = 0; i < 8; i++) { float a = _t * 1.5f + Gd.TAU * i / 8f; v.DrawLine(Gd.Dir(a) * r * 0.8f, Gd.Dir(a) * r, new Color(1, 1, 1, 0.6f), 1.5f); }
                    break;
                case 6:
                    v.Glow(Vector2.zero, r * 2f, Gd.WithA(c, 0.5f));
                    for (int i = 0; i < 3; i++)
                    {
                        float a0 = -_t * 6f + Gd.TAU * i / 3f;
                        for (int j = 0; j < 6; j++) { float k = j / 6f; v.DrawCircle(Gd.Dir(a0 + k * 2.4f) * r * (0.3f + k * 0.9f), 2.5f + k * 2f, Gd.WithA(c, 0.9f - k * 0.5f)); }
                    }
                    v.DrawCircle(Vector2.zero, r * 0.3f, new Color(1, 1, 1, 0.9f));
                    break;
                case 8:
                    {
                        v.Glow(Vector2.zero, r * 2f, Gd.WithA(c, 0.5f));
                        float a0 = -Mathf.PI * 0.5f - 1.15f, a1 = -Mathf.PI * 0.5f + 1.15f;
                        var piv = new Vector2(0, r * 0.5f);
                        v.DrawArc(piv, r * 1.15f, a0, a1, 22, Gd.C_PAPER, r * 0.5f);
                        v.DrawArc(piv, r, a0, a1, 22, c, r * 0.16f);
                        for (int i = 0; i < 7; i++) v.DrawLine(piv, piv + Gd.Dir(Mathf.Lerp(a0, a1, i / 6f)) * r * 1.35f, Gd.C_INK, 1f);
                        v.DrawCircle(piv, r * 0.16f, Gd.C_INK);
                        v.DrawCircle(new Vector2(0, -r * 0.5f), r * 0.28f, new Color(0.85f, 0.2f, 0.3f, 0.9f));
                        break;
                    }
                case 9:
                    v.Glow(Vector2.zero, r * 3f, Gd.WithA(c, 0.75f));
                    v.DrawCircle(new Vector2(0, r * 0.5f), r, Gd.C_PAPER);
                    v.DrawCircle(new Vector2(0, -r * 0.55f), r * 0.7f, Gd.C_PAPER);
                    v.DrawArc(new Vector2(0, r * 0.5f), r, 0, Gd.TAU, 16, c, 1.5f);
                    v.DrawArc(new Vector2(0, -r * 0.55f), r * 0.7f, 0, Gd.TAU, 14, c, 1.5f);
                    v.DrawRect(new Rect(-r * 0.25f, -r * 1.5f, r * 0.5f, r * 0.4f), c);
                    v.DrawCircle(new Vector2(0, r * 0.6f), r * 0.4f, new Color(0.85f, 0.2f, 0.25f, 0.85f));
                    break;
                case 10:
                    v.Glow(Vector2.zero, r * 3f, Gd.WithA(c, 0.6f));
                    v.DrawColoredPolygon(new[] { new Vector2(0, -r * 3.2f), new Vector2(r * 0.9f, -r * 0.6f), new Vector2(r * 0.6f, r * 1.4f), new Vector2(-r * 0.6f, r * 1.4f), new Vector2(-r * 0.9f, -r * 0.6f) }, c);
                    v.DrawLine(new Vector2(0, -r * 2.6f), new Vector2(0, r), new Color(1, 1, 1, 0.9f), 1.5f);
                    break;
                case 11:
                    v.DrawArc(new Vector2(0, r * 1.2f), r * 2.6f, Mathf.PI + 0.6f, Gd.TAU - 0.6f, 12, Gd.WithA(c, 0.9f), r * 0.7f);
                    v.DrawArc(new Vector2(0, r * 1.2f), r * 2.6f, Mathf.PI + 0.8f, Gd.TAU - 0.8f, 12, new Color(1, 1, 1, 0.8f), r * 0.25f);
                    break;
                case 12:
                    {
                        float fl = Mathf.Sin(_t * 18f) * 3f;
                        v.DrawColoredPolygon(new[] { new Vector2(0, -r * 1.6f), new Vector2(r * 0.6f, r * 0.4f), new Vector2(0, 0), new Vector2(-r * 0.6f, r * 0.4f) }, Gd.C_PAPER);
                        v.DrawColoredPolygon(new[] { new Vector2(0, -r * 0.4f), new Vector2(r * 1.8f, r * 0.2f + fl), new Vector2(r * 0.3f, r * 0.5f) }, Gd.C_PAPER);
                        v.DrawColoredPolygon(new[] { new Vector2(0, -r * 0.4f), new Vector2(-r * 1.8f, r * 0.2f + fl), new Vector2(-r * 0.3f, r * 0.5f) }, Gd.C_PAPER);
                        v.DrawCircle(new Vector2(0, -r * 0.2f), r * 0.3f, new Color(0.85f, 0.2f, 0.25f, 0.9f));
                        break;
                    }
                case 7:
                    {
                        v.Glow(Vector2.zero, r * 3.2f, Gd.WithA(c, 0.75f));
                        float fl2 = 1f + 0.25f * Mathf.Sin(_t * 26f);
                        v.DrawCircle(Vector2.zero, r * 1.1f, c);
                        v.DrawColoredPolygon(new[] { new Vector2(0, r * 2.6f * fl2), new Vector2(r * 0.9f, 0), new Vector2(-r * 0.9f, 0) }, Gd.WithA(c, 0.7f));
                        v.DrawCircle(Vector2.zero, r * 0.5f, new Color(1, 1, 1, 0.95f));
                        break;
                    }
                default:
                    v.DrawLine(new Vector2(0, trailLen), Vector2.zero, new Color(c.r, c.g, c.b, 0.18f), r * 2.2f);
                    v.DrawLine(new Vector2(0, trailLen * 0.55f), Vector2.zero, new Color(c.r, c.g, c.b, 0.4f), r * 1.2f);
                    v.Glow(Vector2.zero, r * 3.2f, Gd.WithA(c, 0.75f));
                    v.DrawLine(new Vector2(0, r * 0.7f), new Vector2(0, -r * 0.9f), c, r * 2f);
                    v.DrawLine(new Vector2(0, r * 0.3f), new Vector2(0, -r * 0.6f), new Color(1, 1, 1, 0.95f), r * 0.9f);
                    break;
            }
            v.End();
        }
    }
}
