using System.Collections.Generic;
using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>
    /// 大妖（ボス）。Godot 版 boss.gd の移植。5 波ごとに出現し、HP で 3 段階に変化する。
    /// 荒魂（突進）、百目鬼（開眼・閉眼）、八岐大蛇（首が減るごとに怒りの弾幕）。
    /// </summary>
    public class Boss : Enemy
    {
        private static readonly string[] NAMES = { "荒魂", "百目鬼", "八岐大蛇" };
        private static readonly string[] TITLES = { "参道を塞ぐ荒ぶる魂", "百の眼で見張る鬼", "八つの首を持つ大蛇" };

        public int tier = 1;
        public bool isFinal, entering = true;
        public string bossName = "荒魂";
        public override string DisplayName() => bossName;

        private float _atkCd = 1.6f, _burstT, _burstGap = 0.12f, _spiralA, _hoverX;
        private int _burstLeft;
        private string _burstKind = "";
        // 固有ギミック
        private bool _invuln, _eyeOpen = true;
        private float _eyeT;
        private int _dashState;
        private float _dashT;
        private Vector2 _dashDir = Vector2.up;   // 画面の下向き（Godot の DOWN）
        private int _headsAlive = 8, _headsPrev = 8;

        public void SetupBoss(int w, bool endless)
        {
            Setup("boss", w, new Vector2(Gd.W * 0.5f, -110f));
            isBoss = true;
            tier = Mathf.Clamp(Stages.StageOf(w), 1, 3);
            isFinal = Stages.IsFinalWave(w) && !endless;
            bossName = NAMES[Mathf.Min(tier - 1, NAMES.Length - 1)];
            maxHp = 1300f * (1f + (tier - 1) * 1f) * (isFinal ? 4.2f : 1f);
            hp = maxHp;
            radius = isFinal ? 70f : 56f;
            speed = 70f;
            contactDmg = 30f;
            score = 500 * tier;
            xp = 60f + 20f * tier;
            color = Gd.C_BOSS;
            _hoverX = Gd.W * 0.5f;
            entering = true;
            _atkCd = 1.6f; _burstLeft = 0; _burstT = 0f; _burstKind = ""; _spiralA = 0f;
            _invuln = false; _eyeOpen = true; _eyeT = 0f; _dashState = 0; _dashT = 0f; _headsAlive = 8; _headsPrev = 8;
            _spawnIn = 0f;
        }

        public string TitleText() => TITLES[Mathf.Min(tier - 1, TITLES.Length - 1)];

        public int Phase()
        {
            float r = hp / maxHp;
            return r > 0.66f ? 1 : r > 0.33f ? 2 : 3;
        }

        /// <summary>八岐大蛇：残っている首の位置（体の左右に扇状に並ぶ）。</summary>
        public List<Vector2> HeadPositions()
        {
            var outL = new List<Vector2>();
            for (int i = 0; i < 8 && i < _headsAlive; i++)
            {
                float a = Mathf.PI + Mathf.PI * (i + 1) / 9f;
                outL.Add(pos + new Vector2(Mathf.Cos(a) * radius * 2.2f, Mathf.Sin(a) * radius * 1.4f - radius * 0.3f));
            }
            return outL;
        }

        protected override void Behavior(float delta, GameManager g)
        {
            if (entering)
            {
                pos.y = Mathf.MoveTowards(pos.y, 175f, 165f * delta);
                if (Mathf.Abs(pos.y - 175f) < 1f) entering = false;
                return;
            }
            int ph = Phase();
            var pl = P();

            // ---- 荒魂：狙いを定めてから突進し、戻る ----
            if (tier == 1 && !isFinal)
            {
                if (_dashState == 1)
                {
                    _dashT -= delta;
                    if (_dashT <= 0f)
                    {
                        _dashState = 2; _dashT = 1.6f;
                        _dashDir = pl != null ? (pl.pos + new Vector2(0, 40f) - pos).normalized : Vector2.up;
                        if (_dashDir.y < 0.35f) _dashDir = new Vector2(_dashDir.x, 0.35f).normalized;
                        Sfx.Play("hit_storm", -4f, 0.6f);
                        Fx.ShakeAdd(6f);
                    }
                    return;
                }
                if (_dashState == 2)
                {
                    _dashT -= delta;
                    pos += _dashDir * 900f * delta;
                    Fx.Cone(pos, -_dashDir, color, 3, 160f, 0.6f, 6f, 0.3f);
                    Fx.Puff(pos, radius * 0.6f, radius * 1.6f, Gd.WithA(color, 0.6f), 0.2f);
                    if (_dashT <= 0f || pos.y > Gd.H - 30f) _dashState = 3;
                    return;
                }
                if (_dashState == 3)
                {
                    pos.y = Mathf.MoveTowards(pos.y, 175f, 260f * delta);
                    pos.x = Mathf.Lerp(pos.x, Gd.W * 0.5f, Mathf.Clamp01(2f * delta));
                    if (Mathf.Abs(pos.y - 175f) < 2f) { _dashState = 0; _atkCd = 1.2f; }
                    return;
                }
            }

            // ---- 百目鬼：開眼（無防備）と閉眼（無敵・弾幕）を繰り返す ----
            if (tier == 2 && !isFinal)
            {
                _eyeT -= delta;
                if (_eyeT <= 0f)
                {
                    _eyeOpen = !_eyeOpen;
                    _eyeT = _eyeOpen ? 4.5f : 2.6f;
                    _invuln = !_eyeOpen;
                    if (_eyeOpen) { Fx.RingFx(pos, Color.white, radius, radius * 3f, 0.4f, 4f); Sfx.Play("suzu", -6f, 0.9f); g.hud.Small("開眼　いま撃て", new Color(1, 0.9f, 0.6f)); }
                    else { Fx.Burst(pos, color, 14, 200f, 4f, 0.4f, true); Sfx.Play("warn", -14f, 1.4f); g.hud.Small("閉眼　弾を弾き返す", new Color(1, 0.6f, 0.6f)); }
                }
            }

            // ---- 八岐大蛇：首が減るたびに短い硬直と怒りの弾幕 ----
            if (isFinal)
            {
                _headsAlive = Mathf.Max(1, Mathf.CeilToInt(hp / maxHp * 8f));
                if (_headsAlive < _headsPrev)
                {
                    _headsPrev = _headsAlive;
                    Fx.ShakeAdd(10f);
                    Fx.RingFx(pos, Color.white, radius, radius * 4f, 0.5f, 5f);
                    Sfx.Play("taiko", -2f, 0.7f);
                    g.Hitstop(0.25f, 0.1f);
                    g.hud.Small("首を断った　残り " + _headsAlive, new Color(1, 0.8f, 0.6f));
                    _atkCd = 0.4f; _burstKind = "heads"; _burstLeft = 2; _burstGap = 0.35f;
                }
            }

            // ふわふわ移動
            _hoverX = Gd.W * 0.5f + Mathf.Sin(t * (0.45f + 0.16f * ph)) * (Gd.W * 0.30f);
            pos.x = Mathf.Lerp(pos.x, _hoverX, Mathf.Clamp01(2.2f * delta));
            pos.y = 175f + Mathf.Sin(t * 0.9f) * 18f;

            if (_burstLeft > 0)
            {
                _burstT -= delta;
                if (_burstT <= 0f) { _burstT = _burstGap; _burstLeft--; DoBurstShot(ph, g); }
                return;
            }
            _atkCd -= delta * FireMult();
            if (_atkCd <= 0f) ChooseAttack(ph);
        }

        private void ChooseAttack(int ph)
        {
            string[] opts;
            switch (ph)
            {
                case 1: opts = isFinal ? new[] { "radial", "aimed", "spiral" } : new[] { "radial", "aimed", "radial" }; break;
                case 2: opts = isFinal ? new[] { "spiral", "shotgun", "wall", "summon" } : new[] { "spiral", "shotgun", "radial", "summon" }; break;
                default: opts = new[] { "spiral2", "shotgun", "summon", "wall", "spiral2" }; break;
            }
            _burstKind = opts[Random.Range(0, opts.Length)];
            if (tier == 1 && !isFinal && ph >= 2 && Random.value < 0.35f && _dashState == 0)
            {
                _dashState = 1; _dashT = 0.8f;
                Sfx.Play("warn", -10f, 0.8f);
                return;
            }
            if (tier == 2 && !isFinal)
                _burstKind = !_eyeOpen ? new[] { "spiral", "spiral2", "radial" }[Random.Range(0, 3)] : new[] { "aimed", "shotgun", "summon" }[Random.Range(0, 3)];
            if (isFinal && Random.value < 0.45f) _burstKind = "heads";
            _spiralA = Random.value * Gd.TAU;
            switch (_burstKind)
            {
                case "radial": _burstLeft = 3; _burstGap = 0.24f; _atkCd = 1.9f - 0.15f * ph; break;
                case "aimed": _burstLeft = 4; _burstGap = 0.16f; _atkCd = 1.7f; break;
                case "shotgun": _burstLeft = 3; _burstGap = 0.30f; _atkCd = 1.6f; break;
                case "spiral": _burstLeft = 26; _burstGap = 0.055f; _atkCd = 1.7f; break;
                case "spiral2": _burstLeft = 36; _burstGap = 0.048f; _atkCd = 1.4f; break;
                case "summon": _burstLeft = 1; _burstGap = 0.1f; _atkCd = 2.6f; break;
                case "wall": _burstLeft = 2; _burstGap = 0.5f; _atkCd = 1.6f; break;
                case "heads": _burstLeft = 3; _burstGap = 0.4f; _atkCd = 1.6f; break;
            }
            _burstT = 0f;
        }

        private float BossBulletDmg() => (10f + wave * 0.7f) * OutDmgMult();

        private void DoBurstShot(int ph, GameManager g)
        {
            float spd = 200f + 14f * ph + tier * 14f + (isFinal ? 30f : 0f);
            switch (_burstKind)
            {
                case "radial":
                    ShootRadial(12 + ph * 3, spd, Random.value * Gd.TAU);
                    Fx.RingFx(pos, color, radius * 0.6f, radius * 1.7f, 0.25f);
                    break;
                case "aimed": ShootAimed(3, 12f, spd + 60f); break;
                case "shotgun": ShootAimed(7 + ph, 9f, spd + 30f); Fx.ShakeAdd(2f); break;
                case "spiral":
                case "spiral2":
                    {
                        OnFire();
                        int arms = _burstKind == "spiral" ? 2 : 3;
                        for (int a = 0; a < arms; a++) SpawnShot(Gd.Dir(_spiralA + Gd.TAU * a / arms) * spd);
                        _spiralA += _burstKind == "spiral" ? 0.42f : -0.36f;
                        Sfx.Play("eshot", -20f, 1.2f, 0.06f);
                        break;
                    }
                case "summon":
                    {
                        int n = 2 + ph;
                        for (int i = 0; i < n; i++) g.SpawnEnemy("mini", pos + new Vector2(Gd.Rand(-70, 70), Gd.Rand(20, 60)));
                        Sfx.Play("warn", -18f, 1.6f);
                        break;
                    }
                case "heads":
                    {
                        OnFire();
                        var pl = P();
                        foreach (var hp0 in HeadPositions())
                        {
                            float a = (pl != null ? Gd.Angle(pl.pos - hp0) : Mathf.PI * 0.5f) + Gd.Rand(-0.15f, 0.15f);
                            g.SpawnEnemyBullet(hp0, Gd.Dir(a) * (spd + 40f), BossBulletDmg(), 6f, Gd.C_EBULLET, 0f, bossName + "の吐息");
                        }
                        Sfx.Play("eshot", -10f, 0.6f, 0.05f);
                        break;
                    }
                case "wall":
                    {
                        OnFire();
                        int gap = Random.Range(1, 7);
                        for (int i = 0; i < 8; i++)
                        {
                            if (Mathf.Abs(i - gap) <= 1) continue;
                            float x = 45f + i * (Gd.W - 90f) / 7f;
                            g.SpawnEnemyBullet(new Vector2(x, pos.y + 40f), new Vector2(0, spd * 0.85f), BossBulletDmg(), 6f, Gd.C_EBULLET, 0f, bossName + "の弾幕");
                        }
                        Sfx.Play("eshot", -12f, 0.7f, 0.05f);
                        break;
                    }
            }
        }

        public override bool TakeDamage(float d, bool crit, Vector2 at, bool quiet = false)
        {
            if (_invuln)
            {
                if (!quiet) { Fx.Sparks(at, Vector2.down, Color.white, 3, 200f); Fx.Number(at + new Vector2(0, -radius), "無効", new Color(1, 1, 1, 0.7f), 11f); }
                return false;
            }
            int before = Phase();
            bool dead = base.TakeDamage(d, crit, at, quiet);
            if (!dead && hp > 0f && Phase() != before)
            {
                Fx.RingFx(pos, Color.white, radius, radius * 5f, 0.5f);
                Fx.ShakeAdd(9f);
                Sfx.Play("taiko", -4f, 0.8f);
                Sfx.Play("warn", -10f, 1f);
                GameManager.I.Hitstop(0.2f, 0.1f);
                _burstLeft = 0; _atkCd = 0.7f;
            }
            return dead;
        }

        public override void Die()
        {
            if (!Active) return;
            Sfx.Play("boom", -2f);
            Sfx.Play("taiko", 0f, 0.6f);
            for (int i = 0; i < 8; i++)
            {
                var off = new Vector2(Gd.Rand(-50, 50), Gd.Rand(-50, 50));
                Fx.Burst(pos + off, i % 2 == 0 ? color : new Color(1, 0.85f, 0.4f), 18, 380f, 7f, 0.9f);
            }
            Fx.RingFx(pos, Color.white, 10f, 420f, 0.8f);
            Fx.Flash(new Color(1, 1, 1, 0.5f), 0.3f);
            Fx.ShakeAdd(24f);
            Active = false;
            GameManager.I.OnEnemyKilled(this);
            gameObject.SetActive(false);
        }

        // ---------- 描画 ----------

        protected override void DrawBodyOverride(Vec v, Color c)
        {
            int ph = Phase();
            float r = radius;
            if (st.frozen > 0f) c = Color.Lerp(c, new Color(0.75f, 0.92f, 1f), 0.6f);
            v.Glow(Vector2.zero, r * 2.8f, Gd.WithA(color, 0.45f));

            // 回転する外殻（数珠のように連なる珠）
            for (int ringI = 0; ringI < 2; ringI++)
            {
                float rr = r * (1.35f + 0.28f * ringI);
                float dir = ringI == 0 ? 1f : -1f;
                int seg = 8 + ringI * 4;
                for (int i = 0; i < seg; i++) { float a0 = t * (0.5f + 0.3f * ph) * dir + Gd.TAU * i / seg; v.DrawCircle(Gd.Dir(a0) * rr, 5f - ringI, Gd.WithA(c, 0.6f)); }
            }
            // 八岐大蛇：首
            if (isFinal)
            {
                var dark = Gd.Darkened(c, 0.3f);
                foreach (var hp0 in HeadPositions())
                {
                    Vector2 lp = hp0 - pos;
                    Vector2 mid = lp * 0.5f + new Vector2(0, -20f + Mathf.Sin(t * 2f + lp.x * 0.02f) * 6f);
                    v.DrawLine(Vector2.zero, mid, dark, 10f);
                    v.DrawLine(mid, lp, dark, 8f);
                    v.DrawCircle(lp, 14f, c);
                    v.DrawCircle(lp + new Vector2(-4, -3), 3f, new Color(1, 0.95f, 0.6f));
                    v.DrawCircle(lp + new Vector2(4, -3), 3f, new Color(1, 0.95f, 0.6f));
                    v.DrawColoredPolygon(new[] { lp + new Vector2(-5, 6), lp + new Vector2(5, 6), lp + new Vector2(0, 14) }, new Color(1, 0.95f, 0.85f));
                }
            }
            // 百目鬼：閉眼中は鈍い色、開眼中は大きな眼
            if (tier == 2 && !isFinal)
            {
                if (_invuln)
                {
                    c = Gd.Darkened(c, 0.45f);
                    v.DrawArc(Vector2.zero, r * 1.15f, 0, Gd.TAU, 40, new Color(1, 1, 1, 0.35f + 0.15f * Mathf.Sin(t * 10f)), 3f);
                }
                else
                {
                    v.DrawCircle(new Vector2(0, -r * 0.1f), r * 0.5f, new Color(1, 1, 0.95f));
                    v.DrawCircle(new Vector2(0, -r * 0.1f), r * 0.26f, new Color(0.9f, 0.2f, 0.3f));
                    v.DrawCircle(new Vector2(0, -r * 0.1f), r * 0.12f, Gd.C_INK);
                }
            }
            // 荒魂：狙いの線
            if (tier == 1 && !isFinal && _dashState == 1)
            {
                var pl = P();
                if (pl != null) v.DrawLine(Vector2.zero, (pl.pos - pos).normalized * 1200f, new Color(1, 0.4f, 0.5f, 0.25f + 0.2f * Mathf.Sin(t * 30f)), 3f);
            }
            // 本体：鬼の面
            var hex = new Vector2[6];
            for (int i = 0; i < 6; i++) hex[i] = Gd.Dir(Gd.TAU * i / 6f + Mathf.PI / 6f) * r;
            v.DrawColoredPolygon(hex, Gd.Darkened(c, 0.35f));
            for (int i = 0; i < 6; i++) v.DrawLine(hex[i], hex[(i + 1) % 6], c, 3f);
            // 角
            foreach (float sgn in new[] { -1f, 1f })
                v.DrawColoredPolygon(new[] { new Vector2(sgn * r * 0.35f, -r * 0.7f), new Vector2(sgn * r * 0.55f, -r * 1.35f), new Vector2(sgn * r * 0.7f, -r * 0.6f) }, new Color(1, 0.95f, 0.85f));
            // 目
            float pulse = 0.75f + 0.25f * Mathf.Sin(t * (4f + 2f * ph));
            foreach (float sgn in new[] { -1f, 1f })
            {
                var ep = new Vector2(sgn * r * 0.32f, -r * 0.1f);
                v.DrawCircle(ep, r * 0.2f * pulse, new Color(1, 0.95f, 0.7f, 0.95f));
                v.DrawCircle(ep, r * 0.09f, Gd.C_INK);
            }
            // 口（フェーズで牙が増える）
            v.DrawArc(new Vector2(0, r * 0.3f), r * 0.4f, 0.3f, Mathf.PI - 0.3f, 12, Gd.C_INK, 3f);
            for (int i = 0; i < ph * 2; i++)
            {
                float x = (i - (ph * 2 - 1) * 0.5f) * r * 0.16f;
                v.DrawColoredPolygon(new[] { new Vector2(x - 3, r * 0.45f), new Vector2(x + 3, r * 0.45f), new Vector2(x, r * 0.7f) }, new Color(1, 0.95f, 0.85f));
            }
        }
    }
}
