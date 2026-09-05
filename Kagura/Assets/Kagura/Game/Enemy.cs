using System.Collections.Generic;
using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>神威（状態異常）。Godot 版 enemy.gd の st 辞書。</summary>
    public class Status
    {
        public float exposed, rupture, jolted, weak, charm, frozen, sunslow, stagger;
        public bool marked;
        public float doomT = -1f, doomDmg;          // doomT < 0 なら宿命なし
        public int hangoverStacks; public float hangoverT, hangoverDps;
        public int chillStacks; public float chillT;
        public void Clear() { exposed = rupture = jolted = weak = charm = frozen = sunslow = stagger = 0f; marked = false; doomT = -1f; doomDmg = 0f; hangoverStacks = 0; hangoverT = 0; hangoverDps = 0; chillStacks = 0; chillT = 0; }
    }

    /// <summary>雑魚敵（穢れ）。Godot 版 enemy.gd の移植。Boss はこれを継承する。</summary>
    public class Enemy : MonoBehaviour
    {
        public static readonly Dictionary<string, string> KindNames = Enemies.Names;

        public string kind = "grunt";
        public int wave;
        public Vector2 pos;
        public float hp, maxHp, radius = 16f, speed = 60f, contactDmg = 12f, score = 10, xp = 6;
        public bool Active, isBoss;
        public Color color;
        public readonly Status st = new Status();
        public float fireT, t, flash;
        public int state;
        public Vector2 kb;
        public string lastTag = "";
        protected float _phase, _dir = 1f, _spawnIn, _stateT, _kbHitCd, _ruptureAcc, _hangT;
        protected Vector2 _chargeDir = Vector2.up, _lastPos;   // 画面の下向き（Godot の DOWN）
        protected Vec _vec;
        // 敵の絵（Resources/Art/enemy/<kind>.png があれば、ベクター描画の代わりに使う。無ければ従来の描画）
        private static readonly Dictionary<string, Sprite> _artCache = new Dictionary<string, Sprite>();
        protected SpriteRenderer _spr;
        private Vec _vecTop;             // 絵の前面：状態異常・発射の予兆・体力（絵は ZEnemy+1 なので、その上に描く）
        protected Sprite _sprite;

        protected virtual void Awake()
        {
            _vec = Vec.Create(transform, "vec", Gd.ZEnemy);
            var sgo = new GameObject("spr");
            sgo.transform.SetParent(transform, false);
            _spr = sgo.AddComponent<SpriteRenderer>();
            _spr.sortingOrder = Gd.ZEnemy + 1;
            _spr.enabled = false;
            _vecTop = Vec.Create(transform, "vec_top", Gd.ZEnemy + 2);
        }

        private static Sprite EnemyArt(string kind)
        {
            if (_artCache.TryGetValue(kind, out var sp)) return sp;
            var tex = Resources.Load<Texture2D>("Art/enemy/" + kind);
            sp = tex != null ? Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f), 1f) : null;
            _artCache[kind] = sp;
            return sp;
        }

        public virtual string DisplayName() => Enemies.Names.TryGetValue(kind, out var n) ? n : kind;

        public void Setup(string k, int w, Vector2 p)
        {
            kind = k; wave = w; pos = p; _lastPos = p; t = 0f; fireT = 0f; flash = 0f; state = 0; _stateT = 0f; _spawnIn = 0.35f;
            kb = Vector2.zero; _kbHitCd = 0f; _ruptureAcc = 0f; _hangT = 0f; lastTag = ""; _chillFrac = 0f;
            st.Clear();
            _phase = Random.value * Gd.TAU;
            _dir = Random.value < 0.5f ? 1f : -1f;
            float hs = 1.2f + w * 0.30f + w * w * 0.017f;
            float ss = 1.08f + w * 0.03f;
            color = Gd.C_ENEMY; contactDmg = 12f;
            switch (k)
            {
                case "grunt": maxHp = 16f * hs; speed = 118f * ss; radius = 15f; score = 10; xp = 4; fireT = Gd.Rand(1f, 2.6f); break;
                case "weaver": maxHp = 22f * hs; speed = 98f * ss; radius = 16f; score = 18; xp = 5; color = Gd.C_ENEMY2; fireT = Gd.Rand(1.4f, 3f); break;
                case "charger": maxHp = 30f * hs; speed = 470f * ss; radius = 17f; score = 25; xp = 7; contactDmg = 22f; color = Gd.C_ENEMY3; break;
                case "turret": maxHp = 46f * hs; speed = 60f; radius = 20f; score = 35; xp = 10; contactDmg = 14f; color = new Color(0.55f, 0.85f, 1f); fireT = 1.6f; break;
                case "splitter": maxHp = 40f * hs; speed = 84f * ss; radius = 21f; score = 30; xp = 9; contactDmg = 14f; color = new Color(0.45f, 1f, 0.65f); fireT = Gd.Rand(1.5f, 3f); break;
                case "mini": maxHp = 10f * hs; speed = 210f * ss; radius = 10f; score = 8; xp = 2.5f; contactDmg = 9f; color = new Color(0.45f, 1f, 0.65f); break;
                case "spirit": maxHp = 8f * hs; speed = 150f * ss; radius = 11f; score = 6; xp = 2; contactDmg = 8f; color = new Color(0.70f, 0.85f, 1f); break;
                case "lantern": maxHp = 34f * hs; speed = 60f; radius = 18f; score = 30; xp = 8; contactDmg = 14f; color = new Color(1f, 0.55f, 0.35f); fireT = Gd.Rand(1.5f, 2.5f); break;
                case "kite": maxHp = 20f * hs; speed = 230f * ss; radius = 14f; score = 22; xp = 6; color = new Color(1f, 0.35f, 0.35f); fireT = Gd.Rand(0.8f, 1.6f); break;
                case "oni": maxHp = 95f * hs; speed = 42f * ss; radius = 24f; score = 60; xp = 16; contactDmg = 26f; color = new Color(0.85f, 0.25f, 0.30f); fireT = 2f; break;
                case "caster": maxHp = 40f * hs; speed = 80f; radius = 16f; score = 45; xp = 12; color = new Color(0.85f, 0.75f, 1f); fireT = 1.8f; _stateT = 3f; break;
                case "bomber": maxHp = 26f * hs; speed = 120f * ss; radius = 13f; score = 20; xp = 7; contactDmg = 18f; color = new Color(1f, 0.62f, 0.25f); break;
                default: maxHp = 16f * hs; speed = 118f * ss; radius = 15f; break;
            }
            hp = maxHp;
            _sprite = (k == "boss" || (GameManager.I != null && !GameManager.I.enemySprites)) ? null : EnemyArt(k);
            _spr.enabled = _sprite != null;
            if (_sprite != null)
            {
                _spr.sprite = _sprite;
                float sc = radius * 2.7f / Mathf.Max(_sprite.rect.height, 1f);
                _spr.transform.localScale = new Vector3(sc, sc, 1f);
                _spr.color = Color.white;
            }
            Active = true;
            gameObject.SetActive(true);
            Apply();
            Draw();
        }

        protected Player P() { var g = GameManager.I; return g != null && g.player != null && g.player.alive ? g.player : null; }

        public virtual void Tick(float dt, GameManager g)
        {
            t += dt;
            if (flash > 0f) flash = Mathf.Max(0f, flash - dt * 6f);
            if (_spawnIn > 0f) _spawnIn = Mathf.Max(0f, _spawnIn - dt);
            _kbHitCd = Mathf.Max(0f, _kbHitCd - dt);
            TickStatus(dt);
            if (!Active) return;
            if (st.frozen <= 0f && st.stagger <= 0f) Behavior(dt * SpeedMult() * g.enemySlow, g);
            if (!Active) return;
            if (kb.sqrMagnitude > 1f)
            {
                var before = pos;
                pos += kb * dt;
                kb = Vector2.Lerp(kb, Vector2.zero, Mathf.Clamp01(6f * dt));
                CheckKbCollision(before, g);
            }
            else kb = Vector2.zero;
            if (st.rupture > 0f)
            {
                _ruptureAcc += Vector2.Distance(pos, _lastPos);
                if (_ruptureAcc >= 24f) { _ruptureAcc -= 24f; Combat.StatusDamage(this, Combat.RuptureDmg(), "rupture"); }
            }
            _lastPos = pos;
            if (!Active) return;
            if (pos.y > Gd.H + 90f || pos.y < -420f || pos.x < -260f || pos.x > Gd.W + 260f) { Despawn(); return; }
            Apply();
            Draw();
        }

        // ---------- 神威 ----------

        public void TickStatusPublic(float dt) => TickStatus(dt);

        protected void TickStatus(float dt)
        {
            st.exposed = Mathf.Max(0, st.exposed - dt); st.rupture = Mathf.Max(0, st.rupture - dt); st.jolted = Mathf.Max(0, st.jolted - dt);
            st.weak = Mathf.Max(0, st.weak - dt); st.charm = Mathf.Max(0, st.charm - dt); st.frozen = Mathf.Max(0, st.frozen - dt);
            st.sunslow = Mathf.Max(0, st.sunslow - dt); st.stagger = Mathf.Max(0, st.stagger - dt);
            if (st.doomT >= 0f)
            {
                st.doomT -= dt;
                if (st.doomT <= 0f) { float d = st.doomDmg; st.doomT = -1f; st.doomDmg = 0f; Combat.DoomTrigger(this, d); }
            }
            if (st.hangoverStacks > 0)
            {
                st.hangoverT -= dt; _hangT += dt;
                if (_hangT >= 0.5f) { _hangT -= 0.5f; Combat.StatusDamage(this, st.hangoverDps * st.hangoverStacks * 0.5f, "hangover"); }
                if (st.hangoverT <= 0f) st.hangoverStacks = 0;
            }
            if (st.chillStacks > 0) { st.chillT -= dt; if (st.chillT <= 0f) st.chillStacks = 0; }
        }

        public float FireMult()
        {
            float m = 1f;
            if (st.chillStacks > 0) m *= 1f - Mathf.Min(0.1f * st.chillStacks, isBoss ? 0.25f : 0.5f);
            if (st.hangoverStacks > 0) m *= 1f - (isBoss ? 0.1f : 0.2f);
            return m;
        }

        public float SpeedMult()
        {
            float m = 1f;
            if (st.chillStacks > 0) m *= 1f - Mathf.Min(0.12f * st.chillStacks, isBoss ? 0.3f : 0.6f);
            if (st.hangoverStacks > 0) m *= 1f - Combat.HangoverSlow();
            if (st.charm > 0f) m *= 0.6f;
            if (st.sunslow > 0f) { var pl = P(); if (pl != null) m *= 1f - Mathf.Min(pl.Val("ama_u6") * 0.01f, isBoss ? 0.25f : 0.5f); }
            return m;
        }

        public float OutDmgMult()
        {
            float m = 1f;
            if (st.weak > 0f) m *= 1f - Combat.WeakAmount();
            if (st.hangoverStacks > 0) m *= 1f - Combat.HangoverSlow();
            return m;
        }

        public void AddExposed(float sec) => st.exposed = Mathf.Max(st.exposed, sec);
        public void AddRupture(float sec) => st.rupture = Mathf.Max(st.rupture, sec);
        public void AddJolt(float sec) => st.jolted = Mathf.Max(st.jolted, sec);
        public void AddWeak(float sec) => st.weak = Mathf.Max(st.weak, sec);
        public void AddCharm(float sec) { if (isBoss) sec *= 0.4f; st.charm = Mathf.Max(st.charm, sec); Fx.Petals(pos, new Color(1f, 0.5f, 0.75f), 6, 90f); }
        public void Mark() => st.marked = true;
        public void AddDoom(float dmg, float delay = 1.1f)
        {
            if (st.doomT < 0f) { st.doomT = delay; st.doomDmg = dmg; }
            else st.doomDmg = Mathf.Max(st.doomDmg, dmg);
        }
        public void AddHangover(int stacks, float dps)
        {
            st.hangoverStacks = Mathf.Min(st.hangoverStacks + stacks, Combat.HangoverMax());
            st.hangoverT = 4f;
            st.hangoverDps = Mathf.Max(st.hangoverDps, dps);
        }
        private float _chillFrac;   // ボス：冷気は半分の速さで溜まる（端数を持ち越す）
        public void AddChill(int stacks)
        {
            if (isBoss)
            {
                // ボス戦では冷気の効きを半減：段数が半分ずつしか溜まらないので、鈍化も砕けの頻度も半分になる
                _chillFrac += stacks * 0.5f;
                stacks = Mathf.FloorToInt(_chillFrac); _chillFrac -= stacks;
                if (stacks <= 0) { st.chillT = 5f; return; }
            }
            st.chillStacks += stacks; st.chillT = 5f;
            if (st.chillStacks >= Combat.CHILL_MAX) { st.chillStacks = 0; Combat.Shatter(this); }
        }
        public void Stagger(float sec) { if (isBoss) sec *= 0.4f; st.stagger = Mathf.Max(st.stagger, sec); Fx.Sparks(pos, Vector2.up, Color.white, 5, 200f); }
        public void Freeze(float sec) { if (isBoss) sec *= 0.5f; st.frozen = Mathf.Max(st.frozen, sec); Fx.Burst(pos, new Color(0.8f, 0.95f, 1f), 8, 120f, 3f, 0.4f, true); }
        public void Knockback(Vector2 v) { if (isBoss) v *= 0.12f; kb += v; _kbHitCd = 0f; }

        private void CheckKbCollision(Vector2 before, GameManager g)
        {
            if (_kbHitCd > 0f || kb.magnitude < 120f) return;
            float minX = radius, maxX = Gd.W - radius;
            if (pos.x < minX || pos.x > maxX)
            {
                pos.x = Mathf.Clamp(pos.x, minX, maxX);
                kb.x = -kb.x * 0.4f;
                _kbHitCd = 0.3f;
                Combat.Collide(this, null);
                return;
            }
            foreach (var o in g.EnemyList())
            {
                if (o == this || !o.Active) continue;
                if (Vector2.Distance(o.pos, pos) < radius + o.radius)
                {
                    _kbHitCd = 0.3f;
                    Combat.Collide(this, o);
                    o.kb += kb * 0.5f;
                    kb *= 0.3f;
                    return;
                }
            }
        }

        // ---------- 行動 ----------

        protected virtual void Behavior(float delta, GameManager g)
        {
            var p = P();
            switch (kind)
            {
                case "grunt":
                    pos.y += speed * delta;
                    pos.x += Mathf.Sin(t * 1.4f + _phase) * 26f * delta;
                    fireT -= delta * FireMult();
                    if (fireT <= 0f && pos.y > 40f && pos.y < Gd.H * 0.75f) { fireT = Cool(2.4f, 3.8f); ShootAimed(wave < 4 ? 1 : 2, 10f, Spd(285f)); }
                    break;
                case "weaver":
                    pos.y += speed * delta;
                    pos.x += Mathf.Cos(t * 2.1f + _phase) * 165f * delta * _dir;
                    fireT -= delta * FireMult();
                    if (fireT <= 0f && pos.y > 40f && pos.y < Gd.H * 0.8f) { fireT = Cool(2.6f, 4f); ShootSpread(wave < 4 ? 2 : 3, 22f, Spd(240f)); }
                    break;
                case "charger":
                    if (state == 0) { pos.y += 150f * delta; if (pos.y > Gd.Rand(120f, 300f)) { state = 1; _stateT = 0.55f; } }
                    else if (state == 1)
                    {
                        _stateT -= delta; pos.y += 14f * delta;
                        if (_stateT <= 0f) { state = 2; _chargeDir = p != null ? (p.pos - pos).normalized : Vector2.up; Sfx.Play("eshot", -16f, 0.7f, 0.05f); }
                    }
                    else { pos += _chargeDir * speed * delta; Fx.Cone(pos, -_chargeDir, color, 1, 60f, 0.5f, 3f, 0.25f); }
                    break;
                case "turret":
                    if (pos.y < 130f) pos.y += speed * delta; else pos.x += Mathf.Sin(t * 0.8f + _phase) * 60f * delta;
                    fireT -= delta * FireMult();
                    if (fireT <= 0f && pos.y >= 100f) { fireT = Cool(2.6f, 3.2f); ShootRadial(8 + Mathf.Min(5, wave / 4), Spd(215f), t * 0.6f); }
                    break;
                case "splitter":
                    pos.y += speed * delta;
                    pos.x += Mathf.Sin(t * 1.1f + _phase) * 40f * delta;
                    fireT -= delta * FireMult();
                    if (fireT <= 0f && pos.y > 40f && pos.y < Gd.H * 0.8f) { fireT = Cool(2.8f, 4.2f); ShootAimed(2, 14f, Spd(235f)); }
                    break;
                case "mini":
                    {
                        Vector2 dir = p != null ? (p.pos - pos).normalized : Vector2.up;
                        pos += Vector2.Lerp(dir, Vector2.up, 0.35f) * speed * delta;   // 自機へ寄りつつ画面の下へ（Godot の DOWN）
                        break;
                    }
                case "spirit":
                    pos.y += speed * 0.6f * delta;
                    pos.x += Mathf.Sin(t * 2.6f + _phase) * 120f * delta;
                    pos.y += Mathf.Cos(t * 1.7f + _phase) * 40f * delta;
                    break;
                case "lantern":
                    {
                        float ty = 160f + 100f * (0.5f + 0.5f * Mathf.Sin(_phase));
                        if (pos.y < ty) pos.y += speed * delta; else { pos.x += Mathf.Sin(t * 0.7f + _phase) * 50f * delta; pos.y += 8f * delta; }
                        fireT -= delta * FireMult();
                        if (fireT <= 0f && pos.y >= ty - 20f) { fireT = Cool(2.6f, 3.4f); ShootAimed(3, 16f, Spd(150f), 9f); }
                        break;
                    }
                case "kite":
                    if (state == 0) { state = 1; _dir = pos.x < Gd.W * 0.5f ? 1f : -1f; }
                    pos.x += speed * _dir * delta;
                    pos.y += (70f + Mathf.Sin(t * 3f + _phase) * 90f) * delta;
                    fireT -= delta * FireMult();
                    if (fireT <= 0f && pos.x > 30f && pos.x < Gd.W - 30f) { fireT = Cool(1.2f, 2f); Emit(Mathf.PI * 0.5f, 1, 0f, Spd(220f)); }
                    if ((pos.x < -60f && _dir < 0f) || (pos.x > Gd.W + 60f && _dir > 0f)) Despawn();
                    break;
                case "oni":
                    pos.y += speed * delta;
                    fireT -= delta * FireMult();
                    if (fireT <= 0f && pos.y > 40f) { fireT = Cool(3.2f, 4f); ShootRadial(10 + Mathf.Min(6, wave / 5), Spd(170f), Random.value * Gd.TAU); Fx.RingFx(pos, color, radius * 0.6f, radius * 1.8f, 0.25f); }
                    break;
                case "caster":
                    if (pos.y < 130f) pos.y += speed * delta;
                    else
                    {
                        _stateT -= delta;
                        if (_stateT <= 0f)
                        {
                            _stateT = Gd.Rand(3f, 4.5f);
                            Fx.Burst(pos, color, 10, 160f, 3f, 0.35f, true);
                            pos.x = Gd.Rand(60f, Gd.W - 60f); pos.y = Gd.Rand(110f, 220f);
                            Fx.RingFx(pos, color, 4f, radius * 3f, 0.3f, 2f);
                            _spawnIn = 0.3f;
                        }
                        fireT -= delta * FireMult();
                        if (fireT <= 0f && _spawnIn <= 0f)
                        {
                            fireT = Cool(2.4f, 3.2f);
                            if (p != null)
                            {
                                for (int i = 0; i < 2; i++)
                                {
                                    float a = Gd.Angle(p.pos - pos) + (i - 0.5f) * 0.6f;
                                    g.SpawnEnemyBullet(pos, Gd.Dir(a) * Spd(180f), BulletDmg(), 6f, new Color(0.85f, 0.7f, 1f), 1.8f, "陰陽師の式神");
                                }
                                OnFire();
                                Sfx.Play("eshot", -14f, 1.3f, 0.05f);
                            }
                        }
                    }
                    break;
                case "bomber":
                    if (state == 0 && pos.y > 90f) { state = 1; if (p != null) _chargeDir = (p.pos - pos).normalized; }
                    if (state == 0) pos.y += speed * delta;
                    else
                    {
                        speed = Mathf.Min(speed + 260f * delta, 420f);
                        pos += _chargeDir * speed * delta;
                        Fx.Cone(pos, -_chargeDir, color, 1, 60f, 0.5f, 3f, 0.25f);
                        if (p != null && Vector2.Distance(pos, p.pos) < 70f) { Explode(); return; }
                    }
                    break;
            }
        }

        // ---------- 射撃 ----------

        protected float Cool(float lo, float hi) => Gd.Rand(lo, hi) * 1.18f * Mathf.Clamp(0.88f - wave * 0.012f, 0.62f, 1f);
        protected float Spd(float b) { var p = P(); float curse = p != null && p.Has("curse_edge") ? 1.15f : 1f; return b * (1.15f + wave * 0.02f) * curse; }
        protected float BulletDmg() => (9f + wave * 1.1f + wave * wave * 0.02f) * OutDmgMult();

        protected void ShootAimed(int count, float spreadDeg, float spd, float radiusB = 5f)
        {
            var target = AimTarget();
            if (!target.HasValue) return;
            Emit(Gd.Angle(target.Value - pos), count, spreadDeg, spd, radiusB);
        }

        protected void ShootSpread(int count, float spreadDeg, float spd)
        {
            if (st.charm > 0f) { ShootAimed(count, spreadDeg, spd); return; }
            Emit(Mathf.PI * 0.5f, count, spreadDeg, spd);
        }

        protected void ShootRadial(int count, float spd, float offset = 0f)
        {
            OnFire();
            for (int i = 0; i < count; i++) SpawnShot(Gd.Dir(offset + Gd.TAU * i / count) * spd);
            Sfx.Play("eshot", -14f, 0.85f, 0.04f);
        }

        protected void Emit(float baseA, int count, float spreadDeg, float spd, float radiusB = 5f)
        {
            OnFire();
            float step = spreadDeg * Mathf.Deg2Rad;
            for (int i = 0; i < count; i++) SpawnShot(Gd.Dir(baseA + (i - (count - 1) * 0.5f) * step) * spd, radiusB);
            Sfx.Play("eshot", -16f, Gd.Rand(0.9f, 1.1f), 0.04f);
        }

        private void Explode()
        {
            if (hp <= 0f) return;
            Fx.Burst(pos, color, 16, 260f, 4f, 0.5f);
            Fx.RingFx(pos, color, 6f, 60f, 0.3f, 4f);
            Sfx.Play("explode", -10f, 1.2f);
            OnFire();
            for (int i = 0; i < 8; i++) SpawnShot(Gd.Dir(Gd.TAU * i / 8f + Gd.Rand(-0.1f, 0.1f)) * Spd(190f), 6f);
            hp = 0f;
            GameManager.I.OnEnemyKilled(this);
            Despawn();
        }

        /// <summary>魅了中は仲間を狙う。狙う相手がいなければ null。</summary>
        protected Vector2? AimTarget()
        {
            if (st.charm > 0f)
            {
                Enemy best = null; float bd = float.MaxValue;
                foreach (var e in GameManager.I.EnemyList()) { if (e == this || !e.Active) continue; float d = (pos - e.pos).sqrMagnitude; if (d < bd) { bd = d; best = e; } }
                return best != null ? best.pos : (Vector2?)null;
            }
            var p = P();
            return p != null ? p.pos : (Vector2?)null;
        }

        protected void SpawnShot(Vector2 vel, float radiusB = 5f)
        {
            if (st.charm > 0f) GameManager.I.SpawnCharmedBullet(pos, vel * 1.3f, BulletDmg() * 1.5f);
            else GameManager.I.SpawnEnemyBullet(pos, vel, BulletDmg() * (1f + (radiusB - 5f) * 0.08f), radiusB, Gd.C_EBULLET, 0f, DisplayName() + "の弾");
        }

        protected void OnFire() { if (st.jolted > 0f) Combat.JoltTrigger(this); }

        // ---------- 被弾・撃破 ----------

        public virtual bool TakeDamage(float d, bool crit, Vector2 at, bool quiet = false)
        {
            if (hp <= 0f || !Active) return false;
            hp -= d;
            flash = quiet ? Mathf.Max(flash, 0.5f) : 1f;
            if (crit)
            {
                Fx.Number(at + new Vector2(0, -radius - 6f), Mathf.RoundToInt(d) + "!", Gd.C_CRIT, 26f, true);
                Fx.Rays(at, Gd.C_CRIT, 8, 6f, 34f, 0.22f);
                Fx.Puff(at, 6f, radius * 2.4f, Gd.WithA(Gd.C_CRIT, 0.9f), 0.25f);
                Fx.Sparks(at, Vector2.up, Gd.C_CRIT, 8, 420f);
            }
            else if (!quiet || Random.value < 0.3f)
                Fx.Number(at + new Vector2(0, -radius), Mathf.RoundToInt(d).ToString(), new Color(1, 1, 1, 0.92f), quiet ? 11f : 14f, false);
            if (hp <= 0f) { Die(); return true; }
            return false;
        }

        public virtual void Die()
        {
            if (!Active) return;
            Fx.Burst(pos, color, 16, 300f, 5f, 0.55f);
            Fx.RingFx(pos, color, radius * 0.5f, radius * 4f, 0.3f);
            Fx.Puff(pos, radius * 1.2f, radius * 4.5f, Gd.WithA(color, 0.9f), 0.4f);
            Fx.ShakeAdd(3f);
            Sfx.Play("explode", -10f, Gd.Rand(0.9f, 1.15f), 0.02f);
            var g = GameManager.I;
            if (kind == "splitter") for (int i = 0; i < 2; i++) g.SpawnEnemy("mini", pos + new Vector2(-22f + 44f * i, 0));
            if (kind == "bomber") for (int i = 0; i < 6; i++) g.SpawnEnemyBullet(pos, Gd.Dir(Gd.TAU * i / 6f) * Spd(150f), BulletDmg() * 0.7f, 5f, Gd.C_EBULLET, 0f, "火の玉の爆散");
            Active = false;
            g.OnEnemyKilled(this);
            gameObject.SetActive(false);
        }

        public void Despawn() { Active = false; gameObject.SetActive(false); }

        protected void Apply() => transform.position = Gd.ToWorld(pos);


        protected virtual void DrawBodyOverride(Vec v, Color c) => DrawBody(v, c);

        protected void Draw()
        {
            var v = _vec;
            v.Begin();
            Color c = color;
            if (flash > 0f) c = Color.Lerp(c, Color.white, flash * 0.85f);
            if (st.frozen > 0f) c = Color.Lerp(c, new Color(0.75f, 0.92f, 1f), 0.7f);
            else if (st.chillStacks > 0) c = Color.Lerp(c, new Color(0.6f, 0.85f, 1f), 0.06f * st.chillStacks);
            v.Glow(Vector2.zero, radius * 2.6f, Gd.WithA(color, 0.5f));
            if (_spawnIn > 0f)
            {
                float k = _spawnIn / 0.35f;
                v.DrawArc(Vector2.zero, radius * (1f + k * 2.5f), 0f, Gd.TAU, 24, new Color(c.r, c.g, c.b, 1f - k), 2f);
            }
            if (_sprite != null)
            {
                // 絵：閃き・凍結は色で、ゆらぎは少し傾けて表す
                Color tint = Color.white;
                if (flash > 0f) tint = Color.Lerp(tint, new Color(1f, 0.6f, 0.65f), flash * 0.7f);
                if (st.frozen > 0f) tint = Color.Lerp(tint, new Color(0.7f, 0.9f, 1f), 0.7f);
                else if (st.chillStacks > 0) tint = Color.Lerp(tint, new Color(0.7f, 0.88f, 1f), 0.16f * st.chillStacks);
                _spr.color = tint;
                _spr.transform.localRotation = Quaternion.Euler(0, 0, Mathf.Sin(t * 2.2f + _phase) * 6f);
                _spr.transform.localPosition = new Vector3(0, Mathf.Sin(t * 3f + _phase) * 2f, 0);
                if (kind == "charger" && state == 2) _spr.transform.localScale = new Vector3(_spr.transform.localScale.x, _spr.transform.localScale.x * 1.25f, 1f);
            }
            else
            {
                DrawBodyOverride(v, c);
                if (!isBoss)
                {
                    // 輪郭の締めと艶（Godot 版より一段はっきり見えるように）：暗い縁取りと左上の光沢
                    v.DrawArc(Vector2.zero, radius * 1.04f, 0f, Gd.TAU, 28, new Color(0.05f, 0.02f, 0.08f, 0.35f), 1.6f);
                    v.DrawCircle(new Vector2(-radius * 0.38f, -radius * 0.42f), radius * 0.18f, new Color(1f, 1f, 1f, 0.22f));
                    v.DrawArc(new Vector2(0, radius * 0.15f), radius * 0.78f, 0.35f, Mathf.PI - 0.35f, 14, new Color(0f, 0f, 0.05f, 0.18f), radius * 0.28f);
                }
            }
            v.End();
            v = _vecTop; v.Begin();   // ここから絵の前面（状態異常が絵に隠れない）
            DrawStatusAura(v);
            if (fireT > 0f && fireT < 0.35f && (kind == "grunt" || kind == "weaver" || kind == "turret" || kind == "splitter" || kind == "lantern" || kind == "oni" || kind == "caster"))
            {
                float k = fireT / 0.35f;
                v.DrawArc(Vector2.zero, radius * (0.9f + k * 1.4f), 0, Gd.TAU, 24, new Color(1, 0.6f, 0.7f, 0.85f * (1f - k)), 2f);
                v.DrawCircle(Vector2.zero, radius * 0.5f, new Color(1, 0.85f, 0.9f, 0.35f * (1f - k)));
            }
            if (kind == "charger" && state == 1)
            {
                Vector2 d = ((P() != null ? P().pos : pos + Vector2.up) - pos).normalized;
                v.DrawLine(Vector2.zero, d * 900f, new Color(1, 0.4f, 0.5f, 0.25f + 0.2f * Mathf.Sin(t * 30f)), 2f);
            }
            if (kind == "bomber" && state == 0 && pos.y > 40f)
                v.DrawLine(Vector2.zero, ((P() != null ? P().pos : pos + Vector2.up) - pos).normalized * 120f, new Color(1, 0.6f, 0.3f, 0.3f), 1.5f);
            if (hp < maxHp && kind != "mini" && !isBoss)
            {
                float w = radius * 2f, y = -radius - 9f;
                v.DrawRect(new Rect(-w * 0.5f, y, w, 3f), new Color(0, 0, 0, 0.5f));
                v.DrawRect(new Rect(-w * 0.5f, y, w * (hp / maxHp), 3f), new Color(1, 0.45f, 0.5f, 0.95f));
            }
            v.End();
        }

        private void DrawBody(Vec v, Color c)
        {
            float r = radius;
            switch (kind)
            {
                case "grunt":
                    {
                        var pts = new Vector2[12];
                        for (int i = 0; i < 12; i++)
                        {
                            float a = Gd.TAU * i / 12f;
                            float rr = r * (0.85f + 0.2f * Mathf.Sin(a * 3f + t * 9f));
                            if (a > Mathf.PI * 1.2f && a < Mathf.PI * 1.8f) rr *= 1.35f;
                            pts[i] = Gd.Dir(a) * rr;
                        }
                        v.DrawColoredPolygon(pts, c);
                        v.DrawCircle(new Vector2(-r * 0.3f, r * 0.05f), r * 0.16f, new Color(1, 1, 1, 0.9f));
                        v.DrawCircle(new Vector2(r * 0.3f, r * 0.05f), r * 0.16f, new Color(1, 1, 1, 0.9f));
                        break;
                    }
                case "weaver":
                    {
                        var pts2 = new[] { new Vector2(0, r * 1.05f), new Vector2(r * 1.15f, 0), new Vector2(0, -r * 1.05f), new Vector2(-r * 1.15f, 0) };
                        v.DrawColoredPolygon(pts2, c);
                        v.DrawPolyline(new[] { pts2[0], pts2[1], pts2[2], pts2[3], pts2[0] }, new Color(1, 1, 1, 0.7f), 1.6f);
                        v.DrawCircle(Vector2.zero, r * 0.3f, new Color(1, 1, 1, 0.9f));
                        v.DrawCircle(Vector2.zero, r * 0.14f, Gd.C_INK);
                        break;
                    }
                case "charger":
                    {
                        float stretch = state != 2 ? 1f : 1.35f;
                        v.DrawColoredPolygon(new[] { new Vector2(0, r * 1.2f * stretch), new Vector2(r * 0.85f, -r * 0.7f), new Vector2(0, -r * 0.3f), new Vector2(-r * 0.85f, -r * 0.7f) }, c);
                        if (state == 1) v.DrawCircle(Vector2.zero, r * 0.45f, new Color(1, 0.9f, 0.3f, 0.5f + 0.5f * Mathf.Sin(t * 30f)));
                        else v.DrawCircle(Vector2.zero, r * 0.32f, new Color(1, 1, 1, 0.9f));
                        break;
                    }
                case "turret":
                    v.DrawCircle(Vector2.zero, r, c);
                    v.DrawArc(Vector2.zero, r * 1.28f, 0f, Gd.TAU, 26, new Color(1, 1, 1, 0.55f), 2f);
                    for (int i = 0; i < 6; i++)
                    {
                        Vector2 p = Gd.Dir(t * 0.6f + Gd.TAU * i / 6f) * r * 1.28f;
                        v.DrawCircle(p, 3.5f, new Color(1, 1, 1, 0.9f));
                        v.DrawCircle(p, 1.6f, Gd.C_INK);
                    }
                    v.DrawCircle(Vector2.zero, r * 0.42f, Gd.C_BG);
                    v.DrawCircle(Vector2.zero, r * 0.2f, new Color(1, 0.3f, 0.3f));
                    break;
                case "splitter":
                    v.DrawCircle(Vector2.zero, r, c);
                    v.DrawLine(new Vector2(0, -r), new Vector2(0, r), new Color(0.05f, 0.1f, 0.1f, 0.9f), 3f);
                    v.DrawArc(Vector2.zero, r * 0.62f, 0f, Gd.TAU, 22, new Color(1, 1, 1, 0.6f), 2f);
                    break;
                case "mini":
                    v.DrawCircle(Vector2.zero, r, c);
                    v.DrawCircle(Vector2.zero, r * 0.45f, new Color(1, 1, 1, 0.85f));
                    break;
                case "spirit":
                    {
                        Vector2 tail = new Vector2(-Mathf.Sin(t * 2.6f + _phase) * 6f, -r * 2.2f);
                        v.DrawColoredPolygon(new[] { new Vector2(-r * 0.8f, 0), tail, new Vector2(r * 0.8f, 0) }, Gd.WithA(c, 0.5f));
                        v.DrawCircle(Vector2.zero, r, c);
                        v.DrawCircle(new Vector2(-r * 0.3f, -r * 0.1f), r * 0.15f, Gd.C_INK);
                        v.DrawCircle(new Vector2(r * 0.3f, -r * 0.1f), r * 0.15f, Gd.C_INK);
                        break;
                    }
                case "lantern":
                    v.DrawRect(new Rect(-r * 0.6f, -r * 1.25f, r * 1.2f, r * 0.25f), Gd.C_INK);
                    v.DrawCircle(Vector2.zero, r, c);
                    for (int i = 0; i < 5; i++)
                    {
                        float yy = -r + r * 2f * (i + 1) / 6f;
                        float hw = Mathf.Sqrt(Mathf.Max(0f, r * r - yy * yy));
                        v.DrawLine(new Vector2(-hw, yy), new Vector2(hw, yy), new Color(0.4f, 0.1f, 0.1f, 0.6f), 1f);
                    }
                    v.DrawRect(new Rect(-r * 0.6f, r, r * 1.2f, r * 0.25f), Gd.C_INK);
                    v.DrawLine(new Vector2(0, r * 1.25f), new Vector2(0, r * 1.7f), Gd.WithA(c, 0.9f), 2f);
                    v.DrawCircle(new Vector2(0, -r * 0.2f), r * 0.32f, new Color(1, 1, 0.9f));
                    v.DrawCircle(new Vector2(0, -r * 0.2f), r * 0.14f, Gd.C_INK);
                    v.DrawArc(new Vector2(0, r * 0.35f), r * 0.3f, 0.2f, Mathf.PI - 0.2f, 10, Gd.C_INK, 2f);
                    break;
                case "kite":
                    {
                        var pts4 = new[] { new Vector2(0, -r * 1.3f), new Vector2(r, 0), new Vector2(0, r * 1.3f), new Vector2(-r, 0) };
                        v.DrawColoredPolygon(pts4, c);
                        v.DrawPolyline(new[] { pts4[0], pts4[1], pts4[2], pts4[3], pts4[0] }, new Color(1, 1, 1, 0.8f), 1.5f);
                        v.DrawLine(new Vector2(0, -r * 1.3f), new Vector2(0, r * 1.3f), new Color(1, 1, 1, 0.6f), 1f);
                        v.DrawLine(new Vector2(-r, 0), new Vector2(r, 0), new Color(1, 1, 1, 0.6f), 1f);
                        v.DrawCircle(Vector2.zero, r * 0.3f, new Color(1, 1, 1, 0.9f));
                        v.DrawCircle(Vector2.zero, r * 0.14f, Gd.C_INK);
                        for (int i = 0; i < 3; i++) v.DrawCircle(new Vector2(-_dir * (i + 1) * 9f, r * 1.3f + Mathf.Sin(t * 8f + i) * 4f), 2.5f, Gd.WithA(c, 0.8f - 0.2f * i));
                        break;
                    }
                case "oni":
                    v.DrawCircle(Vector2.zero, r, c);
                    v.DrawArc(Vector2.zero, r, 0, Gd.TAU, 28, new Color(0, 0, 0, 0.35f), 2f);
                    foreach (float sgn in new[] { -1f, 1f })
                    {
                        v.DrawColoredPolygon(new[] { new Vector2(sgn * r * 0.35f, -r * 0.7f), new Vector2(sgn * r * 0.5f, -r * 1.35f), new Vector2(sgn * r * 0.7f, -r * 0.6f) }, new Color(1, 0.95f, 0.85f));
                        v.DrawCircle(new Vector2(sgn * r * 0.35f, -r * 0.15f), r * 0.18f, new Color(1, 0.95f, 0.6f));
                        v.DrawCircle(new Vector2(sgn * r * 0.35f, -r * 0.15f), r * 0.08f, Gd.C_INK);
                    }
                    v.DrawArc(new Vector2(0, r * 0.3f), r * 0.4f, 0.3f, Mathf.PI - 0.3f, 12, Gd.C_INK, 3f);
                    for (int i = 0; i < 4; i++) { float x = (i - 1.5f) * r * 0.22f; v.DrawColoredPolygon(new[] { new Vector2(x - 2, r * 0.45f), new Vector2(x + 2, r * 0.45f), new Vector2(x, r * 0.7f) }, new Color(1, 0.95f, 0.85f)); }
                    break;
                case "caster":
                    v.DrawColoredPolygon(new[] { new Vector2(-r, r), new Vector2(r, r), new Vector2(r * 0.35f, -r * 0.5f), new Vector2(-r * 0.35f, -r * 0.5f) }, Gd.C_PAPER);
                    v.DrawCircle(new Vector2(0, -r * 0.7f), r * 0.4f, new Color(1, 0.9f, 0.85f));
                    v.DrawRect(new Rect(-r * 0.3f, -r * 1.5f, r * 0.6f, r * 0.55f), Gd.C_INK);
                    v.DrawLine(new Vector2(-r * 0.4f, r * 0.2f), new Vector2(r * 0.4f, r * 0.2f), Gd.WithA(c, 0.9f), 2f);
                    for (int i = 0; i < 3; i++) v.DrawCircle(Gd.Dir(t * 3f + Gd.TAU * i / 3f) * r * 1.5f, 3f, Gd.WithA(c, 0.9f));
                    break;
                case "bomber":
                    {
                        float fl = 1f + (state == 1 ? 0.35f : 0.15f) * Mathf.Sin(t * 30f);
                        v.DrawColoredPolygon(new[] { new Vector2(0, -r * 2.2f * fl), new Vector2(r * 1.1f, 0), new Vector2(0, r * 1.1f), new Vector2(-r * 1.1f, 0) }, c);
                        v.DrawCircle(Vector2.zero, r * 0.6f, new Color(1, 0.95f, 0.7f, 0.95f));
                        v.DrawCircle(Vector2.zero, r * 0.3f, new Color(1, 0.4f, 0.2f));
                        break;
                    }
                default:
                    v.DrawCircle(Vector2.zero, r, c);
                    break;
            }
        }

        private void Star(Vec v, Vector2 p, float r, Color c)
        {
            var pts = new Vector2[10];
            for (int i = 0; i < 10; i++) { float a = -Mathf.PI * 0.5f + Gd.TAU * i / 10f; float rr = i % 2 == 0 ? r : r * 0.45f; pts[i] = p + Gd.Dir(a) * rr; }
            v.DrawColoredPolygon(pts, c);
        }

        private void DrawStatusAura(Vec v)
        {
            float r = radius;
            if (st.exposed > 0f)
            {
                var c = new Color(1f, 0.84f, 0.42f);
                v.DrawArc(Vector2.zero, r + 4f, 0, Gd.TAU, 28, Gd.WithA(c, 0.85f), 2.5f);
                for (int i = 0; i < 6; i++) { float a = t * 1.5f + Gd.TAU * i / 6f; v.DrawLine(Gd.Dir(a) * (r + 6f), Gd.Dir(a) * (r + 12f + 3f * Mathf.Sin(t * 6f + i)), Gd.WithA(c, 0.7f), 1.5f); }
            }
            if (st.weak > 0f)
            {
                var c = new Color(1f, 0.58f, 0.78f);
                v.DrawCircle(Vector2.zero, r * 1.5f, Gd.WithA(c, 0.10f));
                for (int i = 0; i < 4; i++)
                {
                    float k = Mathf.Repeat(t * 0.7f + i * 0.25f, 1f);
                    Vector2 p = new Vector2(Mathf.Sin(t * 2f + i * 1.7f) * r, -r * 1.4f + k * r * 2.8f);
                    Vector2 dd = Gd.Dir(t * 3f + i);
                    v.DrawColoredPolygon(new[] { p + dd * 4f, p + Gd.Orth(dd) * 2f, p - dd * 4f, p - Gd.Orth(dd) * 2f }, Gd.WithA(c, 0.85f * (1f - k)));
                }
            }
            if (st.charm > 0f)
            {
                var c = new Color(1f, 0.45f, 0.7f);
                v.DrawArc(Vector2.zero, r + 3f, 0, Gd.TAU, 24, Gd.WithA(c, 0.5f + 0.3f * Mathf.Sin(t * 6f)), 2f);
                Vector2 hp2 = new Vector2(0, -r - 14f + Mathf.Sin(t * 4f) * 2f);
                v.DrawCircle(hp2 + new Vector2(-3, -2), 3f, c); v.DrawCircle(hp2 + new Vector2(3, -2), 3f, c);
                v.DrawColoredPolygon(new[] { hp2 + new Vector2(-6, -1), hp2 + new Vector2(6, -1), hp2 + new Vector2(0, 6) }, c);
            }
            if (st.hangoverStacks > 0)
            {
                var c = new Color(0.62f, 1f, 0.55f);
                v.DrawCircle(Vector2.zero, r * 1.35f, Gd.WithA(c, 0.10f + 0.02f * st.hangoverStacks));
                for (int i = 0; i < Mathf.Min(st.hangoverStacks + 2, 8); i++)
                {
                    float k = Mathf.Repeat(t * 0.9f + i * 0.37f, 1f);
                    Vector2 p = new Vector2(Mathf.Sin(i * 2.1f + t) * r * 0.8f, r * 0.6f - k * r * 2.4f);
                    v.DrawArc(p, 2f + 2f * (1f - k), 0, Gd.TAU, 10, Gd.WithA(c, 0.9f * (1f - k)), 1.2f);
                }
            }
            if (st.chillStacks > 0 || st.frozen > 0f)
            {
                // 冷気：体に氷の膜と水色の輪、周りに結晶。段数は上に並ぶ小さな氷で示す。凍結は氷の塊
                var c = new Color(0.8f, 0.95f, 1f);
                int stacks = st.frozen > 0f ? Combat.CHILL_MAX : st.chillStacks;
                v.DrawCircle(Vector2.zero, r * 1.05f, Gd.WithA(new Color(0.6f, 0.85f, 1f), st.frozen > 0f ? 0.45f : 0.10f + 0.06f * stacks));
                v.DrawArc(Vector2.zero, r + 4f, 0, Gd.TAU, 28, Gd.WithA(c, 0.9f), 2.5f);
                int n = st.frozen <= 0f ? Mathf.Min(stacks * 2, 10) : 12;
                for (int i = 0; i < n; i++)
                {
                    float a = i * 2.4f + 0.3f;
                    Vector2 p = Gd.Dir(a) * r * 0.9f, dd = Gd.Dir(a);
                    v.DrawColoredPolygon(new[] { p + dd * 11f, p + Gd.Orth(dd) * 3.5f, p - dd * 3f, p - Gd.Orth(dd) * 3.5f }, new Color(1, 1, 1, 0.95f));
                    v.DrawColoredPolygon(new[] { p + dd * 9f, p + Gd.Orth(dd) * 2f, p - dd * 1.5f, p - Gd.Orth(dd) * 2f }, Gd.WithA(c, 0.9f));
                }
                for (int i = 0; i < Mathf.Min(stacks, Combat.CHILL_MAX); i++)
                {
                    Vector2 q = new Vector2((i - (Mathf.Min(stacks, Combat.CHILL_MAX) - 1) * 0.5f) * 10f, -r - 22f);
                    v.DrawColoredPolygon(new[] { q + new Vector2(0, -5), q + new Vector2(4, 0), q + new Vector2(0, 5), q + new Vector2(-4, 0) }, new Color(1, 1, 1, 0.95f));
                    v.DrawColoredPolygon(new[] { q + new Vector2(0, -3), q + new Vector2(2.4f, 0), q + new Vector2(0, 3), q + new Vector2(-2.4f, 0) }, new Color(0.55f, 0.85f, 1f, 0.95f));
                }
                if (st.frozen > 0f) { v.DrawCircle(Vector2.zero, r * 1.25f, Gd.WithA(c, 0.4f)); v.DrawArc(Vector2.zero, r * 1.25f, 0, Gd.TAU, 24, new Color(1, 1, 1, 0.9f), 3f); }
            }
            if (st.stagger > 0f)
                for (int i = 0; i < 3; i++) { float a = t * 7f + Gd.TAU * i / 3f; Star(v, new Vector2(Mathf.Cos(a) * (r + 6f), -r - 10f + Mathf.Sin(a) * 4f), 3.5f, new Color(1, 1, 0.85f, 0.9f)); }
            if (st.jolted > 0f)
            {
                var c = new Color(1f, 0.95f, 0.5f);
                for (int i = 0; i < 3; i++) { Vector2 p0 = Gd.Dir(t * 9f + i * 2.1f) * (r + 4f); v.DrawLine(p0, p0 + new Vector2(Gd.Rand(-6, 6), Gd.Rand(-6, 6)), Gd.WithA(c, 0.9f), 1.5f); }
                v.DrawArc(Vector2.zero, r + 3f, 0, Gd.TAU, 20, Gd.WithA(c, 0.35f), 1f);
            }
            if (st.rupture > 0f)
            {
                var c = new Color(0.35f, 0.82f, 0.95f);
                for (int i = 0; i < 3; i++) { float a = i * 2f + 0.5f; v.DrawLine(Gd.Dir(a) * r * 0.2f, Gd.Dir(a) * r * 0.95f, Gd.WithA(c, 0.9f), 2f); v.DrawLine(Gd.Dir(a) * r * 0.2f, Gd.Dir(a) * r * 0.95f, new Color(1, 1, 1, 0.6f), 0.8f); }
            }
            if (st.marked)
            {
                var c = new Color(1f, 0.62f, 0.3f);
                Vector2 mp = new Vector2(0, -r - 12f);
                v.DrawColoredPolygon(new[] { mp + new Vector2(0, 6), mp + new Vector2(6, 0), mp + new Vector2(5, -7), mp + new Vector2(0, -3), mp + new Vector2(-5, -7), mp + new Vector2(-6, 0) }, Gd.WithA(Gd.C_PAPER, 0.95f));
                v.DrawLine(mp + new Vector2(-3, -1), mp + new Vector2(-1, 1), new Color(0.85f, 0.2f, 0.3f), 1.5f);
                v.DrawLine(mp + new Vector2(3, -1), mp + new Vector2(1, 1), new Color(0.85f, 0.2f, 0.3f), 1.5f);
                v.DrawArc(Vector2.zero, r + 3f, 0, Gd.TAU, 20, Gd.WithA(c, 0.5f), 1.5f);
            }
            if (st.doomT >= 0f)
            {
                float k = Mathf.Clamp01(st.doomT / 1.1f);
                v.DrawArc(Vector2.zero, r * (1f + k * 1.2f), 0f, Gd.TAU, 24, Gd.WithA(new Color(0.78f, 0.72f, 1f), 0.8f), 2f);
            }
        }
    }
}
