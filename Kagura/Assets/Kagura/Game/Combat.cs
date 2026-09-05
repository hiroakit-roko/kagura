using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>命中の引数（Godot 版 opts 辞書）。</summary>
    public struct HitOpts
    {
        public string tag, kami;
        public bool crit, quiet;
        public Vector2 dir;
        public float kb, doom, charmChance;
        public static HitOpts Of(string tag, string kami) => new HitOpts { tag = tag, kami = kami, dir = Vector2.down };
    }

    /// <summary>
    /// 命中処理の中枢（Godot 版 combat.gd）。ダメージ倍率、神威（状態異常）、連鎖・宿命・砕け、伝説／双神、神徳の加算。
    /// </summary>
    public static class Combat
    {
        public const float EXPOSED_T = 5f, RUPTURE_T = 3f, JOLT_T = 8f, WEAK_T = 4f;
        public const int CHILL_MAX = 5;

        public static readonly Dictionary<string, Color> StatusColor = new Dictionary<string, Color>
        {
            { "exposed", new Color(1f, 0.84f, 0.42f) }, { "rupture", new Color(0.35f, 0.82f, 0.95f) }, { "jolted", new Color(1f, 0.95f, 0.5f) },
            { "doom", new Color(0.78f, 0.72f, 1f) }, { "weak", new Color(1f, 0.58f, 0.78f) }, { "charm", new Color(1f, 0.45f, 0.7f) },
            { "marked", new Color(1f, 0.62f, 0.3f) }, { "hangover", new Color(0.62f, 1f, 0.55f) }, { "chill", new Color(0.58f, 0.82f, 1f) },
            { "frozen", new Color(0.8f, 0.95f, 1f) }, { "frost", new Color(0.58f, 0.82f, 1f) },
        };

        private static Player P()
        {
            var g = GameManager.I;
            return g != null && g.player != null && g.player.alive ? g.player : null;
        }
        private static bool Has(string id) { var p = P(); return p != null && p.Has(id); }
        private static float Val(string id) { var p = P(); return p != null ? p.Val(id) : 0f; }

        /// <summary>「威力 N%」：基礎攻撃 × 神格倍率 × N/100</summary>
        public static float Scaled(string id, string kami)
        {
            var p = P();
            return p == null ? 0f : p.BaseDamage() * p.KamiPower(kami) * Val(id) * 0.01f;
        }

        // ---------- 命中 ----------

        public static float Hit(Enemy en, float dmg, Vector2 at, HitOpts o)
        {
            if (en == null || !en.Active || en.hp <= 0f) return 0f;
            var p = P();
            string tag = o.tag ?? "attack", kami = o.kami ?? "";
            bool crit = o.crit;
            Vector2 dir = o.dir == Vector2.zero ? Vector2.down : o.dir;   // 既定は画面の上向き（Godot の UP）
            var st = en.st;

            float mult = 1f;
            if (st.exposed > 0f) mult *= 1.20f + Val("ama_u4") * 0.01f;
            if (st.weak > 0f && Has("uzume_u3")) mult *= 1f + Val("uzume_u3") * 0.01f;
            if (st.chillStacks > 0 && Has("iza_u5")) mult *= 1f + Val("iza_u5") * 0.01f;
            if (st.frozen > 0f) mult *= 1.5f;
            if (tag == "lightning" && st.exposed > 0f && Has("duo_ama_take")) mult *= 1f + Val("duo_ama_take") * 0.01f;
            if (tag == "wave" && st.chillStacks > 0 && Has("duo_susa_iza")) mult *= 1f + Val("duo_susa_iza") * 0.01f;
            if (tag == "foxfire" && st.exposed > 0f && Has("duo_ama_inari")) mult *= 1f + Val("duo_ama_inari") * 0.01f;
            if (tag == "lightning" && st.frozen > 0f && Has("duo_take_iza")) mult *= 1f + Val("duo_take_iza") * 0.01f;
            if (tag == "lightning" && en.isBoss && Has("take_u6")) mult *= 1f + Val("take_u6") * 0.01f;
            if (st.hangoverStacks > 0 && Has("suku_u8")) mult *= 1f + Val("suku_u8") * 0.01f;

            if (st.marked && tag != "doom") { crit = true; st.marked = false; }
            if (crit && p != null) mult *= p.CritMult();

            float final = dmg * mult;
            en.lastTag = tag;
            en.TakeDamage(final, crit, at, o.quiet);
            if (p != null)
            {
                p.AddCallGauge(final * 0.00012f);
                if (tag == "lightning" && Has("take_u8")) p.AddCallGauge(Val("take_u8") * 0.01f);
                if (kami != "") p.AddKamiXp(kami, final);
                if (!o.quiet) HitFx(en, at, dir, kami, crit, tag);
                else if (crit) Fx.Sparks(at, -dir, Gd.C_CRIT, 4, 300f);
            }
            if (!en.Active || en.hp <= 0f) return final;
            if (kami != "") ApplyStatus(en, kami, tag, at, dir, o);
            if (crit && p != null && Has("inari_leg") && tag != "foxfire")
            {
                var other = NearestEnemy(en.pos, 260f, en);
                if (other != null) p.SpawnFoxfire(en.pos, other, Scaled("inari_leg", "inari"), "foxfire");
            }
            if (o.kb > 0f) Knockback(en, dir * o.kb, at);
            return final;
        }

        private static void HitFx(Enemy en, Vector2 at, Vector2 dir, string kami, bool crit, string tag)
        {
            Color col = kami != "" ? Data.KamiColor(kami) : Color.white;
            Fx.Sparks(at, -dir, col, crit ? 8 : 4, 380f);
            switch (kami)
            {
                case "ama": Sfx.Play("hit_light", -14f, Gd.Rand(0.95f, 1.1f), 0.04f); break;
                case "susa": Sfx.Play("hit_storm", -16f, Gd.Rand(0.9f, 1.1f), 0.05f); break;
                case "iza": Sfx.Play("hit_ice", -14f, Gd.Rand(0.95f, 1.1f), 0.05f); break;
                case "take": break;
                default: Sfx.Play("hit", -12f, Gd.Rand(0.9f, 1.15f), 0.03f); break;
            }
            if (crit)
            {
                Sfx.Play("hit_heavy", -10f, Gd.Rand(1f, 1.2f), 0.05f);
                GameManager.I.Hitstop(en.isBoss ? 0.06f : 0.04f, 0.05f);
            }
            else if (en.isBoss && (tag == "cast" || tag == "wave" || tag == "call")) GameManager.I.Hitstop(0.05f, 0.1f);
        }

        private static void ApplyStatus(Enemy en, string kami, string tag, Vector2 at, Vector2 dir, HitOpts o)
        {
            var p = P();
            if (p == null) return;
            Color kc = Data.KamiColor(kami);
            switch (kami)
            {
                case "ama":
                    if (en.st.exposed <= 0f) Fx.Rays(en.pos, kc, 6, en.radius * 0.6f, 26f, 0.25f);
                    en.AddExposed(EXPOSED_T + (Has("ama_u6") ? Val("ama_u6") : 0f));
                    break;
                case "susa":
                    if (tag == "wave" || tag == "cast" || tag == "call")
                    {
                        if (Has("susa_u4")) { en.AddRupture(RUPTURE_T); Fx.SlashFx(en.pos, Random.value * Gd.TAU, en.radius * 1.3f, kc, 2f, 0.18f, 6f); }
                        if (Has("duo_susa_iza")) en.AddChill(2);
                        if (Has("duo_susa_inari") && Random.value < Val("duo_susa_inari") * 0.01f)
                        {
                            var other = NearestEnemy(en.pos, 300f);
                            p.SpawnFoxfire(en.pos, other ?? en, p.BaseDamage() * 0.7f, "foxfire");
                        }
                    }
                    break;
                case "tsuki":
                    if (o.doom > 0f) { en.AddDoom(o.doom); Fx.RingFx(en.pos, kc, en.radius, en.radius * 2f, 0.25f, 2f); }
                    break;
                case "uzume":
                    if (tag == "fan" || tag == "cast" || tag == "call")
                    {
                        if (en.st.weak <= 0f) Fx.Petals(en.pos, kc, 5, 90f);
                        ApplyWeak(en);
                        if (o.charmChance > 0f && Random.value < o.charmChance) { en.AddCharm(tag == "cast" ? 5f : 3f); Sfx.Play("charm", -10f); }
                        if (tag == "fan" && Has("duo_take_uzume") && Random.value < Val("duo_take_uzume") * 0.01f)
                            Lightning(en, p.BaseDamage() * 2f * p.KamiPower("take"), at + new Vector2(0, -80), 0);
                    }
                    break;
                case "inari":
                    if (tag == "cast" || (tag == "foxfire" && o.crit))
                    {
                        if (!en.st.marked) Fx.RingFx(en.pos, kc, en.radius * 0.5f, en.radius * 2.2f, 0.3f, 2.5f);
                        en.Mark();
                    }
                    break;
                case "iza":
                    if (tag == "shard" || tag == "cast")
                    {
                        Fx.Sparks(at, Vector2.up, new Color(0.85f, 0.95f, 1f), 3, 220f);
                        en.AddChill(1 + (Has("iza_u7") ? Mathf.RoundToInt(Val("iza_u7")) : 0));
                    }
                    break;
                case "saru":
                    if (tag == "wind" && Has("duo_inari_saru") && Random.value < Val("duo_inari_saru") * 0.01f)
                    {
                        var other = NearestEnemy(en.pos, 300f);
                        if (other != null) p.SpawnFoxfire(en.pos, other, p.BaseDamage() * 0.6f, "foxfire");
                    }
                    break;
            }
        }

        // ---------- 状態異常のヘルパ ----------

        public static float WeakAmount()
        {
            float w = 0.30f;
            if (Has("duo_uzume_suku")) w += Val("duo_uzume_suku") * 0.01f;
            if (Has("duo_ama_uzume")) w += Val("duo_ama_uzume") * 0.01f;
            return Mathf.Min(w, 0.8f);
        }
        public static int HangoverMax() => 5 + (Has("suku_u4") ? Mathf.RoundToInt(Val("suku_u4")) : 0);
        public static float HangoverSlow() => 0.20f;
        public static float HangoverDps()
        {
            var p = P();
            float b = 3f;
            if (p != null && p.gods.Contains("suku")) b = p.BaseDamage() * 0.5f * p.KamiPower("suku");
            return b * (1f + Val("suku_u3") * 0.01f);
        }
        public static float RuptureDmg()
        {
            var p = P();
            float b = Has("susa_u4") ? Val("susa_u4") : 3f;
            if (p != null && p.gods.Contains("susa")) b *= p.KamiPower("susa");
            return b;
        }
        public static void ApplyWeak(Enemy en) { en.AddWeak(WEAK_T); if (Has("duo_ama_uzume")) en.AddExposed(EXPOSED_T); }
        public static void ApplyHangover(Enemy en, int stacks, float dps) { en.AddHangover(stacks, dps); if (Has("duo_uzume_suku")) en.AddWeak(WEAK_T); }

        /// <summary>持続ダメージ（裂傷・酩酊・凍土）。</summary>
        public static void StatusDamage(Enemy en, float dmg, string tag)
        {
            if (en == null || !en.Active || en.hp <= 0f) return;
            Color col = StatusColor.TryGetValue(tag, out var c) ? c : new Color(1, 1, 1, 0.8f);
            string kami = tag == "rupture" ? "susa" : tag == "hangover" ? "suku" : tag == "frost" ? "iza" : "";
            en.hp -= dmg;
            en.flash = Mathf.Max(en.flash, 0.3f);
            Fx.Number(en.pos + new Vector2(Gd.Rand(-6, 6), -en.radius), Mathf.RoundToInt(dmg).ToString(), col, 11f);
            var p = P();
            if (p != null) { p.AddCallGauge(dmg * 0.0001f); if (kami != "") p.AddKamiXp(kami, dmg); }
            if (en.hp <= 0f) en.Die();
        }

        // ---------- 雷 ----------

        public static void Lightning(Enemy en, float dmg, Vector2 from, int chains, HashSet<Enemy> used = null)
        {
            if (en == null || !en.Active || en.hp <= 0f) return;
            used ??= new HashSet<Enemy>();
            used.Add(en);
            var lc = new Color(1f, 0.97f, 0.7f);
            Fx.BoltFx(from, en.pos, lc);
            Fx.Puff(en.pos, 6f, en.radius * 2.6f, new Color(1f, 0.97f, 0.7f, 0.9f), 0.22f);
            Fx.Sparks(en.pos, Vector2.up, lc, 5, 300f);
            Fx.RingFx(en.pos, lc, 4f, en.radius * 2f, 0.2f, 3f);
            Sfx.Play("hit_thunder", -12f, Gd.Rand(0.9f, 1.2f), 0.04f);
            float bonus = Has("duo_take_suku") ? Scaled("duo_take_suku", "take") * en.st.hangoverStacks : 0f;
            var p = P();
            bool crit = p != null && Random.value < p.CritChance();
            Hit(en, dmg + bonus, en.pos, new HitOpts { tag = "lightning", kami = "take", crit = crit, dir = Vector2.down });
            // 倒れても連鎖・余波は続く（Godot 版は queue_free が遅延するので続いていた）
            if (Has("take_u4")) en.AddJolt(JOLT_T);
            if (Has("duo_take_iza")) en.AddChill(2);
            if (Has("take_u5"))
            {
                float r = Val("take_u5");
                foreach (var o in GameManager.I.EnemyList().ToArray())
                    if (o != en && o.Active && !used.Contains(o) && Vector2.Distance(o.pos, en.pos) <= r)
                        Hit(o, dmg * 0.5f, o.pos, new HitOpts { tag = "lightning", kami = "take", quiet = true, dir = Vector2.down });
            }
            if (Has("take_leg") && Random.value < Val("take_leg") * 0.01f)
            {
                var extra = NearestEnemy(en.pos, 240f, en, used);
                if (extra != null) Lightning(extra, dmg, en.pos, 0, used);
            }
            if (chains > 0)
            {
                var nxt = NearestEnemy(en.pos, 220f, en, used);
                if (nxt != null) Lightning(nxt, dmg * 0.75f, en.pos, chains - 1, used);
            }
        }

        public static void JoltTrigger(Enemy en)
        {
            float d = Scaled("take_u4", "take");
            if (d <= 0f) d = 15f;
            Fx.BoltFx(en.pos + new Vector2(Gd.Rand(-40, 40), -70), en.pos, new Color(1f, 0.97f, 0.7f), 0.14f);
            Sfx.Play("hit_thunder", -16f, 1.3f, 0.05f);
            Hit(en, d, en.pos, new HitOpts { tag = "lightning", kami = "take", dir = Vector2.down });
        }

        // ---------- 宿命 ----------

        public static void DoomTrigger(Enemy en, float dmg)
        {
            if (en == null || !en.Active || en.hp <= 0f) return;
            var col = new Color(0.78f, 0.72f, 1f);
            Vector2 pos = en.pos;
            float r = 72f * (1f + Val("tsuki_u3") * 0.01f);
            Fx.RingFx(pos, col, 6f, r, 0.35f, 6f);
            Fx.RingFx(pos, Color.white, 4f, r * 0.6f, 0.25f, 3f);
            Fx.ZoneFx(pos, r, col, 0.35f);
            Fx.Puff(pos, r * 0.3f, r * 1.1f, Gd.WithA(col, 0.9f), 0.4f);
            Fx.Burst(pos, col, 14, 260f, 3.5f, 0.45f, true);
            Fx.SlashFx(pos, Random.value * Gd.TAU, en.radius * 1.6f, Color.white, 2.6f, 0.2f, 7f);
            Sfx.Play("doom", -8f, Gd.Rand(0.9f, 1.1f), 0.05f);
            GameManager.I.Hitstop(0.05f, 0.05f);
            bool crit = Has("duo_tsuki_inari") || (Has("tsuki_u9") && Random.value < Val("tsuki_u9") * 0.01f);
            if (Has("tsuki_leg") && !en.isBoss && en.hp / en.maxHp <= Val("tsuki_leg") * 0.01f)
            {
                Fx.Number(pos + new Vector2(0, -en.radius - 10), "裁定", new Color(1, 0.9f, 1), 18f, true);
                en.TakeDamage(en.hp + 1f, true, pos);
            }
            else Hit(en, dmg, pos, new HitOpts { tag = "doom", kami = "tsuki", crit = crit, dir = Vector2.down });
            if ((!en.Active || en.hp <= 0f) && Has("tsuki_u7") && Random.value < Val("tsuki_u7") * 0.01f)
            {
                var nxt = NearestEnemy(pos, 170f, en);
                if (nxt != null) { nxt.AddDoom(dmg * 0.7f, 1.1f); Fx.BoltFx(pos, nxt.pos, col, 0.12f); Fx.RingFx(nxt.pos, col, nxt.radius, nxt.radius * 2f, 0.25f, 2f); }
            }
            if (en.Active && en.hp > 0f && Has("duo_iza_tsuki")) en.Freeze(Val("duo_iza_tsuki"));
            if (Has("duo_tsuki_suku")) GameManager.I.SpawnZone(pos, "fog", r * 0.9f, Val("duo_tsuki_suku"), 0f, new Color(0.62f, 1f, 0.55f));
            foreach (var o in GameManager.I.EnemyList().ToArray())
                if (o != en && o.Active && Vector2.Distance(o.pos, pos) <= r)
                    Hit(o, dmg * 0.5f, o.pos, new HitOpts { tag = "doom", kami = "tsuki", crit = crit, dir = Vector2.down });
        }

        // ---------- 押し戻し ----------

        public static void Knockback(Enemy en, Vector2 v, Vector2 at)
        {
            en.Knockback(v);
            Fx.Cone(at, v.normalized, new Color(0.35f, 0.82f, 0.95f), 4, 260f, 0.5f, 3f, 0.25f);
            if (Has("duo_susa_take")) Lightning(en, Scaled("duo_susa_take", "take"), at + new Vector2(0, -70), 0);
            if (Has("susa_u8")) Hit(en, Scaled("susa_u8", "susa"), en.pos, new HitOpts { tag = "wave", kami = "susa", quiet = true, dir = Vector2.down });
            if (Has("susa_u5")) en.Stagger(Val("susa_u5"));
            if (Has("susa_leg")) Hit(en, Scaled("susa_leg", "susa"), en.pos, new HitOpts { tag = "wave", kami = "susa", quiet = true, dir = Vector2.down });
        }

        /// <summary>壁・仲間への衝突（ダメージは廃止、Godot 版と同じ no-op）。</summary>
        public static void Collide(Enemy a, Enemy b) { }

        // ---------- 冷気の砕け ----------

        public static void Shatter(Enemy en)
        {
            var col = new Color(0.8f, 0.95f, 1f);
            Fx.Burst(en.pos, col, 16, 260f, 4f, 0.5f);
            Fx.Puff(en.pos, en.radius, en.radius * 3.5f, Gd.WithA(col, 0.9f), 0.35f);
            Fx.RingFx(en.pos, col, 8f, en.radius * 3f, 0.3f, 4f);
            Fx.Rays(en.pos, col, 8, 4f, 40f, 0.25f);
            Sfx.Play("hit_ice", -6f, 0.7f);
            GameManager.I.Hitstop(0.05f, 0.05f);
            var p = P();
            float d = Has("iza_u3") ? Scaled("iza_u3", "iza") : (p != null ? p.BaseDamage() * 1.5f * p.KamiPower("iza") : 25f);
            en.Freeze(0.8f);
            Hit(en, d, en.pos, new HitOpts { tag = "shatter", kami = "iza", dir = Vector2.down });
            if (Has("iza_u4")) GameManager.I.SpawnZone(en.pos, "frost", 60f, Val("iza_u4"), p != null ? p.BaseDamage() * 0.3f : 3f, new Color(0.58f, 0.82f, 1f));
            if (Has("iza_u9") && p != null)
            {
                int n = Mathf.RoundToInt(Val("iza_u9"));
                float sd = p.BaseDamage() * 0.7f * p.KamiPower("iza");
                for (int i = 0; i < n; i++)
                {
                    float a = Gd.TAU * i / n + Gd.Rand(-0.1f, 0.1f);
                    var b = GameManager.I.SpawnPlayerBullet(en.pos + Gd.Dir(a) * 12f, Gd.Dir(a) * 520f, sd, new Color(0.85f, 0.95f, 1f), 5f, 10);
                    b.kami = "iza"; b.tag = "shard"; b.life = 0.7f; b.critChance = p.CritChance();
                }
            }
            if (Has("iza_leg"))
            {
                float ld = Scaled("iza_leg", "iza");
                foreach (var o in GameManager.I.EnemyList().ToArray())
                    if (o != en && o.Active && Vector2.Distance(o.pos, en.pos) <= 120f) { o.Freeze(1.2f); Hit(o, ld, o.pos, new HitOpts { tag = "shatter", kami = "iza", dir = Vector2.down }); }
            }
        }

        // ---------- 撃破時 ----------

        public static void OnKill(Enemy en)
        {
            var p = P();
            if (p == null) return;
            if (Has("uzume_leg") && en.st.weak > 0f && Random.value < Val("uzume_leg") * 0.01f) p.Heal(6f, true);
            if (Has("ama_u8") && en.st.exposed > 0f && Random.value < Val("ama_u8") * 0.01f) { p.Heal(1f, false); Fx.Sparks(en.pos, Vector2.up, new Color(1f, 0.84f, 0.42f), 3, 160f); }
            if (Has("inari_u7") && en.lastTag == "foxfire" && Random.value < Val("inari_u7") * 0.01f)
            {
                var other = NearestEnemy(en.pos, 320f, en);
                if (other != null) p.SpawnFoxfire(en.pos, other, p.BaseDamage() * 0.75f * p.KamiPower("inari"), "foxfire");
            }
            if (Has("suku_u9") && en.st.hangoverStacks > 0 && Random.value < Val("suku_u9") * 0.01f)
                GameManager.I.SpawnZone(en.pos, "fog", 52f, 2.2f, 0f, new Color(0.62f, 1f, 0.55f));
            if (p.HasRelic("r_s_hidama") && Random.value < 0.15f)
            {   // 火の玉の壺：倒した敵が爆ぜて周りを焼く
                var fc = new Color(1f, 0.55f, 0.25f);
                Fx.Burst(en.pos, fc, 14, 240f, 4f, 0.45f); Fx.RingFx(en.pos, fc, 10f, 90f, 0.3f, 4f); Fx.Puff(en.pos, 10f, 80f, Gd.WithA(fc, 0.8f), 0.3f);
                Sfx.Play("boom", -10f, 1.1f, 0.1f); Fx.ShakeAdd(3f);
                float bd = p.BaseDamage() * 1.5f;
                foreach (var o in GameManager.I.EnemyList().ToArray())
                    if (o != en && o.Active && Vector2.Distance(o.pos, en.pos) <= 90f) Hit(o, bd, o.pos, new HitOpts { tag = "burst", kami = "", dir = Vector2.down });
            }
        }

        public static void OnErase(Bullet b) { if (b.kami == "susa") Fx.Sparks(b.pos, Vector2.up, new Color(0.35f, 0.82f, 0.95f), 2, 160f); }

        public static void OnFanReturn(Bullet b)
        {
            var p = P();
            if (p == null) return;
            if (Has("uzume_u9") && p.hp < p.maxHp && p.fanHealCd <= 0f)
            {
                p.fanHealCd = 3f;
                p.Heal(Val("uzume_u9"), false);
                Fx.Petals(p.pos, new Color(1f, 0.58f, 0.78f), 3, 60f);
            }
        }

        // ---------- 検索 ----------

        public static Enemy NearestEnemy(Vector2 from, float maxD, Enemy exclude = null, HashSet<Enemy> used = null)
        {
            Enemy best = null;
            float bd = maxD * maxD;
            foreach (var e in GameManager.I.EnemyList())
            {
                if (e == exclude || !e.Active || (used != null && used.Contains(e))) continue;
                float d = (from - e.pos).sqrMagnitude;
                if (d < bd) { bd = d; best = e; }
            }
            return best;
        }
    }
}
