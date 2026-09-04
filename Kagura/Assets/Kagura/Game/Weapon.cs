using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 神器：神を迎えると付く自動発射の武器（Godot 版 weapon.gd）。神ごとに挙動が違う。
    ///   ama 日輪光線 / susa 荒波 / take 神鳴り / tsuki 月輪 / uzume 舞扇 / inari 狐火 / suku 酒霧の瓢 / iza 氷柱 / saru 神風の刃
    /// </summary>
    public class Weapon
    {
        public string kami;
        public Player p;
        public Color col, col2;
        public float cd, t;
        private readonly Dictionary<Enemy, float> _bladeHit = new Dictionary<Enemy, float>();
        private float _beamTick, _eclipseT, _flareT, _spin;
        public float flareFx;
        private int _alt;
        private readonly Dictionary<Enemy, float> _focus = new Dictionary<Enemy, float>();
        private Vec _vec;

        public Weapon(string kamiId, Player player, Transform parent)
        {
            kami = kamiId; p = player;
            col = Data.KamiColor(kamiId); col2 = Data.KamiColor2(kamiId);
            _vec = Vec.Create(parent, "weapon_" + kamiId, Gd.ZPBullet, false, true);
        }

        public void Destroy() { if (_vec != null) Object.Destroy(_vec.gameObject); }

        private float Power() => p.KamiPower(kami);
        private float BaseDmg() => p.BaseDamage();
        private float Rate(float mult) => mult / p.FireRateMult();
        private GameManager G => GameManager.I;
        private int Lv => p.KamiLv(kami);

        public void Tick(float delta)
        {
            if (p == null || !p.alive) { _vec.Begin(); _vec.End(); return; }
            t += delta;
            cd -= delta;
            switch (kami)
            {
                case "ama": Beam(delta); break;
                case "susa": WaveAtk(); break;
                case "take": LightningAtk(); break;
                case "tsuki": Blades(delta); break;
                case "uzume": Fan(); break;
                case "inari": Foxfire(); break;
                case "suku": Gourd(); break;
                case "iza": Shards(); break;
                case "saru": Wind(); break;
            }
            Draw();
        }

        // ---------- 天照：日輪光線 ----------

        public float BeamWidth() => (14f + 3f * (Lv / 3)) * (1f + p.Val("ama_u1") * 0.01f);

        public List<Vector2> BeamDirs()
        {
            var dirs = new List<Vector2> { Vector2.down };   // Godot の UP は (0,-1)：画面上へ。px 座標では y が減る方向
            int extra = p.Has("ama_u3") ? Mathf.RoundToInt(p.Val("ama_u3")) : 0;
            for (int i = 0; i < extra; i++)
            {
                float a = (14f + 10f * i) * Mathf.Deg2Rad;
                dirs.Add(Rot(Vector2.down, a));
                dirs.Add(Rot(Vector2.down, -a));
            }
            return dirs;
        }

        private static Vector2 Rot(Vector2 v, float a) { float c = Mathf.Cos(a), s = Mathf.Sin(a); return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c); }

        private void Beam(float delta)
        {
            _beamTick -= delta;
            if (_beamTick > 0f) return;
            _beamTick = 0.1f;
            float dmg = BaseDmg() * 0.24f * Power() * (1f + p.Val("ama_u2") * 0.01f);
            float w = BeamWidth();
            Vector2 origin = p.pos + new Vector2(0, -30);
            bool hitAny = false;
            float focusMax = p.Has("ama_u9") ? p.Val("ama_u9") * 0.01f : 0f;
            var hitSet = new HashSet<Enemy>();
            var dirs = BeamDirs();
            foreach (var d in dirs)
            {
                Vector2 n = Gd.Orth(d);
                foreach (var e in G.EnemyList())
                {
                    if (!e.Active) continue;
                    Vector2 rel = e.pos - origin;
                    float along = Vector2.Dot(rel, d);
                    if (along < -10f) continue;
                    float side = Mathf.Abs(Vector2.Dot(rel, n));
                    if (side <= w * 0.5f + e.radius * 0.8f)
                    {
                        hitAny = true;
                        hitSet.Add(e);
                        if (p.Has("ama_u6")) e.st.sunslow = 0.25f;
                        float dmgE = dmg;
                        if (focusMax > 0f)
                        {
                            float f = (_focus.TryGetValue(e, out var fv) ? fv : 0f) + 0.1f;
                            _focus[e] = f;
                            dmgE *= 1f + focusMax * Mathf.Clamp01(f / 2f);
                        }
                        Combat.Hit(e, dmgE, e.pos + new Vector2(Gd.Rand(-6, 6), Gd.Rand(-6, 6)), new HitOpts { tag = "beam", kami = "ama", dir = d, crit = Random.value < p.CritChance(), quiet = true });
                    }
                }
            }
            if (focusMax > 0f)
            {
                var drop = new List<Enemy>();
                foreach (var k in _focus.Keys) if (!hitSet.Contains(k)) drop.Add(k);
                foreach (var k in drop) _focus.Remove(k);
            }
            flareFx = Mathf.Max(0f, flareFx - 0.1f);
            if (p.Has("ama_u7"))
            {
                _flareT += 0.1f;
                if (_flareT >= p.Val("ama_u7"))
                {
                    _flareT = 0f; flareFx = 0.35f;
                    int nErased = 0;
                    foreach (var eb in G.EnemyBullets())
                    {
                        if (!eb.Active) continue;
                        foreach (var d in dirs)
                        {
                            Vector2 rel = eb.pos - origin;
                            if (Vector2.Dot(rel, d) < 0f || Mathf.Abs(Vector2.Dot(rel, Gd.Orth(d))) > w * 0.5f + 6f) continue;
                            Fx.Sparks(eb.pos, Vector2.up, col, 3, 200f);
                            eb.Vanish("ama-kagerou"); nErased++;
                            break;
                        }
                    }
                    Fx.RingFx(origin, col, 8f, 60f, 0.25f, 3f);
                    Sfx.Play("hit_light", -10f, 1.4f, 0.05f);
                    if (nErased > 0) Fx.Number(origin + new Vector2(0, -30), "陽炎", col, 12f);
                }
            }
            if (hitAny && Random.value < 0.5f) Sfx.Play("hit_light", -22f, Gd.Rand(0.9f, 1.1f), 0.08f);
            if (p.Has("ama_leg"))
            {
                _eclipseT += 0.1f;
                if (_eclipseT >= p.Val("ama_leg"))
                {
                    _eclipseT = 0f;
                    Fx.Flash(Gd.WithA(col, 0.6f), 0.4f);
                    Fx.Rays(p.pos, col, 24, 40f, 900f, 0.5f);
                    Sfx.Play("flute", -8f, 1.3f);
                    foreach (var e in G.EnemyList()) if (e.Active) { e.AddExposed(Combat.EXPOSED_T); Combat.Hit(e, dmg * 10f, e.pos, HitOpts.Of("light", "ama")); }
                }
            }
        }

        // ---------- 須佐之男：荒波 ----------

        private void WaveAtk()
        {
            if (cd > 0f) return;
            cd = Rate(0.95f * (1f - p.Val("susa_u6") * 0.01f));
            float size = 70f * (1f + p.Val("susa_u2") * 0.01f) * (1f + 0.05f * (Lv / 3));
            float reach = 260f * (1f + p.Val("susa_u3") * 0.01f);
            float dmg = BaseDmg() * 3.42f * Power() * (1f + p.Val("susa_u1") * 0.01f);
            if (p.Has("susa_u9")) dmg *= 1f + p.Val("susa_u9") * 0.01f * Mathf.Min(G.EnemyCount, 10);
            int count = p.Has("susa_leg") ? 2 : 1;
            for (int i = 0; i < count; i++)
            {
                var b = G.SpawnPlayerBullet(p.pos + new Vector2(0, -30 - i * 60f), new Vector2(0, -420f), dmg, col, size, 4);
                b.pierce = 999; b.kb = 620f; b.kami = "susa"; b.tag = "wave"; b.life = reach / 420f; b.critChance = p.CritChance();
                if (p.Has("susa_leg")) { b.eraser = true; b.eraseChance = 0.6f; }
                else if (p.Has("susa_u7")) { b.eraser = true; b.eraseChance = p.Val("susa_u7") * 0.01f; }
            }
            Fx.RingFx(p.pos + new Vector2(0, -30), col, 10f, size * 0.8f, 0.25f, 4f);
            Sfx.Play("hit_storm", -12f, Gd.Rand(0.7f, 0.85f), 0.2f);
        }

        // ---------- 建御雷：神鳴り ----------

        private void LightningAtk()
        {
            if (cd > 0f) return;
            var es = new List<Enemy>();
            foreach (var e in G.EnemyList()) if (e.Active) es.Add(e);
            if (es.Count == 0) { cd = 0.2f; return; }
            cd = Rate(1.4f * (1f - p.Val("take_u2") * 0.01f) * (1f - 0.04f * (Lv / 3)));
            float dmg = BaseDmg() * 3f * Power() * (1f + p.Val("take_u1") * 0.01f);
            Enemy target = es[Random.Range(0, es.Count)];
            if (Random.value < 0.6f)
            {
                Enemy best = null; float bd = float.MaxValue;
                foreach (var e in es) { float d = (e.pos - p.pos).sqrMagnitude; if (d < bd) { bd = d; best = e; } }
                if (best != null) target = best;
            }
            int chains = 1 + (p.Has("take_u3") ? Mathf.RoundToInt(p.Val("take_u3")) : 0);
            Vector2 tpos = target.pos;
            Combat.Lightning(target, dmg, new Vector2(tpos.x + Gd.Rand(-40, 40), -30f), chains);
            if (p.Has("take_u9") && es.Count > 1 && Random.value < p.Val("take_u9") * 0.01f)
            {
                var other = es[Random.Range(0, es.Count)];
                if (other == target) other = es[(es.IndexOf(other) + 1) % es.Count];
                if (other != target && other.Active) Combat.Lightning(other, dmg * 0.8f, new Vector2(other.pos.x + Gd.Rand(-40, 40), -30f), 0);
            }
            if (p.Has("take_u7")) G.SpawnZone(tpos + new Vector2(0, -40), "cloud", 90f, p.Val("take_u7"), dmg * 0.3f, col);
            Fx.Flash(Gd.WithA(col, 0.08f), 0.08f);
        }

        // ---------- 月読：月輪 ----------

        public int BladeCount() => 2 + (p.Has("tsuki_u1") ? Mathf.RoundToInt(p.Val("tsuki_u1")) : 0) + Lv / 5;
        public float BladeRadius() => 72f * (1f + p.Val("tsuki_u4") * 0.01f);
        public const float BladeSize = 24f;

        private void Blades(float delta)
        {
            int n = BladeCount();
            float r = BladeRadius();
            float dmg = BaseDmg() * 1.1f * Power() * (1f + p.Val("tsuki_u5") * 0.01f);
            float doom = BaseDmg() * 3f * Power() * (1f + p.Val("tsuki_u2") * 0.01f);
            _spin += delta * 2.6f * (1f + p.Val("tsuki_u6") * 0.01f);
            float spin = _spin, br = BladeSize;
            foreach (var eb in G.EnemyBullets())
            {
                if (!eb.Active) continue;
                for (int i = 0; i < n; i++)
                {
                    Vector2 bp = p.pos + Gd.Dir(spin + Gd.TAU * i / n) * r;
                    if (Vector2.Distance(bp, eb.pos) <= br + eb.radius) { Fx.Sparks(eb.pos, Vector2.up, col, 2, 160f); eb.Vanish("tsuki-blade"); break; }
                }
            }
            foreach (var e in G.EnemyList())
            {
                if (!e.Active) continue;
                if (_bladeHit.TryGetValue(e, out var next) && next > t) continue;
                for (int i = 0; i < n; i++)
                {
                    float a = spin + Gd.TAU * i / n;
                    Vector2 bp = p.pos + Gd.Dir(a) * r;
                    if (Vector2.Distance(bp, e.pos) <= br + e.radius)
                    {
                        _bladeHit[e] = t + 0.28f / (1f + p.Val("tsuki_u6") * 0.01f);
                        Combat.Hit(e, dmg, e.pos, new HitOpts { tag = "blade", kami = "tsuki", dir = (e.pos - p.pos).normalized, crit = Random.value < p.CritChance(), doom = doom });
                        Fx.SlashFx(e.pos, a + Mathf.PI * 0.5f, 22f, col, 2f, 0.15f, 5f);
                        break;
                    }
                }
            }
            if (_bladeHit.Count > 200) _bladeHit.Clear();
        }

        // ---------- 天宇受売：舞扇 ----------

        private void Fan()
        {
            if (cd > 0f) return;
            cd = Rate(1.6f * (1f - p.Val("uzume_u7") * 0.01f));
            int n = 1 + (p.Has("uzume_u1") ? Mathf.RoundToInt(p.Val("uzume_u1")) : 0);
            float size = 1f + p.Val("uzume_u2") * 0.01f + 0.06f * (Lv / 3);
            float dmg = BaseDmg() * 1.5f * Power() * size;
            for (int i = 0; i < n; i++)
            {
                float a = -Mathf.PI * 0.5f + (i - (n - 1) * 0.5f) * 22f * Mathf.Deg2Rad;
                var b = G.SpawnPlayerBullet(p.pos + new Vector2(0, -20), Gd.Dir(a) * 520f, dmg, col, 16f * size, 8);
                b.pierce = 999; b.eraser = true; b.kami = "uzume"; b.tag = "fan"; b.mode = "boomerang";
                b.turnDist = 330f * (1f + p.Val("uzume_u6") * 0.01f);
                b.returnMult = 1f + p.Val("uzume_u8") * 0.01f;
                b.life = 3.2f + p.Val("uzume_u6") * 0.01f;
                b.critChance = p.CritChance();
                b.charmChance = p.Has("uzume_u4") ? p.Val("uzume_u4") * 0.01f : 0f;
            }
            Sfx.Play("clap", -12f, 1.3f, 0.1f);
        }

        // ---------- 稲荷：狐火 ----------

        private void Foxfire()
        {
            if (cd > 0f) return;
            cd = Rate(0.42f * (1f - p.Val("inari_u6") * 0.01f));
            int n = 1 + (p.Has("inari_u1") ? Mathf.RoundToInt(p.Val("inari_u1")) : 0) + Lv / 4;
            float dmg = BaseDmg() * 0.75f * Power() * (1f + p.Val("inari_u2") * 0.01f);
            var target = Combat.NearestEnemy(p.pos, 900f);
            for (int i = 0; i < n; i++) p.SpawnFoxfire(p.pos + new Vector2((i - (n - 1) * 0.5f) * 14f, -24f), target, dmg, "foxfire");
        }

        // ---------- 少名毘古那：酒霧の瓢 ----------

        private void Gourd()
        {
            if (cd > 0f) return;
            cd = Rate(2f * (1f - p.Val("suku_u6") * 0.01f));
            var target = Combat.NearestEnemy(p.pos, 900f);
            Vector2 to = target != null ? target.pos : new Vector2(p.pos.x, p.pos.y - 300f);
            Vector2 dir = (to - p.pos).normalized;
            var b = G.SpawnPlayerBullet(p.pos + new Vector2(0, -20), dir * 520f, BaseDmg() * 0.9f * Power(), col, 9f, 9);
            b.kami = "suku"; b.tag = "gourd"; b.zoneKind = "fog";
            b.zoneR = 68f * (1f + p.Val("suku_u1") * 0.01f + p.Val("duo_ama_suku") * 0.01f) * (1f + 0.05f * (Lv / 3));
            b.zoneLife = 3.5f * (1f + p.Val("suku_u2") * 0.01f);
            b.zoneDmg = 0f;
            b.life = Mathf.Clamp(Vector2.Distance(p.pos, to) / 520f, 0.25f, 1.4f);
            Sfx.Play("miki", -20f, 1.6f, 0.2f);
        }

        // ---------- 伊邪那美：氷柱 ----------

        private void Shards()
        {
            if (cd > 0f) return;
            cd = Rate(0.7f * (1f - p.Val("iza_u6") * 0.01f));
            int n = 3 + (p.Has("iza_u1") ? Mathf.RoundToInt(p.Val("iza_u1")) : 0) + 2 * (Lv / 5);
            float dmg = BaseDmg() * 0.9f * Power() * (1f + p.Val("iza_u2") * 0.01f);
            int pierce = p.Has("iza_u8") ? Mathf.RoundToInt(p.Val("iza_u8")) : 0;
            for (int i = 0; i < n; i++)
            {
                float a = -Mathf.PI * 0.5f + (i - (n - 1) * 0.5f) * 11f * Mathf.Deg2Rad;
                var b = G.SpawnPlayerBullet(p.pos + new Vector2(0, -26), Gd.Dir(a) * 640f, dmg, new Color(0.85f, 0.95f, 1f), 5f, 10);
                b.pierce = pierce; b.kami = "iza"; b.tag = "shard"; b.critChance = p.CritChance();
            }
            Sfx.Play("hit_ice", -22f, 1.4f, 0.15f);
        }

        // ---------- 猿田彦：神風の刃 ----------

        private void Wind()
        {
            if (cd > 0f) return;
            float rate = 1f + p.Val("saru_u1") * 0.01f;
            cd = Rate(0.13f / rate);
            float dmg = BaseDmg() * 0.45f * Power() * (1f + p.Val("saru_u2") * 0.01f);
            if (p.Has("saru_u7") && p.dashBuffT > 0f) dmg *= 1f + p.Val("saru_u7") * 0.01f;
            int n = 1 + Lv / 4 + (p.Has("saru_u5") ? Mathf.RoundToInt(p.Val("saru_u5")) : 0);
            int pierce = p.Has("saru_u6") ? Mathf.RoundToInt(p.Val("saru_u6")) : 0;
            _alt = (_alt + 1) % 2;
            for (int i = 0; i < n; i++)
            {
                float x = (_alt - 0.5f) * 16f + (i - (n - 1) * 0.5f) * 22f;
                float a = -Mathf.PI * 0.5f + Gd.Rand(-3f, 3f) * Mathf.Deg2Rad;
                var b = G.SpawnPlayerBullet(p.pos + new Vector2(x, -30), Gd.Dir(a) * 980f, dmg, col, 4f, 11);
                b.pierce = pierce; b.kami = "saru"; b.tag = "wind"; b.critChance = p.CritChance();
            }
        }

        // ---------- 描画（光線と月輪は自分で描く） ----------

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            if (kami == "ama")
            {
                float w = BeamWidth();
                Vector2 origin = p.pos + new Vector2(0, -30);
                float flick = 0.85f + 0.15f * Mathf.Sin(t * 40f);
                var dirs = BeamDirs();
                if (flareFx > 0f) foreach (var d in dirs) v.DrawLine(origin, origin + d * 1400f, new Color(1, 1, 1, flareFx * 1.6f), w * 2.6f * (0.5f + flareFx));
                foreach (var d in dirs)
                {
                    Vector2 far = origin + d * 1400f;
                    v.DrawLine(origin, far, Gd.WithA(col, 0.18f * flick), w * 2.2f);
                    v.DrawLine(origin, far, Gd.WithA(col, 0.55f * flick), w);
                    v.DrawLine(origin, far, new Color(1, 1, 0.95f, 0.9f * flick), w * 0.35f);
                    for (int i = 0; i < 6; i++)
                    {
                        float k = Mathf.Repeat(t * 1.6f + i / 6f, 1f);
                        Vector2 pos = origin + d * (k * 900f);
                        v.DrawCircle(pos + Gd.Orth(d) * Mathf.Sin(t * 9f + i) * w * 0.4f, 2.5f, new Color(1, 1, 1, (1f - k) * 0.8f));
                    }
                }
                v.DrawCircle(origin, w * 0.9f, Gd.WithA(col, 0.5f));
                v.DrawCircle(origin, w * 0.5f, new Color(1, 1, 1, 0.9f));
            }
            else if (kami == "tsuki")
            {
                int n = BladeCount();
                float r = BladeRadius();
                float bs = BladeSize / 22f;
                v.DrawArc(p.pos, r, 0, Gd.TAU, 48, Gd.WithA(col, 0.12f), 1f);
                for (int i = 0; i < n; i++)
                {
                    float a = _spin + Gd.TAU * i / n;
                    Vector2 bp = p.pos + Gd.Dir(a) * r;
                    float ang = a + Mathf.PI * 0.5f;
                    v.DrawCircle(bp, 18f * bs, Gd.WithA(col, 0.14f));
                    v.DrawArc(bp, 15f * bs, ang - 1.6f, ang + 1.6f, 14, Gd.WithA(col, 0.95f), 6f * bs);
                    v.DrawArc(bp, 15f * bs, ang - 1.3f, ang + 1.3f, 12, new Color(1, 1, 1, 0.85f), 2f);
                    for (int j = 0; j < 4; j++) v.DrawCircle(p.pos + Gd.Dir(a - (j + 1) * 0.12f) * r, 6f - j, Gd.WithA(col, 0.25f - 0.05f * j));
                }
            }
            v.End();
        }
    }
}
