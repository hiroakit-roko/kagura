using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>使い魔（Godot 版 familiar.gd）：烏・猫又・式神。自機の後ろを付いて回り、自動で撃つ。</summary>
    public class Familiar : MonoBehaviour
    {
        public class Info { public string id, name, kana, role, desc, passive; public Color color; }
        public static readonly List<Info> LIST = new List<Info>
        {
            new Info { id = "karasu", name = "烏", kana = "からす", role = "直進・連射", desc = "正面へ速い弾を絶え間なく放つ。足の速い相棒で、移動速度も少し上がる", passive = "移動速度 +6%", color = new Color(0.55f, 0.55f, 0.75f) },
            new Info { id = "neko", name = "猫又", kana = "ねこまた", role = "3 方向・広範囲", desc = "尾を振って 3 方向に弾を撒く。ひと弾は弱いが取りこぼしが少なく、勾玉を引き寄せる範囲も広がる", passive = "勾玉の吸引範囲 +35%", color = new Color(0.95f, 0.75f, 0.45f) },
            new Info { id = "shiki", name = "式神", kana = "しきがみ", role = "誘導・命中保証", desc = "紙の鳥を折って放つ。ゆっくりだが敵を追って必ず届く。護符の力で被弾後の無敵が少し長い", passive = "被弾後の無敵時間 +25%", color = new Color(0.95f, 0.95f, 1f) },
        };
        public static Info InfoOf(string id) { foreach (var f in LIST) if (f.id == id) return f; return null; }

        public string kind = "karasu";
        public Player p;
        public Color col = Color.white;
        public bool mirror;
        public Vector2 pos;
        private float _cd, _t, _side = -1f;
        private Vec _vec;

        public static Familiar Create(Transform parent, string id, Player player, bool mirror)
        {
            var go = new GameObject("familiar_" + id);
            go.transform.SetParent(parent, false);
            var f = go.AddComponent<Familiar>();
            f.kind = id; f.p = player; f.mirror = mirror;
            f.col = InfoOf(id)?.color ?? Color.white;
            f.pos = player.pos + new Vector2(-36, 40);
            f._vec = Vec.Create(go.transform, "vec", Gd.ZPlayer - 1);
            return f;
        }

        private float Dmg() => p.BaseDamage() * 0.55f * (p.HasRelic("r_fam_dmg") ? 1.6f : 1f);
        private float Rate(float sec) => sec / (p.HasRelic("r_fam_rate") ? 1.4f : 1f);

        public void Tick(float delta)
        {
            if (p == null || !p.alive) { _vec.Begin(); _vec.End(); return; }
            _t += delta;
            if (Mathf.Abs(p.moveDir.x) > 0.3f) _side = -Mathf.Sign(p.moveDir.x);
            float side = mirror ? -_side : _side;
            Vector2 want = p.pos + new Vector2(side * 34f, 44f + Mathf.Sin(_t * 3f) * 3f);
            pos = Vector2.Lerp(pos, want, Mathf.Clamp01(7f * delta));
            transform.position = Gd.ToWorld(pos);
            _cd -= delta;
            if (_cd <= 0f) Fire();
            Draw();
        }

        private void Fire()
        {
            var g = GameManager.I;
            Vector2 from = pos + new Vector2(0, -12);
            switch (kind)
            {
                case "karasu":
                    {
                        _cd = Rate(0.22f);
                        var b = g.SpawnPlayerBullet(from, new Vector2(Gd.Rand(-20, 20), -1000f), Dmg(), col, 3.5f, 0);
                        b.tag = "familiar"; if (p.HasRelic("r_s_fam_kiba")) b.pierce = Mathf.Max(b.pierce, 1); b.trailLen = 18f; b.critChance = p.CritChance();
                        break;
                    }
                case "neko":
                    _cd = Rate(0.55f);
                    for (int i = 0; i < 3; i++)
                    {
                        float a = -Mathf.PI * 0.5f + (i - 1) * 16f * Mathf.Deg2Rad;
                        var b = g.SpawnPlayerBullet(from, Gd.Dir(a) * 720f, Dmg() * 0.7f, col, 3.5f, 0);
                        b.tag = "familiar"; if (p.HasRelic("r_s_fam_kiba")) b.pierce = Mathf.Max(b.pierce, 1); b.critChance = p.CritChance();
                    }
                    break;
                case "shiki":
                    {
                        _cd = Rate(0.7f);
                        var target = Combat.NearestEnemy(pos, 900f);
                        Vector2 dir = target != null ? (target.pos - from).normalized : Vector2.down;
                        var b = g.SpawnPlayerBullet(from, dir * 420f, Dmg() * 1.3f, col, 5f, 12);
                        b.tag = "familiar"; if (p.HasRelic("r_s_fam_kiba")) b.pierce = Mathf.Max(b.pierce, 1); b.homing = 4.5f; b.critChance = p.CritChance();
                        break;
                    }
            }
            Sfx.Play("shoot", -26f, 1.3f, 0.05f);
        }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            float bob = Mathf.Sin(_t * 6f) * 1.5f;
            switch (kind)
            {
                case "karasu":
                    {
                        float flap = Mathf.Sin(_t * 14f) * 4f;
                        var dark = new Color(0.12f, 0.10f, 0.18f);
                        v.DrawColoredPolygon(new[] { new Vector2(-2, bob), new Vector2(-16, bob - 6 + flap), new Vector2(-14, bob + 2) }, dark);
                        v.DrawColoredPolygon(new[] { new Vector2(2, bob), new Vector2(16, bob - 6 + flap), new Vector2(14, bob + 2) }, dark);
                        v.DrawCircle(new Vector2(0, bob), 6f, new Color(0.14f, 0.12f, 0.2f));
                        v.DrawCircle(new Vector2(0, bob - 6), 4f, new Color(0.16f, 0.14f, 0.22f));
                        v.DrawCircle(new Vector2(-1.5f, bob - 7), 1.2f, new Color(1, 0.85f, 0.2f));
                        v.DrawCircle(new Vector2(1.5f, bob - 7), 1.2f, new Color(1, 0.85f, 0.2f));
                        v.DrawColoredPolygon(new[] { new Vector2(-1.5f, bob - 5), new Vector2(1.5f, bob - 5), new Vector2(0, bob - 1) }, new Color(0.6f, 0.5f, 0.3f));
                        break;
                    }
                case "neko":
                    v.DrawCircle(new Vector2(0, bob), 7.5f, col);
                    v.DrawCircle(new Vector2(0, bob - 8), 5.5f, col);
                    v.DrawColoredPolygon(new[] { new Vector2(-5, bob - 10), new Vector2(-3, bob - 16), new Vector2(-1, bob - 11) }, col);
                    v.DrawColoredPolygon(new[] { new Vector2(5, bob - 10), new Vector2(3, bob - 16), new Vector2(1, bob - 11) }, col);
                    foreach (float sgn in new[] { -1f, 1f })
                    {
                        var pts = new Vector2[6];
                        for (int i = 0; i < 6; i++) { float k = i / 5f; pts[i] = new Vector2(sgn * (4f + k * 10f) + Mathf.Sin(_t * 5f + k * 3f + sgn) * 2f, bob + 4f + k * 8f); }
                        v.DrawPolyline(pts, Gd.Darkened(col, 0.15f), 2.5f);
                    }
                    v.DrawCircle(new Vector2(-2, bob - 8), 1.2f, Gd.C_INK);
                    v.DrawCircle(new Vector2(2, bob - 8), 1.2f, Gd.C_INK);
                    v.DrawLine(new Vector2(-2, bob - 5), new Vector2(2, bob - 5), Gd.C_INK, 1f);
                    break;
                case "shiki":
                    v.DrawCircle(new Vector2(0, bob), 11f, Gd.WithA(new Color(0.85f, 0.75f, 1f), 0.15f));
                    v.DrawColoredPolygon(new[] { new Vector2(0, bob - 12), new Vector2(5, bob - 4), new Vector2(3, bob - 4), new Vector2(6, bob + 8), new Vector2(-6, bob + 8), new Vector2(-3, bob - 4), new Vector2(-5, bob - 4) }, Gd.C_PAPER);
                    v.DrawLine(new Vector2(-9, bob - 2), new Vector2(-3, bob - 3), Gd.C_PAPER, 2f);
                    v.DrawLine(new Vector2(9, bob - 2), new Vector2(3, bob - 3), Gd.C_PAPER, 2f);
                    v.DrawRect(new Rect(-2, bob - 1, 4, 5), new Color(0.85f, 0.2f, 0.25f, 0.9f));
                    v.DrawLine(new Vector2(0, bob - 12), new Vector2(0, bob - 8), Gd.C_INK, 1f);
                    break;
            }
            v.End();
        }

        /// <summary>使い魔の姿（選択カード用、Godot 版 Emblem.familiar_preview）。</summary>
        public static void Preview(Vec ci, string id, Vector2 c, float t, Color col, float alpha = 1f)
        {
            float bob = Mathf.Sin(t * 4f) * 3f;
            float a = alpha;
            switch (id)
            {
                case "karasu":
                    {
                        float flap = Mathf.Sin(t * 10f) * 8f;
                        var dark = Gd.WithA(new Color(0.12f, 0.10f, 0.18f), a);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(-4, bob), c + new Vector2(-34, bob - 12 + flap), c + new Vector2(-28, bob + 4) }, dark);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(4, bob), c + new Vector2(34, bob - 12 + flap), c + new Vector2(28, bob + 4) }, dark);
                        ci.DrawCircle(c + new Vector2(0, bob), 13f, dark);
                        ci.DrawCircle(c + new Vector2(0, bob - 13), 9f, Gd.WithA(new Color(0.16f, 0.14f, 0.22f), a));
                        ci.DrawCircle(c + new Vector2(-3.5f, bob - 15), 2.5f, Gd.WithA(new Color(1, 0.85f, 0.2f), a));
                        ci.DrawCircle(c + new Vector2(3.5f, bob - 15), 2.5f, Gd.WithA(new Color(1, 0.85f, 0.2f), a));
                        ci.DrawColoredPolygon(new[] { c + new Vector2(-3, bob - 10), c + new Vector2(3, bob - 10), c + new Vector2(0, bob - 3) }, Gd.WithA(new Color(0.6f, 0.5f, 0.3f), a));
                        break;
                    }
                case "neko":
                    {
                        var cc = Gd.WithA(col, a);
                        ci.DrawCircle(c + new Vector2(0, bob + 4), 16f, cc);
                        ci.DrawCircle(c + new Vector2(0, bob - 14), 12f, cc);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(-11, bob - 18), c + new Vector2(-7, bob - 32), c + new Vector2(-2, bob - 21) }, cc);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(11, bob - 18), c + new Vector2(7, bob - 32), c + new Vector2(2, bob - 21) }, cc);
                        foreach (float sgn in new[] { -1f, 1f })
                        {
                            var pts = new Vector2[7];
                            for (int i = 0; i < 7; i++) { float kk = i / 6f; pts[i] = c + new Vector2(sgn * (8f + kk * 22f) + Mathf.Sin(t * 4f + kk * 3f + sgn) * 4f, bob + 8f + kk * 14f); }
                            ci.DrawPolyline(pts, Gd.WithA(Gd.Darkened(col, 0.15f), a), 4f);
                        }
                        ci.DrawCircle(c + new Vector2(-4.5f, bob - 15), 2.2f, Gd.WithA(Gd.C_INK, a));
                        ci.DrawCircle(c + new Vector2(4.5f, bob - 15), 2.2f, Gd.WithA(Gd.C_INK, a));
                        ci.DrawLine(c + new Vector2(-4, bob - 9), c + new Vector2(4, bob - 9), Gd.WithA(Gd.C_INK, a), 1.5f);
                        break;
                    }
                case "shiki":
                    {
                        ci.DrawCircle(c + new Vector2(0, bob), 26f, Gd.WithA(new Color(0.85f, 0.75f, 1f), 0.15f * a));
                        var paper = Gd.WithA(Gd.C_PAPER, a);
                        ci.DrawColoredPolygon(new[] { c + new Vector2(0, bob - 26), c + new Vector2(10, bob - 8), c + new Vector2(6, bob - 8), c + new Vector2(13, bob + 18), c + new Vector2(-13, bob + 18), c + new Vector2(-6, bob - 8), c + new Vector2(-10, bob - 8) }, paper);
                        ci.DrawLine(c + new Vector2(-20, bob - 4), c + new Vector2(-6, bob - 6), paper, 4f);
                        ci.DrawLine(c + new Vector2(20, bob - 4), c + new Vector2(6, bob - 6), paper, 4f);
                        ci.DrawRect(new Rect(c.x - 4, c.y + bob - 2, 8, 10), Gd.WithA(new Color(0.85f, 0.2f, 0.25f), a));
                        ci.DrawLine(c + new Vector2(0, bob - 26), c + new Vector2(0, bob - 18), Gd.WithA(Gd.C_INK, a), 1.5f);
                        break;
                    }
            }
        }
    }

    /// <summary>眷属の狐（稲荷の加護）。自機の周りを回り、近い敵へ狐火を放つ（Godot 版 drone.gd）。</summary>
    public class Drone : MonoBehaviour
    {
        public int index, total = 1;
        public float orbitR = 54f;
        public Player owner;
        private float _cd, _t;
        private Vec _vec;
        public Vector2 pos;

        public static Drone Create(Transform parent, Player owner, int index, int total)
        {
            var go = new GameObject("drone");
            go.transform.SetParent(parent, false);
            var d = go.AddComponent<Drone>();
            d.owner = owner; d.index = index; d.total = total;
            d._vec = Vec.Create(go.transform, "vec", Gd.ZPlayer);
            return d;
        }

        public void Tick(float delta)
        {
            _t += delta;
            float a = _t * 1.6f + Gd.TAU * index / Mathf.Max(total, 1);
            pos = owner.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a) * 0.7f) * orbitR;
            transform.position = Gd.ToWorld(pos);
            Draw();
            if (owner == null || !owner.alive) return;
            _cd -= delta;
            if (_cd > 0f) return;
            var target = Combat.NearestEnemy(pos, 480f);
            if (target == null) return;
            _cd = 0.55f / owner.FireRateMult();
            owner.SpawnFoxfire(pos, target, owner.BaseDamage() * 0.6f * owner.KamiPower("inari"), "foxfire");
        }

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            var c = new Color(1f, 0.62f, 0.30f);
            float fl = 1f + 0.15f * Mathf.Sin(_t * 14f + index);
            v.DrawCircle(Vector2.zero, 11f, Gd.WithA(c, 0.2f));
            v.DrawColoredPolygon(new[] { new Vector2(0, -12 * fl), new Vector2(6, -2), new Vector2(4, 6), new Vector2(-4, 6), new Vector2(-6, -2) }, c);
            v.DrawColoredPolygon(new[] { new Vector2(0, -6 * fl), new Vector2(3, 0), new Vector2(0, 4), new Vector2(-3, 0) }, new Color(1, 1, 0.85f, 0.95f));
            v.DrawColoredPolygon(new[] { new Vector2(-6, -2), new Vector2(-9, -10), new Vector2(-2, -5) }, c);
            v.DrawColoredPolygon(new[] { new Vector2(6, -2), new Vector2(9, -10), new Vector2(2, -5) }, c);
            v.DrawCircle(new Vector2(-2.5f, 1), 1.2f, Gd.C_INK);
            v.DrawCircle(new Vector2(2.5f, 1), 1.2f, Gd.C_INK);
            v.End();
        }
    }
}
