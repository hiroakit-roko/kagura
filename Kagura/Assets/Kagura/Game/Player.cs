using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using Kagura.Core;

namespace Kagura.Game
{
    /// <summary>
    /// 自機（魔法少女）。Godot 版 player.gd の移植。座標は Godot px。
    ///   - 基本の弾（巫矢）は常に自動で撃つ
    ///   - 迎えた神ごとに Weapon（神器）が付く。主神も副神も同じ威力（差は詠唱・神招きだけ）
    ///   - 神ごとに神格レベル（kamiLv）があり、神器のダメージで神徳（kamiXp）が溜まる
    ///   - Z/J：詠唱  X/K：神招き  Space／フリック：疾走（無敵）
    /// </summary>
    public class Player : MonoBehaviour
    {
        public const int HFRAMES = 10;
        public const float SPR_SCALE = 0.5f;
        public const float VEIL_R = 150f;
        public const float TOUCH_SENS = 0.72f;

        // ---- 素の値 ----
        public float baseSpeed = 330f, fireRate = 5f, bulletSpeed = 900f, critBase = 0.05f, critMultBase = 2f, xpMult = 1.15f, magnet = 170f, dashCd = 2.2f;

        // ---- 神と恩恵 ----
        public readonly Dictionary<string, (int rar, int lv)> boons = new Dictionary<string, (int rar, int lv)>();
        public readonly List<string> gods = new List<string>();
        public readonly Dictionary<string, int> kamiLv = new Dictionary<string, int>();
        public readonly Dictionary<string, float> kamiXp = new Dictionary<string, float>();
        public readonly Dictionary<string, Weapon> weapons = new Dictionary<string, Weapon>();
        public readonly Dictionary<string, float> kamiDmg = new Dictionary<string, float>();
        public readonly List<string> relics = new List<string>();
        public string familiarId = "";
        public Familiar familiar, familiar2;
        public string lastHitBy = "";
        private bool _revived;
        private readonly List<Drone> _drones = new List<Drone>();

        // ---- 状態 ----
        public Vector2 pos;
        public float hp = 100f, maxHp = 100f;
        public int level = 1;
        public float xp, xpNext = 50f;
        public int pendingLevels;
        public bool alive = true;
        public float radius = 7f;
        public int castCharges, castMax = 3;
        public float iframe, t;
        public int shield;
        public float shieldT, regenT, dashT, dashCool;
        public Vector2 dashDir = Vector2.up, moveDir;
        public bool focus;
        public float callGauge, callT, callTick, callPower = 1f;
        public string callKind = "";
        public float hasteT, dashMult = 1f, dashBuffT, fanHealCd;
        // 自動プレイ用
        public Vector2 autoDir; public bool autoCast, autoCall, godMode; public float dmgMult = 1f;
        private float _fogT, _contactCd, _ghostT, _miracleCd, _fireCd;
        private bool _dashReadyPing = true;
        private readonly HashSet<Enemy> _dashHit = new HashSet<Enemy>();

        // ---- 見た目・入力 ----
        private float _anim, _lean;
        private SpriteRenderer _spr;
        private Sprite[] _frames;
        private Vec _vec;
        private WorldText _dashText;
        private Vector2 _lastTouch, _lastMouse;
        private bool _touching, _mouseDown;
        private readonly List<(SpriteRenderer sr, float t)> _ghosts = new List<(SpriteRenderer, float)>();

        private void Awake()
        {
            var tex = Resources.Load<Texture2D>("Art/player_walk");
            _frames = new Sprite[HFRAMES];
            if (tex != null)
            {
                float fw = tex.width / (float)HFRAMES;
                for (int i = 0; i < HFRAMES; i++)
                    _frames[i] = Sprite.Create(tex, new Rect(fw * i, 0, fw, tex.height), new Vector2(0.5f, 0.5f), 1f);
            }
            var sgo = new GameObject("spr");
            sgo.transform.SetParent(transform, false);
            sgo.transform.localScale = Vector3.one * SPR_SCALE;
            sgo.transform.localPosition = new Vector3(0, -9f, 0);
            _spr = sgo.AddComponent<SpriteRenderer>();
            _spr.sprite = _frames[0];
            _spr.sortingOrder = Gd.ZPlayer + 1;
            _vec = Vec.Create(transform, "vec", Gd.ZPlayer);
        }

        public void Reset()
        {
            alive = true; hp = maxHp = 100f; iframe = 0f; t = 0f;
            level = 1; xp = 0f; xpNext = 50f; pendingLevels = 0;   // Godot 版の初期値
            foreach (var w in weapons.Values) w.Destroy();
            weapons.Clear();
            gods.Clear(); kamiLv.Clear(); kamiXp.Clear(); kamiDmg.Clear(); boons.Clear(); relics.Clear();
            if (familiar != null) Destroy(familiar.gameObject); familiar = null;
            if (familiar2 != null) Destroy(familiar2.gameObject); familiar2 = null;
            foreach (var d in _drones) if (d != null) Destroy(d.gameObject); _drones.Clear();
            familiarId = ""; lastHitBy = ""; _revived = false;
            castCharges = 0; castMax = 3; shield = 0; shieldT = 0f; regenT = 0f; dashT = 0f; dashCool = 0f;
            callGauge = 0f; callT = 0f; callKind = ""; callPower = 1f; hasteT = 0f; dashBuffT = 0f; fanHealCd = 0f;
            _contactCd = 0f; _miracleCd = 0f; _fireCd = 0f; _dashReadyPing = true; radius = 7f;
            pos = new Vector2(Gd.W * 0.5f, Gd.H - 170f);
            _spr.transform.localScale = Vector3.one * SPR_SCALE;
            _spr.enabled = true;
            gameObject.SetActive(true);
            Apply();
        }

        public static float XpNeed(int lv) => 36f + lv * 20f + Mathf.Pow(lv, 1.5f) * 2.5f;

        // ---------- 神・恩恵の参照 ----------

        public bool Has(string id) => boons.ContainsKey(id);
        public float Val(string id)
        {
            if (!boons.TryGetValue(id, out var b)) return 0f;
            var def = Data.Boon(id);
            return def == null ? 0f : (float)Boons.Value(def, b.rar, b.lv);
        }
        public string MainGod() => gods.Count > 0 ? gods[0] : "";
        public bool IsMain(string id) => MainGod() == id;
        public int KamiLv(string id) => kamiLv.TryGetValue(id, out var v) ? v : 1;
        public float KamiXp(string id) => kamiXp.TryGetValue(id, out var v) ? v : 0f;
        public Color KamiColor(string id) => Data.KamiColor(id);
        /// <summary>神器の威力倍率：神格レベルで伸びる（主神・副神で差はない）。</summary>
        public float KamiPower(string id) => Boons.KamiPower(KamiLv(id), Boons.GrowthOf(id)) * (Has("curse_fire") ? 1.3f : 1f);
        public bool HasRelic(string id) => relics.Contains(id);
        public float HitScale() => Mathf.Clamp(1f - Val("saru_u9") * 0.01f - (HasRelic("r_small") ? 0.25f : 0f), 0.4f, 1f);
        public float BaseDamage() => 10f * (1f + (level - 1) * 0.03f) * (HasRelic("r_dmg") ? 1.10f : 1f) * dmgMult;

        public void SetFamiliar(string id)
        {
            familiarId = id;
            if (familiar != null) Destroy(familiar.gameObject);
            familiar = Familiar.Create(GameManager.I.world, id, this, false);
        }

        /// <summary>神を迎える：神器がすぐに付く。</summary>
        public void AddGod(string id)
        {
            if (gods.Contains(id) || gods.Count >= BoonsLogic.MAX_KAMI) return;
            gods.Add(id);
            kamiLv[id] = 1;
            kamiXp[id] = 0f;
            weapons[id] = new Weapon(id, this, GameManager.I.world);
            var col = KamiColor(id);
            Fx.RingFx(pos, col, 10f, 160f, 0.6f, 5f);
            Fx.Rays(pos, col, 14, 20f, 160f, 0.5f);
            OnBoonsChanged();
        }

        public void AddKamiXp(string id, float amount)
        {
            if (!kamiLv.ContainsKey(id)) return;
            int lv = kamiLv[id];
            kamiDmg[id] = (kamiDmg.TryGetValue(id, out var dd) ? dd : 0f) + amount;
            if (lv >= 10) return;
            kamiXp[id] = KamiXp(id) + amount * (Has("curse_haste") ? 1.5f : 1f);
            float need = Boons.KamiXpNeed(lv);
            if (kamiXp[id] >= need) { kamiXp[id] -= need; KamiLevelUp(id); }
        }

        public void KamiLevelUp(string id)
        {
            kamiLv[id] = KamiLv(id) + 1;
            var k = Data.KamiOf(id);
            int lv = kamiLv[id];
            var col = KamiColor(id);
            Sfx.Play("suzu", -8f, 1.1f);
            Fx.RingFx(pos, col, 20f, 140f, 0.5f, 4f);
            Fx.Petals(pos, col, 14, 200f);
            int g = Mathf.RoundToInt(Boons.GrowthOf(id) * 100f);
            string note = "威力 +" + g + "%";
            if (lv % 3 == 0 || lv % 4 == 0 || lv % 5 == 0) note = "威力 +" + g + "%　弾数や大きさが増えた";
            if (k != null) GameManager.I.hud.Banner(k.name + "　神格 " + lv, k.weapon + "　" + note, col);
            OnBoonsChanged();
        }

        /// <summary>契約の代償：迎えた神ごとの軽いペナルティ。</summary>
        public float CostMult(string kind)
        {
            float m = 1f;
            switch (kind)
            {
                case "hp": if (gods.Contains("ama")) m *= 0.9f; if (gods.Contains("uzume")) m *= 0.9f; break;
                case "taken": if (gods.Contains("susa")) m *= 1.08f; if (gods.Contains("iza")) m *= 1.08f; break;
                case "orb": if (gods.Contains("take")) m *= 0.7f; break;
                case "speed": if (gods.Contains("tsuki")) m *= 0.94f; break;
                case "magnet": if (gods.Contains("inari")) m *= 0.8f; break;
                case "gauge": if (gods.Contains("suku")) m *= 0.85f; break;
                case "dash_cd": if (gods.Contains("saru")) m *= 1.1f; break;
            }
            return m;
        }

        public void OnBoonsChanged()
        {
            float baseHp = (100f + (level - 1) * 3f) * CostMult("hp");
            float newMax = baseHp + (Has("uzume_u5") ? Val("uzume_u5") : 0f) - (Has("curse_haste") ? 20f : 0f) - (Has("curse_wind") ? 25f : 0f) + (HasRelic("r_hp") ? 30f : 0f);
            radius = 7f * HitScale();
            _spr.transform.localScale = Vector3.one * SPR_SCALE * HitScale();
            newMax = Mathf.Max(newMax, 30f);
            float diff = newMax - maxHp;
            maxHp = newMax;
            if (diff > 0f) hp = Mathf.Min(newMax, hp + diff);
            hp = Mathf.Min(hp, newMax);
            castMax = 3 + (HasRelic("r_orb") ? 2 : 0);
            if (HasRelic("r_fam_twin") && familiarId != "" && familiar2 == null)
                familiar2 = Familiar.Create(GameManager.I.world, familiarId, this, true);
            int want = Has("inari_u4") ? Mathf.RoundToInt(Val("inari_u4")) : 0;
            if (want != _drones.Count)
            {
                foreach (var d in _drones) if (d != null) Destroy(d.gameObject);
                _drones.Clear();
                for (int i = 0; i < want; i++) _drones.Add(Drone.Create(GameManager.I.world, this, i, want));
            }
            if (Has("ama_u5") && shield == 0) shieldT = Mathf.Min(shieldT, 2f);
            var g = GameManager.I;
            if (g != null && g.stars != null && gods.Count > 0) g.stars.tint = Gd.Darkened(KamiColor(MainGod()), 0.35f);
        }

        // ---------- 毎フレーム ----------

        public void Tick(float dt)
        {
            TickGhosts(dt);
            if (!alive) return;
            var g = GameManager.I;
            t += dt;
            iframe = Mathf.Max(0f, iframe - dt);
            dashCool = Mathf.Max(0f, dashCool - dt);
            _contactCd = Mathf.Max(0f, _contactCd - dt);
            _miracleCd = Mathf.Max(0f, _miracleCd - dt);
            hasteT = Mathf.Max(0f, hasteT - dt);
            if (dashCool <= 0f && !_dashReadyPing)
            {
                _dashReadyPing = true;
                Fx.RingFx(pos + new Vector2(0, 30), Color.white, 6f, 30f, 0.25f, 2f);
                Sfx.Play("suzu", -24f, 1.8f);
            }
            Move(dt, g);
            Animate(dt);
            Weapons(dt, g);
            CallTick(dt, g);
            Upkeep(dt);
            Contact(g);
            Graze(g);
            if (familiar != null) familiar.Tick(dt);
            if (familiar2 != null) familiar2.Tick(dt);
            foreach (var d in _drones) d.Tick(dt);
            Apply();
            Draw();
        }

        public int grazes;

        /// <summary>かすり：敵弾のすれすれを抜けると神招きゲージが少し溜まる（Godot 版 _graze）。</summary>
        private void Graze(GameManager g)
        {
            foreach (var b in g.EnemyBullets())
            {
                if (!b.Active || b.grazed) continue;
                float d = Vector2.Distance(b.pos, pos);
                if (d < 30f && d > radius + b.radius)
                {
                    b.grazed = true;
                    grazes++;
                    AddCallGauge(0.004f);
                    Fx.Sparks(b.pos, Vector2.down, Color.white, 2, 200f);
                    Fx.Number(pos + new Vector2(0, -40), "かすり", new Color(1, 1, 1, 0.6f), 9f);
                }
            }
        }

        // ---------- 移動 ----------

        public float MoveSpeed()
        {
            float m = 1f + Val("saru_u3") * 0.01f;
            if (gods.Contains("saru")) m += 0.10f;
            if (HasRelic("r_speed")) m += 0.10f;
            if (Has("curse_wind")) m += 0.20f;
            if (familiarId == "karasu") m += 0.06f;
            if (hasteT > 0f) m += 0.35f;
            return baseSpeed * m * CostMult("speed");
        }

        public float DashCdTime() => dashCd * (1f - Val("saru_u4") * 0.01f) * (1f - Val("saru_leg") * 0.01f) * CostMult("dash_cd") * (HasRelic("r_dash") ? 0.75f : 1f) * (Has("curse_wind") ? 0.7f : 1f);

        private Vector2 InputDir()
        {
            if (autoDir != Vector2.zero) return autoDir.normalized;
            var kb = Keyboard.current;
            if (kb == null) return Vector2.zero;
            var d = Vector2.zero;
            if (kb.aKey.isPressed || kb.leftArrowKey.isPressed) d.x -= 1f;
            if (kb.dKey.isPressed || kb.rightArrowKey.isPressed) d.x += 1f;
            if (kb.wKey.isPressed || kb.upArrowKey.isPressed) d.y -= 1f;
            if (kb.sKey.isPressed || kb.downArrowKey.isPressed) d.y += 1f;
            return d.normalized;
        }

        /// <summary>指／マウスのドラッグ量（px、Godot 座標系）。</summary>
        private Vector2 ConsumeTouchMove(GameManager g)
        {
            float scale = Gd.W / Mathf.Max(1, Screen.width);
            var touchUi = g.touchUi;
            var ts = Touchscreen.current;
            Vector2 mv = Vector2.zero;
            if (ts != null && ts.primaryTouch.press.isPressed && (touchUi == null || !touchUi.IsButtonTouch(ts.primaryTouch.position.ReadValue())))
            {
                Vector2 p = ts.primaryTouch.position.ReadValue();
                if (_touching) { Vector2 d = (p - _lastTouch) * scale; mv = new Vector2(d.x, -d.y); }
                _lastTouch = p; _touching = true;
                return mv;
            }
            _touching = false;
            var ms = Mouse.current;
            if (ms != null && ms.leftButton.isPressed && (ts == null || !ts.primaryTouch.press.isPressed))
            {
                Vector2 p = ms.position.ReadValue();
                if (_mouseDown && (touchUi == null || !touchUi.IsButtonTouch(p))) { Vector2 d = (p - _lastMouse) * scale; mv = new Vector2(d.x, -d.y); }
                _lastMouse = p; _mouseDown = true;
                return mv;
            }
            _mouseDown = false;
            return Vector2.zero;
        }

        private void Move(float dt, GameManager g)
        {
            var kb = Keyboard.current;
            focus = kb != null && kb.shiftKey.isPressed;
            Vector2 dir = InputDir();
            Vector2 touchMove = ConsumeTouchMove(g);
            if (dir == Vector2.zero && touchMove.magnitude > 0.01f) dir = touchMove.normalized;
            moveDir = dir;

            if (dashT > 0f)
            {
                dashT -= dt;
                iframe = Mathf.Max(iframe, 0.05f);
                pos += dashDir * MoveSpeed() * 2.6f * dashMult * dt;
                if (Has("saru_leg"))
                    foreach (var e in g.EnemyList().ToArray())
                    {
                        if (!e.Active || Vector2.Distance(e.pos, pos) > radius + 26f || _dashHit.Contains(e)) continue;
                        _dashHit.Add(e);
                        Combat.Hit(e, BaseDamage() * 2.5f * KamiPower("saru"), e.pos, new HitOpts { tag = "wind", kami = "saru", dir = dashDir });
                        e.Stagger(1f);
                    }
                _ghostT -= dt;
                if (_ghostT <= 0f)
                {
                    _ghostT = 0.025f;
                    var gc = MainGod() != "" ? KamiColor(MainGod()) : Gd.C_PLAYER;
                    SpawnGhost(gc);
                    Fx.Sparks(pos, -dashDir, Color.white, 2, 220f);
                }
                if (dashT <= 0f) iframe = Mathf.Max(iframe, 0.18f);
            }
            else
            {
                bool wantDash = kb != null && kb.spaceKey.wasPressedThisFrame;
                var tu = g.touchUi;
                if (tu != null)
                {
                    var flick = tu.TakeFlick();
                    if (flick != Vector2.zero) { wantDash = true; dir = flick.normalized; }
                }
                if (wantDash && dashCool <= 0f && dir != Vector2.zero) StartDash(dir, g);
                if (touchMove != Vector2.zero)
                {
                    float sens = TOUCH_SENS * MoveSpeed() / Mathf.Max(baseSpeed, 1f);
                    float maxlen = MoveSpeed() * 3.6f * dt;
                    pos += Vector2.ClampMagnitude(touchMove * sens, maxlen);
                }
                else pos += dir * MoveSpeed() * (focus ? 0.42f : 1f) * dt;
            }
            pos.x = Mathf.Clamp(pos.x, 30f, Gd.W - 30f);
            pos.y = Mathf.Clamp(pos.y, 80f, Gd.H - 50f);
        }

        private void StartDash(Vector2 dir, GameManager g)
        {
            dashT = 0.18f;
            dashCool = DashCdTime();
            _dashReadyPing = false;
            dashDir = dir;
            var col = MainGod() != "" ? KamiColor(MainGod()) : Gd.C_PLAYER;
            Fx.RingFx(pos, Color.white, 8f, 70f, 0.25f, 4f);
            Fx.RingFx(pos, col, 6f, 110f, 0.35f, 3f);
            Fx.SlashFx(pos, Gd.Angle(dir), 30f, Color.white, 1.6f, 0.18f, 6f);
            Fx.Burst(pos, col, 10, 200f, 3f, 0.3f, true);
            Fx.Number(pos + new Vector2(0, -50), "無敵", new Color(1, 1, 1, 0.9f), 13f);
            Sfx.Play("dash", -4f, Gd.Rand(0.95f, 1.1f));
            Sfx.Play("suzu", -18f, 1.5f);
            g.Hitstop(0.03f, 0.3f);
            dashBuffT = 3f;
            _dashHit.Clear();
            if (Has("saru_u8"))
            {
                int n = Mathf.RoundToInt(Val("saru_u8"));
                float d = BaseDamage() * 0.8f * KamiPower("saru");
                for (int i = 0; i < n; i++)
                {
                    float a = Gd.TAU * i / n + Gd.Angle(dir);
                    var b = g.SpawnPlayerBullet(pos + Gd.Dir(a) * 14f, Gd.Dir(a) * 820f, d, KamiColor("saru"), 4.5f, 11);
                    b.kami = "saru"; b.tag = "wind"; b.critChance = CritChance(); b.pierce = 1;
                }
            }
        }

        // ---------- 残像 ----------

        private void SpawnGhost(Color col)
        {
            var go = new GameObject("ghost");
            go.transform.SetParent(GameManager.I.world, false);
            go.transform.position = _spr.transform.position;
            go.transform.rotation = _spr.transform.rotation;
            go.transform.localScale = _spr.transform.lossyScale;
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = _spr.sprite; sr.sortingOrder = Gd.ZPlayer - 1;
            sr.color = new Color(col.r, col.g, col.b, 0.35f);
            _ghosts.Add((sr, 0.25f));
        }

        private void TickGhosts(float dt)
        {
            for (int i = _ghosts.Count - 1; i >= 0; i--)
            {
                var (sr, life) = _ghosts[i];
                life -= dt;
                if (life <= 0f || sr == null) { if (sr != null) Destroy(sr.gameObject); _ghosts.RemoveAt(i); continue; }
                var c = sr.color; c.a = 0.35f * (life / 0.25f); sr.color = c;
                _ghosts[i] = (sr, life);
            }
        }

        // ---------- アニメーション ----------

        private void Animate(float dt)
        {
            bool moving = moveDir.magnitude > 0.1f;
            float fps = moving ? 10f : 5.5f;
            if (focus) fps *= 0.7f;
            _anim += dt * fps;
            _spr.sprite = _frames[(int)_anim % HFRAMES];
            _lean = Mathf.Lerp(_lean, moveDir.x * 0.13f, Mathf.Clamp01(9f * dt));
            _spr.transform.localRotation = Quaternion.Euler(0, 0, -_lean * Mathf.Rad2Deg);
            _spr.transform.localPosition = new Vector3(0, -(9f + Mathf.Sin(_anim * Mathf.PI) * 1.2f), 0);
            if (dashT > 0f) _spr.color = new Color(1.6f, 1.5f, 1.9f, 0.9f);
            else if (iframe > 0f) _spr.color = new Color(1.2f, 1.2f, 1.4f, 0.55f + 0.45f * (0.5f + 0.5f * Mathf.Sin(t * 40f)));
            else _spr.color = Color.white;
        }

        // ---------- 武装 ----------

        public float CritChance() => Mathf.Min(critBase + Val("inari_u3") * 0.01f + (Has("curse_edge") ? 0.15f : 0f) + (HasRelic("r_crit") ? 0.08f : 0f), 0.95f);
        public float CritMult() => critMultBase + Val("inari_u5") * 0.01f + Val("duo_tsuki_inari") * 0.01f;
        public float FireRateMult() => 1f + (hasteT > 0f ? 0.4f : 0f);

        private void Weapons(float dt, GameManager g)
        {
            _fireCd -= dt;
            if (_fireCd <= 0f) { _fireCd = 1f / (fireRate * FireRateMult()); FireMain(g); }
            foreach (var w in weapons.Values) w.Tick(dt);
            var kb = Keyboard.current;
            var tu = g.touchUi;
            bool ac = autoCast, al = autoCall; autoCast = false; autoCall = false;
            if (ac || (kb != null && (kb.zKey.wasPressedThisFrame || kb.jKey.wasPressedThisFrame)) || (tu != null && tu.Take("cast"))) TryCast(g);
            if (al || (kb != null && (kb.xKey.wasPressedThisFrame || kb.kKey.wasPressedThisFrame)) || (tu != null && tu.Take("call"))) TryCall(g);
        }

        /// <summary>詠唱の札を拾った：1 枚増える（最大 castMax）。</summary>
        public void PickOrb()
        {
            int before = castCharges;
            castCharges = Mathf.Min(castCharges + 1, castMax);
            var col = MainGod() != "" ? KamiColor(MainGod()) : Color.white;
            Fx.RingFx(pos, col, 8f, 50f, 0.3f, 3f);
            Sfx.Play("cast", -14f, 1.5f);
            if (castCharges > before) Fx.Number(pos + new Vector2(0, -44), "詠唱 ×" + castCharges, col, 11f);
        }

        private void FireMain(GameManager g)
        {
            var nose = pos + new Vector2(0, -34f);
            var col = MainGod() != "" ? Color.Lerp(KamiColor(MainGod()), Color.white, 0.4f) : Gd.C_PBULLET;
            float spread = Gd.Rand(-2f, 2f) * (focus ? 0.4f : 1f) * Mathf.Deg2Rad;
            var b = g.SpawnPlayerBullet(nose, Gd.Dir(-Mathf.PI * 0.5f + spread) * bulletSpeed, BaseDamage(), col, 4.5f, 0);
            if (g.diag && Time.frameCount % 60 == 0) Debug.Log($"[diag] fire nose={nose} b.pos={b.pos} b.Active={b.Active} dmg={b.damage}");
            b.trailLen = 20f; b.kami = ""; b.tag = "attack"; b.critChance = CritChance();
            Fx.Cone(nose, Vector2.up, col, 2, 90f, 0.4f, 2f, 0.12f);
            Sfx.Play("shoot", -22f, Gd.Rand(0.95f, 1.1f), 0.035f);
        }

        public Bullet SpawnFoxfire(Vector2 from, Enemy target, float dmg, string tag = "foxfire")
        {
            float quick = 1f + Val("inari_u9") * 0.01f;
            Vector2 dir = target != null ? (target.pos - from).normalized : Gd.Dir(-Mathf.PI * 0.5f + Gd.Rand(-0.6f, 0.6f));
            var b = GameManager.I.SpawnPlayerBullet(from, dir * 520f * quick, dmg, KamiColor("inari"), 6f, 3);
            b.homing = 7f * quick; b.kami = "inari"; b.tag = tag; b.critChance = CritChance(); b.target = target;
            if (Has("duo_ama_inari")) b.pierce = 1;
            Sfx.Play("fox", -20f, Gd.Rand(0.9f, 1.2f), 0.06f);
            return b;
        }

        // ---------- 詠唱（主神の技） ----------

        private Bullet CastBullet(GameManager g, string kami, int shape, float r, Vector2 from, Vector2 vel, float dmg)
        {
            var b = g.SpawnPlayerBullet(from, vel, dmg, KamiColor(kami), r, shape);
            b.kami = kami; b.tag = "cast"; b.critChance = CritChance();
            return b;
        }

        private void TryCast(GameManager g)
        {
            if (castCharges <= 0 || MainGod() == "") return;
            castCharges--;
            string kami = MainGod();
            var col = KamiColor(kami);
            float dmg = BaseDamage() * 8f * Boons.KamiPower(KamiLv(kami));
            var from = pos + new Vector2(0, -30f);
            var k = Data.KamiOf(kami);
            Fx.RingFx(from, col, 8f, 90f, 0.3f, 4f);
            Fx.RingFx(from, Color.white, 4f, 50f, 0.2f, 2f);
            Fx.Rays(from, col, 12, 10f, 70f, 0.3f);
            Fx.Puff(from, 10f, 70f, Gd.WithA(col, 0.9f), 0.35f);
            Fx.Flash(Gd.WithA(col, 0.18f), 0.18f);
            Fx.ShakeAdd(4f);
            g.Hitstop(0.06f, 0.1f);
            Sfx.Play("cast", -6f, Gd.Rand(0.95f, 1.05f));
            Sfx.Play("suzu", -14f, 1.3f);
            if (k != null) g.hud.Small(k.cast, col);
            switch (kami)
            {
                case "ama": { var b = CastBullet(g, kami, 5, 58f, from, new Vector2(0, -120f), dmg); b.reflect = true; b.pierce = 999; b.life = 3.6f; break; }
                case "susa": { var b = CastBullet(g, kami, 6, 36f, from, new Vector2(0, -190f), dmg); b.mode = "vortex"; b.pierce = 999; b.kb = 760f; b.life = 2.6f; break; }
                case "take":
                    {
                        var used = new HashSet<Enemy>();
                        for (int i = 0; i < 3; i++)
                        {
                            var tg = Combat.NearestEnemy(pos, 900f, null, used);
                            if (tg == null) break;
                            used.Add(tg);
                            Combat.Lightning(tg, dmg * 0.6f, new Vector2(tg.pos.x + Gd.Rand(-40, 40), -30f), 0);
                        }
                        var b = CastBullet(g, kami, 2, 14f, from, new Vector2(0, -420f), dmg); b.mode = "cloud"; b.zoneDmg = dmg * 0.7f; b.zoneLife = 4.5f;
                        break;
                    }
                case "tsuki": { var b = CastBullet(g, kami, 2, 16f, from, new Vector2(0, -520f), dmg * 0.6f); b.pierce = 3; b.doom = dmg * 2.4f; break; }
                case "uzume": { Fx.Petals(from, col, 24, 260f); var b = CastBullet(g, kami, 2, 15f, from, new Vector2(0, -520f), dmg); b.charmChance = 1f; b.pierce = 5; break; }
                case "inari":
                    {
                        var target = Combat.NearestEnemy(pos, 900f);
                        for (int i = 0; i < 9; i++) SpawnFoxfire(from + new Vector2((i - 4f) * 12f, 0), target, dmg * 0.45f, "cast");
                        break;
                    }
                case "suku":
                    {
                        Heal(6f, true);
                        var b = CastBullet(g, kami, 9, 13f, from, new Vector2(0, -520f), dmg * 0.6f);
                        b.zoneKind = "fog"; b.zoneR = 135f * (1f + Val("suku_u1") * 0.01f); b.zoneLife = 6f * (1f + Val("suku_u2") * 0.01f); b.life = 0.55f;
                        break;
                    }
                case "iza":
                    {
                        var b = CastBullet(g, kami, 2, 14f, from, new Vector2(0, -520f), dmg * 0.6f);
                        b.zoneKind = "frost"; b.zoneR = 130f; b.zoneLife = 5f; b.zoneDmg = dmg * 0.8f; b.life = 0.6f;
                        foreach (var e in g.EnemyList()) if (e.Active && Vector2.Distance(e.pos, from + new Vector2(0, -312f)) <= 130f) e.Freeze(1.2f);
                        break;
                    }
                case "saru":
                    {
                        hasteT = 6f;
                        Fx.SlashFx(from, -Mathf.PI * 0.5f, 220f, col, 3f, 0.35f, 18f);
                        foreach (var eb in g.EnemyBullets()) if (eb.Active && eb.pos.y < pos.y && Mathf.Abs(eb.pos.x - pos.x) < 220f) eb.Vanish("saru-cast");
                        for (int i = 0; i < 3; i++)
                        {
                            float a = -Mathf.PI * 0.5f + (i - 1f) * 14f * Mathf.Deg2Rad;
                            var b = CastBullet(g, kami, 11, 11f, from, Gd.Dir(a) * 820f, dmg * 0.9f); b.pierce = 999;
                        }
                        Sfx.Play("dash", -6f, 0.8f);
                        break;
                    }
            }
        }

        // ---------- 神招き（主神の技） ----------

        public void AddCallGauge(float amount)
        {
            if (MainGod() == "" || callT > 0f) return;
            callGauge = Mathf.Clamp01(callGauge + amount * CostMult("gauge") * (HasRelic("r_gauge") ? 1.25f : 1f));
        }

        private float CallValue(string kami) => BaseDamage() * 4f * Boons.KamiPower(KamiLv(kami)) * (callPower <= 1f ? 1f : 1.4f);

        private void TryCall(GameManager g)
        {
            string kami = MainGod();
            if (kami == "" || callT > 0f || callGauge < 0.25f) return;
            bool greater = callGauge >= 0.999f;
            callPower = greater ? 1.8f : 1f;
            callGauge = greater ? 0f : callGauge - 0.25f;
            float v = CallValue(kami);
            var col = KamiColor(kami);
            Sfx.Play("flute", -4f);
            Sfx.Play("taiko", -6f);
            Music.Duck(1.6f);
            Fx.Flash(Gd.WithA(col, 0.55f), 0.35f);
            Fx.RingFx(pos, col, 20f, 400f, 0.6f, 6f);
            Fx.ShakeAdd(10f);
            g.Hitstop(0.25f, 0.08f);
            g.hud.CallCutin(kami, greater);
            g.FreezeFor(1.5f);
            switch (kami)
            {
                case "ama": callKind = "sun"; callT = 2.4f * callPower; callTick = 0f; break;
                case "take": callKind = "storm"; callT = 2.2f * callPower; callTick = 0f; break;
                case "susa":
                    Fx.SlashFx(new Vector2(Gd.W * 0.5f, pos.y - 200f), -Mathf.PI * 0.5f, 420f, col, 2.8f, 0.4f, 26f);
                    Fx.SlashFx(new Vector2(Gd.W * 0.5f, pos.y - 220f), -Mathf.PI * 0.5f, 300f, Color.white, 2.6f, 0.3f, 10f);
                    g.EraseAllEnemyBullets();
                    foreach (var e in g.EnemyList().ToArray()) if (e.Active && e.pos.y < pos.y) Combat.Hit(e, v * 3f, e.pos, new HitOpts { tag = "call", kami = "susa", dir = Vector2.down, kb = 700f });   // 画面の上へ押し飛ばす（Godot の UP）
                    Fx.ShakeAdd(18f);
                    break;
                case "tsuki":
                    g.Hitstop(1f, 0.12f);
                    foreach (var e in g.EnemyList()) if (e.Active) e.AddDoom(v * 3f * (1f + Val("tsuki_u2") * 0.01f), 1.3f);
                    break;
                case "uzume":
                    foreach (var e in g.EnemyList()) if (e.Active) e.AddCharm(4f * callPower);
                    Fx.Petals(pos, col, 40, 260f);
                    Sfx.Play("charm", -4f, 0.8f);
                    break;
                case "inari":
                    {
                        int n = greater ? 15 : 9;
                        for (int i = 0; i < n; i++)
                        {
                            var target = Combat.NearestEnemy(pos, 2000f);
                            float a = -Mathf.PI * 0.5f + (i - (n - 1) * 0.5f) * 0.28f;
                            var b = g.SpawnPlayerBullet(pos + new Vector2(0, -20), Gd.Dir(a) * 500f, v * 1.5f, col, 9f, 3);
                            b.homing = 5.5f; b.pierce = 1; b.kami = "inari"; b.tag = "call"; b.critChance = CritChance() + 0.3f; b.target = target;
                        }
                        break;
                    }
                case "suku":
                    foreach (var e in g.EnemyList()) if (e.Active) Combat.ApplyHangover(e, Combat.HangoverMax(), Combat.HangoverDps());
                    Heal(maxHp * 0.3f * callPower, true);
                    Fx.ZoneFx(pos, 200f, col, 0.8f);
                    break;
                case "iza":
                    foreach (var e in g.EnemyList()) if (e.Active) e.Freeze(3f * callPower);
                    Fx.Flash(Gd.WithA(new Color(0.8f, 0.95f, 1f), 0.6f), 0.4f);
                    break;
                case "saru":
                    callKind = "slow"; callT = 3f * callPower;
                    g.enemySlow = 0.35f; g.enemyBulletSlow = 0.6f;
                    break;
            }
        }

        private void CallTick(float dt, GameManager g)
        {
            if (callT <= 0f) return;
            callT -= dt;
            string kami = MainGod();
            float v = CallValue(kami);
            var col = KamiColor(kami);
            callTick -= dt;
            switch (callKind)
            {
                case "sun":
                    iframe = Mathf.Max(iframe, 0.1f);
                    if (callTick <= 0f)
                    {
                        callTick = 0.25f;
                        Fx.Rays(pos, col, 16, 40f, 700f, 0.3f);
                        foreach (var e in g.EnemyList().ToArray()) if (e.Active) { e.AddExposed(Combat.EXPOSED_T); Combat.Hit(e, v * 0.25f, e.pos, HitOpts.Of("light", "ama")); }
                    }
                    break;
                case "storm":
                    if (callTick <= 0f)
                    {
                        callTick = 0.11f;
                        var es = g.EnemyList();
                        if (es.Count > 0) { var e = es[Random.Range(0, es.Count)]; if (e.Active) Combat.Lightning(e, v, new Vector2(e.pos.x + Gd.Rand(-60, 60), -20), 0); }
                        Fx.ShakeAdd(1.5f);
                    }
                    break;
                case "slow":
                    if (callTick <= 0f) { callTick = 0.2f; Fx.RingFx(pos, col, 40f, 60f, 0.3f, 1.5f); }
                    break;
            }
            if (callT <= 0f)
            {
                if (callKind == "slow") { g.enemySlow = 1f; g.enemyBulletSlow = 0f; }
                callKind = "";
            }
        }

        // ---------- 維持処理 ----------

        public bool InFog()
        {
            foreach (var z in GameManager.I.Zones()) if (z.Active && z.kind == "fog" && Vector2.Distance(z.pos, pos) <= z.r) return true;
            return false;
        }

        private void Upkeep(float dt)
        {
            AddCallGauge(dt * 0.022f);
            dashBuffT = Mathf.Max(0f, dashBuffT - dt);
            fanHealCd = Mathf.Max(0f, fanHealCd - dt);
            if (Has("suku_u7"))
            {
                _fogT += dt;
                if (_fogT >= 1f) { _fogT -= 1f; if (hp < maxHp && InFog()) { Heal(Val("suku_u7"), false); Fx.Sparks(pos, Vector2.up, new Color(0.62f, 1f, 0.55f), 3, 120f); } }
            }
            if (Has("suku_u5"))
            {
                regenT += dt;
                if (regenT >= 1f) { regenT -= 1f; if (hp < maxHp) Heal(Val("suku_u5"), false); }
            }
            if (Has("ama_u5") && shield < 1)
            {
                shieldT -= dt;
                if (shieldT <= 0f) { shield = 1; shieldT = Val("ama_u5"); Fx.RingFx(pos, Gd.C_GOLD, 12f, 40f, 0.3f); Sfx.Play("suzu", -14f, 1f); }
            }
        }

        private void Contact(GameManager g)
        {
            if (_contactCd > 0f || iframe > 0f) return;
            foreach (var e in g.EnemyList())
            {
                if (!e.Active || e.st.charm > 0f) continue;
                if (Vector2.Distance(e.pos, pos) < radius + e.radius * 0.88f)
                {
                    _contactCd = 0.4f;
                    TakeDamage(e.contactDmg * e.OutDmgMult(), e.DisplayName() + "の体当たり");
                    return;
                }
            }
        }

        // ---------- HP / XP ----------

        public void TakeDamage(float d, string source = "")
        {
            if (!alive || iframe > 0f || dashT > 0f || godMode) return;
            if (source != "") lastHitBy = source;
            d *= CostMult("taken") * (Has("curse_fire") ? 1.25f : 1f);
            if (Has("suku_u7") && InFog()) d *= 0.8f;
            var g = GameManager.I;
            if (shield > 0)
            {
                shield--;
                shieldT = Has("ama_u5") ? Val("ama_u5") : 99f;
                iframe = 0.7f;
                Fx.RingFx(pos, Gd.C_GOLD, 14f, 90f, 0.35f, 4f);
                Fx.Sparks(pos, Vector2.up, Gd.C_GOLD, 14, 300f);
                Fx.ShakeAdd(5f);
                Sfx.Play("deflect", -4f, 0.8f);
                Sfx.Play("suzu", -8f);
                return;
            }
            if (hp - d <= 0f && HasRelic("r_revive") && !_revived)
            {
                _revived = true;
                hp = maxHp * 0.5f; iframe = 2f;
                Fx.Flash(new Color(1, 1, 1, 0.7f), 0.5f);
                Fx.RingFx(pos, Gd.C_GOLD, 10f, 220f, 0.6f, 6f);
                Fx.Number(pos + new Vector2(0, -60), "身代わり", Gd.C_GOLD, 20f, true);
                Sfx.Play("levelup", -4f);
                g.Hitstop(0.3f, 0.05f);
                return;
            }
            hp -= d;
            iframe = 1f * (familiarId == "shiki" ? 1.25f : 1f) * (HasRelic("r_iframe") ? 1.4f : 1f);
            AddCallGauge(0.08f);
            Fx.ShakeAdd(9f);
            Fx.Flash(new Color(1f, 0.3f, 0.4f, 0.25f), 0.15f);
            Fx.Burst(pos, Gd.C_ENEMY, 14, 250f, 4f, 0.45f);
            Fx.Number(pos + new Vector2(0, -40), "-" + Mathf.RoundToInt(d), new Color(1f, 0.45f, 0.5f), 17f, true);
            Sfx.Play("hurt", -6f);
            g.Hitstop(0.08f, 0.05f);
            g.OnPlayerHit();
            if (hp > 0f && Has("suku_leg") && _miracleCd <= 0f && hp / maxHp <= 0.3f)
            {
                _miracleCd = 60f;
                Heal(maxHp * Val("suku_leg") * 0.01f, true);
                Fx.RingFx(pos, new Color(0.62f, 1f, 0.55f), 10f, 160f, 0.5f, 5f);
                Sfx.Play("heal", -2f, 0.8f);
            }
            if (hp <= 0f) { hp = 0f; Die(); }
        }

        /// <summary>互換用（敵弾の命中など）。</summary>
        public void Hit(float dmg, string source = "敵の弾") => TakeDamage(dmg, source);

        public void Heal(float amount, bool show = true)
        {
            float before = hp;
            hp = Mathf.Min(maxHp, hp + amount);
            if (show && hp > before) Fx.Number(pos + new Vector2(0, -44), "+" + Mathf.RoundToInt(hp - before), Gd.C_HP, 16f);
        }

        public void AddXp(float amount)
        {
            xp += amount * xpMult * (HasRelic("r_xp") ? 1.2f : 1f);
            while (xp >= xpNext)
            {
                xp -= xpNext;
                level++;
                xpNext = XpNeed(level);
                pendingLevels++;
                maxHp += 3f;
                hp += 3f;
                GameManager.I?.OnLeveledUp();
            }
        }

        public float MagnetRange() => magnet * (familiarId == "neko" ? 1.35f : 1f) * CostMult("magnet") * (HasRelic("r_magnet") ? 1.4f : 1f);

        private void Die()
        {
            alive = false;
            Fx.Burst(pos, Gd.C_PLAYER, 40, 420f, 6f, 1f);
            Fx.Petals(pos, new Color(1f, 0.8f, 0.95f), 30, 220f);
            Fx.RingFx(pos, Color.white, 8f, 300f, 0.7f);
            Fx.ShakeAdd(22f);
            Sfx.Play("boom", -4f);
            Sfx.Play("gameover", -8f);
            _spr.enabled = false;
            _vec.Begin(); _vec.End();
            foreach (var w in weapons.Values) w.Destroy();
            weapons.Clear();
            GameManager.I.OnPlayerDied();
        }

        // ---------- 描画 ----------

        private void Apply() => transform.position = Gd.ToWorld(pos);

        private void Draw()
        {
            var v = _vec;
            v.Begin();
            string main = MainGod();
            Color col = main != "" ? KamiColor(main) : Gd.C_PLAYER;
            if (Has("tsuki_u8")) v.DrawArc(Vector2.zero, VEIL_R, 0, Gd.TAU, 64, new Color(0.78f, 0.72f, 1f, 0.10f + 0.03f * Mathf.Sin(t * 2f)), 1.5f);
            float mr = 26f + 2f * Mathf.Sin(t * 3f);
            float ma = main != "" ? 0.35f : 0.18f;
            v.SetTransform(new Vector2(0, 34), 0f, new Vector2(1f, 0.42f));
            v.DrawArc(Vector2.zero, mr, 0, Gd.TAU, 40, Gd.WithA(col, ma), 2f);
            v.DrawArc(Vector2.zero, mr * 0.72f, 0, Gd.TAU, 32, Gd.WithA(col, ma * 0.7f), 1f);
            for (int i = 0; i < 6; i++)
            {
                float a = t * 1.2f + Gd.TAU * i / 6f;
                v.DrawLine(Gd.Dir(a) * mr * 0.72f, Gd.Dir(a + Gd.TAU / 3f) * mr * 0.72f, Gd.WithA(col, ma * 0.5f), 1f);
            }
            v.SetTransform(Vector2.zero, 0f, Vector2.one);
            if (iframe > 0f)
            {
                float k = 0.5f + 0.5f * Mathf.Sin(t * 24f);
                v.DrawArc(new Vector2(0, -4), 30f + 3f * k, 0, Gd.TAU, 40, new Color(1, 1, 1, 0.35f + 0.3f * k), 2f);
                for (int i = 0; i < 4; i++) { float a = t * 6f + Gd.TAU * i / 4f; v.DrawCircle(Gd.Dir(a) * (30f + 3f * k) + new Vector2(0, -4), 2.5f, new Color(1, 1, 1, 0.8f)); }
            }
            if (shield > 0)
            {
                v.DrawArc(new Vector2(0, -6), 34f, 0f, Gd.TAU, 40, Gd.WithA(Gd.C_GOLD, 0.35f + 0.12f * Mathf.Sin(t * 3f)), 2f);
                v.DrawArc(new Vector2(0, -6), 30f, t * 2f, t * 2f + 1.2f, 12, new Color(1, 1, 1, 0.5f), 2f);
            }
            if (hasteT > 0f)
                for (int i = 0; i < 3; i++)
                {
                    float y = Mathf.Repeat(t * 300f + i * 25f, 70f);
                    v.DrawLine(new Vector2(-14, 20 + y), new Vector2(-14, 32 + y), new Color(0.72f, 1f, 0.98f, 0.5f), 1.5f);
                    v.DrawLine(new Vector2(14, 20 + y), new Vector2(14, 32 + y), new Color(0.72f, 1f, 0.98f, 0.5f), 1.5f);
                }
            if (callT > 0f && callKind == "sun") v.DrawCircle(new Vector2(0, -6), 60f + 10f * Mathf.Sin(t * 12f), Gd.WithA(Gd.C_GOLD, 0.18f));
            if (main != "" && castCharges > 0) v.DrawCircle(new Vector2(0, -34), 3f + Mathf.Sin(t * 8f), Gd.WithA(col, 0.6f));
            if (focus)
            {
                v.DrawCircle(Vector2.zero, radius, new Color(1f, 0.4f, 0.5f, 0.75f));
                v.DrawArc(Vector2.zero, radius + 4f, 0f, Gd.TAU, 24, new Color(1, 1, 1, 0.5f), 1f);
            }
            if (dashCool > 0f)
            {
                float k2 = 1f - dashCool / Mathf.Max(0.01f, DashCdTime());
                v.DrawArc(new Vector2(0, 34), 16f, 0, Gd.TAU, 24, new Color(0, 0, 0, 0.45f), 4f);
                v.DrawArc(new Vector2(0, 34), 16f, -Mathf.PI * 0.5f, -Mathf.PI * 0.5f + Gd.TAU * k2, 24, new Color(1, 1, 1, 0.75f), 3f);
            }
            v.End();
        }
    }
}
