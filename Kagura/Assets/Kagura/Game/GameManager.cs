using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using Kagura.Core;

namespace Kagura.Game
{
    public enum GameState { Title, Play, Choice, Pause, Over, Clear }
    public enum ChoiceKind { None, Story, Familiar, Kami, Boon, Miki, Relic, Shop }

    /// <summary>
    /// ゲーム全体の進行（Godot 版 game.gd の移植）。座標は Godot px（横 640、上が 0）。
    /// 波の生成は Kagura.Core.WaveBuilder、弾・敵・領域・アイテムは使い回し、当たり判定は距離で取る。
    /// </summary>
    public class GameManager : MonoBehaviour
    {
        public static GameManager I;
        public static bool storySeen;
        public const float TALISMAN_DROP = 0.02f;

        public GameState State = GameState.Title;
        public ChoiceKind choice = ChoiceKind.None;
        public int Wave, Score, Kills;
        public bool endless;
        public Player player;
        public Boss boss;
        public Starfield stars;
        public Hud hud;
        public Overlay overlay;
        public TouchUi touchUi;
        public Views ui;
        public RankingView ranking;
        public PauseMenu pauseMenu;
        public Net net;
        public Transform world;
        public float runDuration;
        public int runId;
        public string runKey = "";
        public float enemySlow = 1f, enemyBulletSlow;
        public bool diag; private float _diagT;
        public string forceKami = "";
        public string forceBoon = "";
        public bool fullCall;       // ?fullcall：神招きを常に満タンにする（演出の確認用）
        public bool forceShop;      // ?shop：毎波のあとに市を出し、両を多めに持って始める（検証用）
        public ShopStall stall;
        // コンボ：短い間隔で倒し続けると段が上がり、落とし物が少し増える。途切れると締めの演出
        public int combo, comboTier, comboBest; public float comboT;
        public const float COMBO_WINDOW = 1.8f;
        private static readonly int[] ComboNeed = { 5, 10, 20, 35, 60 };
        private static readonly string[] ComboNames = { "連撃", "猛撃", "修羅", "鬼神", "神威" };
        private static readonly float[] ComboMults = { 1.1f, 1.2f, 1.35f, 1.5f, 1.7f };
        private static readonly Color[] ComboCols = { new Color(0.9f, 0.95f, 1f), new Color(1f, 0.7f, 0.35f), new Color(1f, 0.35f, 0.4f), new Color(0.75f, 0.45f, 1f), new Color(1f, 0.85f, 0.4f) };
        public float ComboMult => comboTier > 0 ? ComboMults[comboTier - 1] : 1f;
        public string ComboName => comboTier > 0 ? ComboNames[comboTier - 1] : "";
        public Color ComboColor => comboTier > 0 ? ComboCols[comboTier - 1] : new Color(0.9f, 0.95f, 1f);
        private readonly HashSet<int> _shopStages = new HashSet<int>();
        private readonly List<ShopOffer> _shop = new List<ShopOffer>();
        private bool _userActive;   // 一度でもタップ・キー操作があった（ブラウザの音の解禁）
        public bool enemySprites = true;

        private readonly List<Bullet> _pBullets = new List<Bullet>();
        private readonly List<Bullet> _eBullets = new List<Bullet>();
        private readonly List<Enemy> _enemies = new List<Enemy>();
        private readonly List<Enemy> _enemyList = new List<Enemy>();
        private readonly List<Bullet> _eBulletList = new List<Bullet>();
        private readonly List<Pickup> _pickups = new List<Pickup>();
        private readonly List<Zone> _zones = new List<Zone>();
        private List<SpawnEntry> _plan = new List<SpawnEntry>();
        private int _planI;
        private float _waveT, _between = 1.2f, _minionT;
        private bool _waveActive, _bossReward;
        private IRng _rng;
        private Camera _cam;
        private int _lastW, _lastH;
        private float _hitstop, _hitstopLast = -10f, _freezeT, _overlayDelay;
        private int _tutStep; private float _tutT;
        private readonly HashSet<int> _seenItems = new HashSet<int>();
        // 選択の状態
        private string _offerKami = "", _offerReason = "level";
        private List<Offer> _offers = new List<Offer>();
        private int _offerMinRar, _rerolls;
        private List<RelicDef> _relicOffers = new List<RelicDef>();

        public Vector2 PlayerPos => player != null ? player.pos : new Vector2(Gd.W * 0.5f, Gd.H * 0.8f);
        public bool IsTouch => touchUi != null && touchUi.active;

        /// <summary>
        /// Godot 版の get_tree().paused に相当：世界（背景・敵・弾）が止まっているか。
        /// 一時停止・選択画面・見せ場の静止中・結果画面が出た後は true。UI や演出（Fx）はこれに関わらず動く。
        /// </summary>
        public bool WorldPaused =>
            State == GameState.Pause || State == GameState.Choice || _freezeT > 0f
            || ((State == GameState.Over || State == GameState.Clear) && overlay != null && overlay.visible);
        public int EnemyCount { get { int n = 0; foreach (var e in _enemies) if (e.Active) n++; return n; } }
        public int EnemyBulletCount { get { int n = 0; foreach (var b in _eBullets) if (b.Active) n++; return n; } }

        /// <summary>生きている敵（ボス込み）。呼び出し中に増減しても安全なよう、フレーム内でリストを作り直す。</summary>
        public List<Enemy> EnemyList()
        {
            _enemyList.Clear();
            foreach (var e in _enemies) if (e.Active) _enemyList.Add(e);
            if (boss != null && boss.Active) _enemyList.Add(boss);
            return _enemyList;
        }
        public List<Bullet> EnemyBullets()
        {
            _eBulletList.Clear();
            foreach (var b in _eBullets) if (b.Active) _eBulletList.Add(b);
            return _eBulletList;
        }
        public List<Zone> Zones() => _zones;

        private void Awake()
        {
            I = this;
#if UNITY_WEBGL && !UNITY_EDITOR
            Application.targetFrameRate = -1;   // ブラウザの requestAnimationFrame に任せる（setTimeout 方式は絞られる）
#else
            Application.targetFrameRate = 60;
#endif
            _cam = Camera.main;
            world = new GameObject("world").transform;
            _rng = new SystemRng(System.Environment.TickCount);
            FitCamera();
            stars = Starfield.Create(transform);
            Fx.Create(transform);
            Sfx.Create(transform);
            Music.Create(transform);
            hud = Hud.Create(transform);
            overlay = Overlay.Create(transform);
            touchUi = TouchUi.Create(transform);
            ui = Views.Create(transform);
            ranking = new RankingView(transform);
            pauseMenu = new PauseMenu(transform);
            net = Net.Create(transform);
            ui.OnFamiliarChosen = OnFamiliarChosen;
            ui.OnKamiChosen = OnKamiChosen;
            ui.OnBoonChosen = OnBoonChosen;
            ui.OnReroll = OnReroll;
            ui.OnMikiChosen = OnMikiChosen;
            ui.OnRelicChosen = OnRelicChosen;
            ui.OnStoryDone = OnStoryDone;
            ui.OnShopBuy = OnShopBuy;
            ui.OnShopLeave = OnShopLeave;
            stall = ShopStall.Create(transform);
            PostFx.Setup(_cam);
            string url = Application.absoluteURL ?? "";
            if (url.Contains("autoplay") || url.Contains("cleartest"))
            {
                var ap = gameObject.AddComponent<Autoplay>(); ap.god = url.Contains("cleartest");
                var m = System.Text.RegularExpressions.Regex.Match(url, @"wave=(\d+)");
                if (m.Success) ap.startWave = int.Parse(m.Groups[1].Value);
            }
            diag = url.Contains("diag");
            {   // ?kami=susa：神の選択肢の先頭にその神を出す（検証用。autoplay は先頭を選ぶ）
                var km = System.Text.RegularExpressions.Regex.Match(url, @"kami=([\w,]+)");
                if (km.Success) forceKami = km.Groups[1].Value;
                var bm = System.Text.RegularExpressions.Regex.Match(url, @"boon=(\w+)");
                if (bm.Success) forceBoon = bm.Groups[1].Value;
                fullCall = url.Contains("fullcall");
                forceShop = url.Contains("shop");
            }
            enemySprites = !url.Contains("vector");   // ?vector で従来のベクター描画に戻せる
            ShowTitle();
        }

        /// <summary>横 640px を画面幅に合わせ、縦は端末なりに伸ばす。</summary>
        private void FitCamera()
        {
            if (_cam == null) return;
            float aspect = (float)Screen.height / Mathf.Max(1, Screen.width);
            Gd.H = Mathf.Max(Gd.HBase, Mathf.Floor(Gd.W * aspect));
            _cam.orthographic = true;
            _cam.orthographicSize = Gd.H * 0.5f;
            _cam.transform.position = new Vector3(0, 0, -10);
            _lastW = Screen.width; _lastH = Screen.height;
            if (player != null) player.pos.y = Mathf.Clamp(player.pos.y, 60f, Gd.H - 30f);
        }

        // ---------- 状態 ----------

        public void ShowTitle()
        {
            // 最初の操作前はブラウザが音を鳴らせないので、「tap to begin」で待ってから曲とアニメを始める
            bool wait = !Net.AudioReady();   // iOS は操作前のタップがないと音が出ない。AudioContext の状態で判定
            if (wait) Music.Stop(); else Music.Play("title");
            overlay.StartIntro(wait);
            if (State == GameState.Pause) pauseMenu.Close();
            State = GameState.Title; choice = ChoiceKind.None;
            Time.timeScale = 1f; _hitstop = 0f; _freezeT = 0f;
            ui.HideCards();
            Music.Muffle(false);
            overlay.mode = 0; overlay.visible = true;
            stars.speed = 0.4f;
        }

        public void StartGame()
        {
            foreach (var e in _enemies) e.Despawn();
            foreach (var b in _pBullets) b.Despawn();
            foreach (var b in _eBullets) b.Despawn();
            foreach (var p in _pickups) p.Despawn();
            foreach (var z in _zones) z.Despawn();
            if (boss != null) boss.Despawn();
            boss = null;
            Fx.ClearAll();
            enemySlow = 1f; enemyBulletSlow = 0f;
            if (player == null)
            {
                var go = new GameObject("player");
                go.transform.SetParent(world, false);
                player = go.AddComponent<Player>();
            }
            player.Reset();
            player.pos = new Vector2(Gd.W * 0.5f, Gd.H - 190f);
            Wave = 0; Score = 0; Kills = 0; runDuration = 0f; endless = false;
            runId = (int)(System.DateTimeOffset.UtcNow.ToUnixTimeSeconds() % int.MaxValue);
            runKey = runId + "-" + Random.Range(0, 1000000).ToString("000000");
            _waveActive = false; _between = 1.2f; _plan.Clear(); _planI = 0; _bossReward = false; _hitstop = 0f; _freezeT = 0f;
            _tutStep = 0; _tutT = 0f; _seenItems.Clear(); _shopStages.Clear(); if (stall != null) stall.Despawn();
            combo = 0; comboTier = 0; comboBest = 0; comboT = 0f;
            if (forceShop) player.ryo = 80;
            stars.stage = 1; stars.speed = 1f; stars.tint = new Color(0.45f, 0.30f, 0.80f);
            overlay.visible = false;
            ui.HideCards();
            Time.timeScale = 1f;
            State = GameState.Play;
            Music.Play("stage");
            if (!storySeen && UiKit.Art("cutin/opening") != null)
            {
                storySeen = true;
                PauseForChoice(ChoiceKind.Story);
                ui.ShowStory();
                return;
            }
            PauseForChoice(ChoiceKind.Familiar);
            ui.ShowFamiliarChoice();
        }

        private void OnStoryDone()
        {
            if (choice != ChoiceKind.Story) return;
            PauseForChoice(ChoiceKind.Familiar);
            ui.ShowFamiliarChoice();
        }

        private void OnFamiliarChosen(string id)
        {
            if (choice != ChoiceKind.Familiar) return;
            player.SetFamiliar(id);
            var f = Familiar.InfoOf(id);
            Sfx.Play("suzu", -6f);
            CloseChoice();
            hud.Banner(f.name + " が付いてきた", IsTouch ? "なぞって移動、弾いて疾走" : "WASD 移動　Space 疾走", f.color);
        }

        public void TogglePause()
        {
            if (State == GameState.Play) { State = GameState.Pause; Music.Muffle(true); pauseMenu.Open(); }
            else if (State == GameState.Pause) { pauseMenu.Close(); State = GameState.Play; Music.Muffle(false); }
        }

        /// <summary>小休止のメニューから「あきらめる」：この参拝を記録せず題目へ戻る。</summary>
        public void GiveUp()
        {
            if (State != GameState.Pause) return;
            ShowTitle();
        }

        /// <summary>ヒットストップ：dur 秒（実時間）だけ時間の流れを scale に落とす。小さな止めは間引く。</summary>
        public void Hitstop(float dur, float scale = 0.05f)
        {
            float now = Time.unscaledTime;
            if (dur < 0.07f && now - _hitstopLast < 0.22f) return;
            _hitstopLast = now;
            if (dur <= _hitstop) return;
            _hitstop = dur;
            Time.timeScale = scale;
        }

        /// <summary>見せ場で世界を止める（UI だけ動く）。sec 秒後に自動で再開。</summary>
        public void FreezeFor(float sec)
        {
            if (State != GameState.Play) return;
            Time.timeScale = 1f; _hitstop = 0f;
            _freezeT = sec;
        }

        private void Update()
        {
            if (Screen.width != _lastW || Screen.height != _lastH) FitCamera();
            if (Fx.I != null && Fx.I.shake > 0f) world.position = new Vector3(Gd.Rand(-1f, 1f) * Fx.I.shake, Gd.Rand(-1f, 1f) * Fx.I.shake, 0);
            else world.position = Vector3.zero;

            if (_hitstop > 0f)
            {
                _hitstop -= Time.unscaledDeltaTime;
                if (_hitstop <= 0f) { _hitstop = 0f; Time.timeScale = 1f; }
            }

            var kb = Keyboard.current; var ms = Mouse.current; var ts = Touchscreen.current;
            bool tap = (ts != null && ts.primaryTouch.press.wasPressedThisFrame) || (ms != null && ms.leftButton.wasPressedThisFrame && (ts == null || !ts.primaryTouch.press.isPressed));
            Vector2 tapPx = Vector2.zero;
            if (tap) tapPx = TouchUi.ToPx(ts != null && ts.primaryTouch.press.wasPressedThisFrame ? ts.primaryTouch.position.ReadValue() : ms.position.ReadValue());
            bool held = (ts != null && ts.primaryTouch.press.isPressed) || (ms != null && ms.leftButton.isPressed);
            Vector2 heldPx = held ? TouchUi.ToPx(ts != null && ts.primaryTouch.press.isPressed ? ts.primaryTouch.position.ReadValue() : ms.position.ReadValue()) : Vector2.zero;
            bool enter = kb != null && (kb.enterKey.wasPressedThisFrame || kb.numpadEnterKey.wasPressedThisFrame || kb.spaceKey.wasPressedThisFrame);
            if (tap || (kb != null && kb.anyKey.wasPressedThisFrame)) _userActive = true;
            bool rKey = kb != null && kb.rKey.wasPressedThisFrame;
            if (kb != null && kb.mKey.wasPressedThisFrame)
            {
                bool m = !Sfx.I.muted;
                Sfx.I.muted = m; Music.I.muted = m;
                hud.Banner("音 " + (m ? "OFF" : "ON"), "", new Color(0.8f, 0.9f, 1f));
            }

            if (_overlayDelay > 0f)
            {
                _overlayDelay -= Time.unscaledDeltaTime;
                if (_overlayDelay <= 0f) overlay.visible = true;
            }
            // 記録の一覧（題目・結果画面から開く）
            ranking.Tick(Time.unscaledDeltaTime);
            if (ranking.visible) { ranking.HandleInput(tap, tapPx); return; }
            bool nKey = kb != null && kb.nKey.wasPressedThisFrame;

            switch (State)
            {
                case GameState.Title:
                    if (overlay.gate) { if (enter || tap || (kb != null && kb.anyKey.wasPressedThisFrame)) { overlay.PassGate(); Music.Play("title"); } return; }
                    if (overlay.IntroPlaying) { if (enter || tap) overlay.SkipIntro(); return; }
                    if (enter) { StartGame(); return; }
                    if (rKey) { ranking.Open(); return; }
                    if (nKey) { NamePrompt(); return; }
                    if (tap)
                    {
                        int m = overlay.MenuAt(tapPx);
                        if (m == 0) { Sfx.Play("select", -6f); StartGame(); }
                        else if (m == 1) { Sfx.Play("select", -10f); ranking.Open(); }
                        else if (m == 2) { Sfx.Play("select", -10f); NamePrompt(); }
                    }
                    return;
                case GameState.Over:
                    if (!overlay.visible) { TickWorldFx(); return; }
                    if (rKey) { StartGame(); return; }
                    if (nKey) { NamePrompt(); return; }
                    if (tap && overlay.nameBtnShown && overlay.nameBtn.Contains(tapPx)) { NamePrompt(); return; }
                    if (enter || tap) ShowTitle();
                    return;
                case GameState.Clear:
                    if (!overlay.visible) { TickWorldFx(); return; }
                    if (rKey) { StartGame(); return; }
                    if (nKey) { NamePrompt(); return; }
                    if (tap && overlay.nameBtnShown && overlay.nameBtn.Contains(tapPx)) { NamePrompt(); return; }
                    if (enter || tap) ContinueEndless();
                    return;
                case GameState.Pause:
                    pauseMenu.Tick(Time.unscaledDeltaTime, !IsTouch && ms != null ? TouchUi.ToPx(ms.position.ReadValue()) : (Vector2?)null);
                    if (tap && PauseMenu.GearHit(tapPx)) { TogglePause(); return; }
                    pauseMenu.HandleInput(tap, tapPx, held, heldPx, kb);
                    return;
                case GameState.Choice:
                    if (kb != null && kb.escapeKey.wasPressedThisFrame && !ui.confirm.visible && !ui.shop.visible) { ShowTitle(); return; }
                    return;
            }
            if (kb != null && (kb.pKey.wasPressedThisFrame || kb.escapeKey.wasPressedThisFrame)) { TogglePause(); return; }
            if (tap && PauseMenu.GearHit(tapPx)) { Sfx.Play("select", -12f); TogglePause(); return; }

            stars.speed = 1f + Wave * 0.04f;
            if (player == null || !player.alive) return;

            float dt = Time.deltaTime;
            runDuration += Time.unscaledDeltaTime;
            Tutorial(dt);

            if (_freezeT > 0f)
            {
                if (Time.timeScale < 0.999f) { Time.timeScale = 1f; _hitstop = 0f; }
                _freezeT -= Time.unscaledDeltaTime;
                return;
            }

            // レベルアップした瞬間に時間を止めて神との邂逅へ
            if (player.pendingLevels > 0)
            {
                if (BoonsLogic.RecruitDue(player)) OpenKamiChoice();
                else OpenLevelPick();
                return;
            }

            if (fullCall) player.callGauge = 1f;
            TickWave(dt);
            // 低フレームレートでも弾がすり抜けないよう、1/60 秒以下に刻んで進める（Godot 版の物理 60Hz に相当）
            int steps = Mathf.Clamp(Mathf.CeilToInt(dt * 60f - 0.05f), 1, 4);
            float sub = dt / steps;
            for (int i = 0; i < steps; i++) { TickWorld(sub); if (State != GameState.Play || player == null || !player.alive) break; }
        }

        /// <summary>線分 ab と点 p の距離の二乗（弾の移動経路で当たりを取る：速い弾のすり抜け防止）。</summary>
        private static float SegDist2(Vector2 a, Vector2 b, Vector2 p)
        {
            var ab = b - a; float len2 = ab.sqrMagnitude;
            if (len2 < 1e-6f) return (p - b).sqrMagnitude;
            float t = Mathf.Clamp01(Vector2.Dot(p - a, ab) / len2);
            return (p - (a + ab * t)).sqrMagnitude;
        }

        /// <summary>結果画面までの間、世界を動かさず演出だけ進める（弾は消えていく）。</summary>
        private void TickWorldFx()
        {
            float dt = Time.deltaTime;
            foreach (var b in _pBullets) if (b.Active) b.Tick(dt);
            foreach (var b in _eBullets) if (b.Active) b.Tick(dt);
            foreach (var z in _zones) if (z.Active) z.Tick(dt, this);
            foreach (var pk in _pickups) if (pk.Active) pk.Tick(dt, player);
        }

        private void TickWorld(float dt)
        {
            if (diag)
            {
                _diagT += Time.unscaledDeltaTime;
                if (_diagT > 2f)
                {
                    _diagT = 0f;
                    int pb = 0; string sample = "";
                    foreach (var b in _pBullets) if (b.Active) { pb++; if (sample == "") sample = $"pos={b.pos} vel={b.vel} life={b.life:0.00} r={b.radius} kind={b.shapeKind} go={b.gameObject.activeSelf} vecpos={b.transform.position}"; }
                    string why = ""; foreach (var kv in Bullet.DiagWhy) why += kv.Key + "=" + kv.Value + " ";
                    var kinds = new Dictionary<int, int>(); foreach (var b in _pBullets) if (b.Active) kinds[b.shapeKind] = kinds.TryGetValue(b.shapeKind, out var kn) ? kn + 1 : 1;
                    string pk = ""; foreach (var kv in kinds) pk += kv.Key + "=" + kv.Value + " ";
                    string ws = ""; foreach (var w in player.weapons.Keys) ws += w + " ";
                    Debug.Log($"[diag] pbKinds[{pk}] weapons[{ws}]");
                    Debug.Log($"[diag] dt={dt:0.000} ts={Time.timeScale} wave={Wave} enemies={EnemyCount} pb={pb} eb={EnemyBulletCount} pool={_pBullets.Count} player={player.pos} alive={player.alive} fireRate={player.fireRate} gods={string.Join("+", player.gods)} ebSpawned={Bullet.DiagSpawned} why[{why}] {sample}");
                }
            }
            player.Tick(dt);
            if (!player.alive) return;
            if (combo > 0) { comboT -= dt; if (comboT <= 0f) ComboEnd(); }
            var pp = player.pos;
            foreach (var pk in _pickups)
                if (pk.Active)
                {
                    pk.Tick(dt, player);
                    float rr = pk.Radius + player.radius;
                    if (pk.Active && (pk.pos - pp).sqrMagnitude <= rr * rr) Collect(pk);
                }
            foreach (var z in _zones) if (z.Active) z.Tick(dt, this);
            if (stall != null && stall.Active)
            {
                stall.Tick(dt);
                if (stall.Active && Vector2.Distance(stall.pos, pp) <= ShopStall.R + player.radius) { stall.Despawn(); OpenShop(); return; }
            }
            if (boss != null && boss.Active) boss.Tick(dt, this);
            for (int ei = 0; ei < _enemies.Count; ei++) { var e = _enemies[ei]; if (e.Active) e.Tick(dt, this); }
            for (int bi = 0; bi < _pBullets.Count; bi++) { var b = _pBullets[bi]; if (b.Active) b.Tick(dt); }
            for (int bi = 0; bi < _eBullets.Count; bi++) { var b = _eBullets[bi]; if (b.Active) b.Tick(dt); }

            // 自機の弾 → 敵 ／ 敵弾（消弾・反射）
            var enemies = EnemyList().ToArray();
            for (int bi = 0; bi < _pBullets.Count; bi++)
            {
                var b = _pBullets[bi];
                if (!b.Active) continue;
                foreach (var e in enemies)
                {
                    if (!e.Active || b.HasHit(e)) continue;
                    float r = b.radius + e.radius * 0.88f;
                    if (SegDist2(b.prevPos, b.pos, e.pos) <= r * r) { b.OnHitEnemy(e); if (!b.Active) break; }
                }
                if (!b.Active || !(b.eraser || b.reflect)) continue;
                foreach (var eb in _eBullets)
                {
                    if (!eb.Active) continue;
                    float r = b.radius + eb.radius;
                    if ((b.pos - eb.pos).sqrMagnitude <= r * r) { b.OnTouchEnemyBullet(eb); if (!b.Active) break; }
                }
            }
            // 敵弾 → 自機
            if (player.alive)
            {
                pp = player.pos;
                foreach (var b in _eBullets)
                {
                    if (!b.Active) continue;
                    float r = b.radius + player.radius;
                    if (SegDist2(b.prevPos, b.pos, pp) <= r * r)
                    {
                        b.Vanish("player-hit");   // 無敵中でも弾は消える（Godot と同じ）
                        if (player.dashT > 0f && player.HasRelic("r_s_tengu")) { Fx.Sparks(b.pos, Vector2.down, new Color(0.9f, 0.85f, 1f), 3, 200f); continue; }
                        if (player.iframe > 0f || player.dashT > 0f) continue;
                        player.TakeDamage(b.damage, b.source);
                        if (!player.alive) break;
                    }
                }
            }
        }

        /// <summary>序盤の導線：最初の 1 分だけ、状況に合わせて短い案内を出す。</summary>
        private void Tutorial(float dt)
        {
            if (_tutStep >= 3) return;
            _tutT += dt;
            switch (_tutStep)
            {
                case 0: if (_tutT > 4f) _tutStep = 1; break;
                case 1:
                    if (player.xp > 0f || _tutT > 14f) { _tutStep = 2; _tutT = 0f; hud.Banner("位が上がると神が現れる", "3 柱から主神を選ぶ", Gd.C_GOLD); }
                    break;
                case 2:
                    if (player.gods.Count > 0)
                    {
                        if (_tutT > 4f)
                        {
                            _tutStep = 3;
                            if (IsTouch) hud.Banner("右下の札", "詠唱：札を拾うと撃てる　　神招き：ゲージ 1/4 で", new Color(0.9f, 0.9f, 1f));
                            else hud.Banner("Z 詠唱　X 神招き", "詠唱は札を拾うと撃てる　　神招きはゲージ 1/4 で", new Color(0.9f, 0.9f, 1f));
                        }
                    }
                    else _tutT = 0f;
                    break;
            }
        }

        // ---------- 波 ----------

        private void TickWave(float dt)
        {
            if (!_waveActive) { _between -= dt; if (_between <= 0f) StartWave(); return; }
            _waveT += dt;
            while (_planI < _plan.Count && _plan[_planI].T <= _waveT)
            {
                if (EnemyCount >= Enemies.EnemyCap) break;
                var s = _plan[_planI]; _planI++;
                SpawnEnemy(s.Kind, new Vector2(s.X, s.Y));
            }
            if (boss != null && boss.Active && !boss.entering)
            {
                _minionT -= dt;
                if (_minionT <= 0f)
                {
                    _minionT = Mathf.Max(3f, 6.5f - boss.tier * 1f - (boss.isFinal ? 1f : 0f));
                    var kinds = new List<string> { "grunt", "weaver", "spirit" };
                    if (boss.tier >= 2) kinds.AddRange(new[] { "charger", "kite" });
                    if (boss.tier >= 3) kinds.AddRange(new[] { "splitter", "bomber" });
                    int n = 2 + boss.tier;
                    for (int i = 0; i < n; i++) SpawnEnemy(kinds[Random.Range(0, kinds.Count)], new Vector2(Gd.W * (i + 1) / (n + 1), -46f - i * 20f));
                    Sfx.Play("warn", -18f, 1.5f, 0.5f);
                }
            }
            if (_planI >= _plan.Count && EnemyCount == 0 && (boss == null || !boss.Active)) ClearWave();
        }

        private void StartWave()
        {
            Wave++;
            _waveT = 0f; _planI = 0; _waveActive = true;
            int stg = Stages.StageOf(Wave);
            stars.stage = stg;
            if (Stages.IsBossWave(Wave))
            {
                _plan = new List<SpawnEntry>();
                if (boss == null)
                {
                    var go = new GameObject("boss");
                    go.transform.SetParent(world, false);
                    boss = go.AddComponent<Boss>();
                }
                boss.SetupBoss(Wave, endless);
                _minionT = 5f;
                string[] keys = { "aratama", "dodomeki", "orochi" };
                hud.BossIntro(boss.bossName, boss.TitleText(), boss.isFinal, keys[Mathf.Min(boss.tier - 1, 2)]);
                if (boss.isFinal) { Music.Play("lastboss"); Fx.Flash(new Color(1, 0.2f, 0.3f, 0.4f), 0.6f); Sfx.Play("taiko", 0f, 0.55f); Sfx.Play("flute", -6f, 0.7f); }
                else { Music.Play("boss"); Sfx.Play("taiko", -2f, 0.7f); }
                Sfx.Play("warn", -6f);
                Fx.ShakeAdd(6f);
            }
            else
            {
                _plan = WaveBuilder.Build(Wave, _rng);
                if ((Wave - 1) % Gd.StageLen == 0)
                {
                    hud.Banner($"第{Gd.STAGE_KANJI[stg - 1]}の段　{Gd.STAGE_NAME[stg - 1]}", $"第 {Wave} 波", Gd.C_GOLD);
                    Sfx.Play("taiko", -8f, 1f); Sfx.Play("suzu", -10f);
                }
                else { hud.Banner($"第 {Wave} 波", "", new Color(0.85f, 0.8f, 1f)); Sfx.Play("clap", -10f); }
            }
        }

        private void ClearWave()
        {
            _waveActive = false;
            _between = 1.5f;
            if (player != null && player.alive)
            {
                player.Heal(6f, true);
                player.AddXp(8f + Wave * 2.5f);
                if (player.HasRelic("r_heal_wave")) player.Heal(player.maxHp * 0.08f, true);
                Score += 50 * Wave;
            }
            if (player != null && player.alive && player.HasRelic("r_s_senryo")) { player.ryo += 3; Fx.Number(player.pos + new Vector2(0, -60), "+3 両", Gd.C_GOLD, 14f); }
            if (_bossReward) { _bossReward = false; OpenRelics(); return; }
            hud.Banner($"第 {Wave} 波　祓い清め", $"功徳 +{50 * Wave}　HP +6", Gd.C_HP);
            MaybeSpawnShop();
            Sfx.Play("suzu", -10f);
        }

        public void ContinueEndless()
        {
            if (State != GameState.Clear) return;
            endless = true;
            overlay.visible = false;
            State = GameState.Play;
            Time.timeScale = 1f;
            _waveActive = false; _between = 2f;
            Music.Play("stage");
            hud.Banner("祟りの参道", "踏破の先へ。穢れはさらに濃くなる", new Color(1, 0.5f, 0.6f));
            hud.Cutin("dash", new Color(1, 0.5f, 0.6f), 2f);
            Sfx.Play("taiko", -4f, 0.8f);
        }

        // ---------- 生成 ----------

        public void SpawnEnemy(string kind, Vector2 pos)
        {
            Enemy e = null;
            foreach (var x in _enemies) if (!x.Active) { e = x; break; }
            if (e == null)
            {
                var go = new GameObject("enemy");
                go.transform.SetParent(world, false);
                e = go.AddComponent<Enemy>();
                _enemies.Add(e);
            }
            e.Setup(kind, Wave, pos);
        }

        public Bullet SpawnPlayerBullet(Vector2 pos, Vector2 vel, float dmg, Color col, float r, int kind = 0) =>
            Fire(_pBullets, pos, vel, dmg, true, col, r, kind);

        public Bullet SpawnEnemyBullet(Vector2 pos, Vector2 vel, float dmg, float r = 5f, Color? col = null, float homing = 0f, string source = "敵の弾")
        {
            if (EnemyBulletCount >= Enemies.EnemyBulletCap) return null;
            var b = Fire(_eBullets, pos, vel, dmg, false, col ?? Gd.C_EBULLET, r, 7);
            b.homing = homing; b.source = source; b.trailLen = 10f;
            return b;
        }

        /// <summary>魅了された敵が撃つ弾（自機側の弾として飛ぶ）。</summary>
        public Bullet SpawnCharmedBullet(Vector2 pos, Vector2 vel, float dmg)
        {
            var b = Fire(_pBullets, pos, vel, dmg, true, new Color(1f, 0.55f, 0.8f), 5f, 0);
            b.charmed = true; b.kami = ""; b.tag = "charm"; b.trailLen = 12f;
            return b;
        }

        private Bullet Fire(List<Bullet> pool, Vector2 pos, Vector2 vel, float dmg, bool friendly, Color col, float r, int kind)
        {
            Bullet b = null;
            foreach (var x in pool) if (!x.Active) { b = x; break; }
            if (b == null)
            {
                var go = new GameObject(friendly ? "pbullet" : "ebullet");
                go.transform.SetParent(world, false);
                b = go.AddComponent<Bullet>();
                pool.Add(b);
            }
            b.Fire(pos, vel, dmg, friendly, col, r, kind);
            return b;
        }

        public Zone SpawnZone(Vector2 pos, string kind, float r, float life, float dmg, Color col)
        {
            Zone z = null;
            foreach (var x in _zones) if (!x.Active) { z = x; break; }
            if (z == null)
            {
                var go = new GameObject("zone");
                go.transform.SetParent(world, false);
                z = go.AddComponent<Zone>();
                _zones.Add(z);
            }
            z.Setup(pos, kind, r, life, dmg, col);
            return z;
        }

        public void EraseEnemyBulletsNear(Vector2 pos, float r)
        {
            foreach (var b in _eBullets) if (b.Active && Vector2.Distance(b.pos, pos) <= r) b.Vanish("near");
        }
        public void EraseAllEnemyBullets() { foreach (var b in _eBullets) if (b.Active) b.Vanish("call-all"); }

        public Pickup Drop(Vector2 pos, int kind, float value)
        {
            Pickup p = null;
            foreach (var x in _pickups) if (!x.Active) { p = x; break; }
            if (p == null)
            {
                var go = new GameObject("pickup");
                go.transform.SetParent(world, false);
                p = go.AddComponent<Pickup>();
                _pickups.Add(p);
            }
            p.Setup(pos, kind, value);
            return p;
        }

        /// <summary>アイテムが初めて落ちたとき、絵付きで何かを短く案内する。</summary>
        private void ItemHint(int kind)
        {
            if (_seenItems.Contains(kind)) return;
            _seenItems.Add(kind);
            switch (kind)
            {
                case Pickup.XP: hud.Banner("勾玉", "拾うと位が上がる", Gd.C_XP, kind); break;
                case Pickup.HEAL: hud.Banner("団子", "拾うと HP 回復", Gd.C_HP, kind); break;
                case Pickup.ORB: hud.Banner("詠唱の札", "拾うと詠唱を 1 回撃てる（3 枚まで）", player != null && player.MainGod() != "" ? player.KamiColor(player.MainGod()) : new Color(0.8f, 0.85f, 1f), kind); break;
            }
        }

        /// <summary>詠唱の札を落とす（まれなドロップ）。</summary>
        public void DropOrb(Vector2 pos)
        {
            if (State == GameState.Title || player == null) return;
            var p = new Vector2(Mathf.Clamp(pos.x, 16f, Gd.W - 16f), Mathf.Clamp(pos.y, 40f, Gd.H - 60f));
            Drop(p, Pickup.ORB, 1f);
            ItemHint(Pickup.ORB);
            Fx.RingFx(p, player.MainGod() != "" ? player.KamiColor(player.MainGod()) : Color.white, 4f, 26f, 0.3f, 2f);
        }

        private void Collect(Pickup pk)
        {
            switch (pk.kind)
            {
                case Pickup.XP:
                    player.AddXp(pk.value);
                    Sfx.Play("pickup", -22f, Gd.Rand(1f, 1.25f), 0.02f);
                    break;
                case Pickup.HEAL:
                    player.Heal(pk.value, true);
                    Sfx.Play("heal", -12f);
                    break;
                case Pickup.ORB:
                    player.PickOrb();
                    break;
                case Pickup.COIN:
                    player.ryo += Mathf.RoundToInt(pk.value);
                    Sfx.Play("pickup", -16f, Gd.Rand(1.4f, 1.7f), 0.03f);
                    break;
            }
            Fx.Burst(pk.pos, pk.ColorOf(), 5, 110f, 2.5f, 0.28f, true);
            pk.Despawn();
        }

        // ---------- コールバック ----------

        public void OnEnemyKilled(Enemy e)
        {
            if (e is Boss b) { OnBossKilled(b); return; }
            Kills++;
            ComboHit();
            Score += Mathf.RoundToInt(e.score * (1f + 0.1f * comboTier));
            float xpMult = 1f;
            if (player != null && player.Has("susa_p3")) xpMult += player.Val("susa_p3") * 0.01f;
            DropLoot(e.pos, e.xp * xpMult);
            if (player == null || !player.alive) return;
            Combat.OnKill(e);
        }

        // ---------- コンボ ----------

        private void ComboHit()
        {
            combo++;
            comboT = COMBO_WINDOW + Mathf.Min(0.6f, combo * 0.02f);
            comboBest = Mathf.Max(comboBest, combo);
            int tier = 0;
            for (int i = 0; i < ComboNeed.Length; i++) if (combo >= ComboNeed[i]) tier = i + 1;
            if (tier > comboTier)
            {
                comboTier = tier;
                var col = ComboColor;
                hud.ComboCutin(ComboName, col, tier);
                Fx.Flash(Gd.WithA(col, 0.18f + 0.05f * tier), 0.3f);
                if (player != null) { Fx.RingFx(player.pos, col, 20f, 220f + tier * 60f, 0.5f, 5f); Fx.Rays(player.pos, col, 10 + tier * 4, 30f, 360f + tier * 60f, 0.45f); }
                switch (tier)
                {
                    case 1: Sfx.Play("suzu", -8f, 1.3f); break;
                    case 2: Sfx.Play("clap", -6f); Sfx.Play("suzu", -8f, 1.5f); break;
                    case 3: Sfx.Play("taiko", -6f, 1.1f); Sfx.Play("suzu", -6f, 1.6f); Hitstop(0.10f, 0.15f); break;
                    default: Sfx.Play("taiko", -4f, 0.9f); Sfx.Play("flute", -8f, 1.2f); Fx.ShakeAdd(6f); Hitstop(0.14f, 0.12f); break;
                }
            }
        }

        /// <summary>コンボが途切れた：修羅より上なら締めの一声と音、功徳の上乗せ。</summary>
        private void ComboEnd()
        {
            if (comboTier >= 3)
            {
                int bonus = combo * 10 * comboTier;
                Score += bonus;
                hud.Small($"{ComboName}　{combo} 連　功徳 +{bonus}", ComboColor);
                Sfx.Play("taiko", -5f, 0.75f); Sfx.Play("suzu", -10f, 0.9f);
                if (player != null) { Fx.Burst(player.pos, ComboColor, 24, 300f, 4f, 0.6f); Fx.RingFx(player.pos, ComboColor, 30f, 320f, 0.6f, 6f); }
                Fx.Flash(Gd.WithA(ComboColor, 0.2f), 0.4f);
            }
            else if (comboTier >= 1)
            {
                int bonus = combo * 5 * comboTier;
                Score += bonus;
                hud.Small($"{ComboName}　{combo} 連", ComboColor);
                Sfx.Play("suzu", -14f, 0.9f);
            }
            combo = 0; comboTier = 0; comboT = 0f;
        }

        private void DropLoot(Vector2 pos, float xpTotal)
        {
            float chance = Mathf.Clamp((0.30f + xpTotal * 0.03f) * ComboMult, 0.3f, 0.95f);
            if (Random.value < chance) { Drop(pos + new Vector2(Gd.Rand(-6, 6), Gd.Rand(-6, 6)), Pickup.XP, xpTotal / chance * 0.75f); ItemHint(Pickup.XP); }
            if (player != null && player.MainGod() != "")
            {
                float oc = TALISMAN_DROP * player.CostMult("orb") * (player.HasRelic("r_talisman_luck") ? 2f : 1f);
                if (Random.value < oc) DropOrb(pos);
            }
            if (player != null && player.Has("inari_u8") && Random.value < player.Val("inari_u8") * 0.01f)
                Drop(pos + new Vector2(Gd.Rand(-14, 14), Gd.Rand(-8, 8)), Pickup.XP, xpTotal * 0.6f);
            if (Random.value < (player != null && player.HasRelic("r_heal_drop") ? 0.09f : 0.045f) * ComboMult) { Drop(pos, Pickup.HEAL, 12f); ItemHint(Pickup.HEAL); }
            float cc = 0.28f * (player != null && player.HasRelic("r_s_neko") ? 1.5f : 1f) * ComboMult;
            if (Random.value < cc) Drop(pos + new Vector2(Gd.Rand(-10, 10), Gd.Rand(-6, 6)), Pickup.COIN, 1 + Wave / 8 + (Random.value < 0.15f ? 2 : 0));
        }

        private void OnBossKilled(Boss b)
        {
            Kills++;
            Score += (int)b.score;
            boss = null;
            Fx.Puff(b.pos, 40f, 260f, Gd.WithA(Gd.C_BOSS, 0.9f), 0.8f);
            Fx.Burst(b.pos, Gd.C_BOSS, 60, 380f, 6f, 1.1f);
            Fx.ShakeAdd(18f);
            Sfx.Play("boom", 0f);
            if (b.isFinal && !endless)
            {
                Score += 5000;
                Hitstop(1.2f, 0.1f);
                OnCleared();
                return;
            }
            _bossReward = true;
            Music.Play("stage");
            Hitstop(0.9f, 0.12f);
            Fx.Flash(new Color(1, 1, 1, 0.6f), 0.5f);
            hud.Banner("討伐", b.bossName + "　+" + (int)b.score, new Color(1, 0.85f, 0.4f));
            for (int i = 0; i < 10; i++) DropLoot(b.pos + new Vector2(Gd.Rand(-70, 70), Gd.Rand(-70, 70)), b.xp / 10f);
            for (int i = 0; i < 2; i++) Drop(b.pos + new Vector2(Gd.Rand(-50, 50), 0), Pickup.HEAL, 18f);
            for (int i = 0; i < 5; i++) Drop(b.pos + new Vector2(Gd.Rand(-60, 60), Gd.Rand(-30, 30)), Pickup.COIN, 4);
            DropOrb(b.pos);
        }

        // ---------- 神と恩恵 ----------

        private void PauseForChoice(ChoiceKind kind)
        {
            State = GameState.Choice; choice = kind;
            Music.Muffle(true);
            Time.timeScale = 1f; _hitstop = 0f; _freezeT = 0f;
            hud.bannerT = 0f;
        }

        private void CloseChoice()
        {
            ui.HideCards();
            choice = ChoiceKind.None;
            State = GameState.Play;
            Music.Muffle(false);
        }

        private void OpenKamiChoice()
        {
            PauseForChoice(ChoiceKind.Kami);
            if (diag) Debug.Log($"[diag] choice=kami(3択) lv={player.level} gods={player.gods.Count} pending={player.pendingLevels}");
            var ids = BoonsLogic.RollKamiChoices(player, 3);
            if (forceKami != "")
            {   // "susa,suku" のように並べると、その順に主神・副神の先頭候補になる
                foreach (var fk in forceKami.Split(','))
                {
                    if (player.gods.Contains(fk) || Data.KamiOf(fk) == null) continue;
                    ids.Remove(fk); ids.Insert(0, fk); if (ids.Count > 3) ids.RemoveAt(3);
                    break;
                }
            }
            Sfx.Play("descend", -6f);
            ui.ShowKamiChoice(ids, player.gods.Count == 0 ? "主神" : "副神");
        }

        private void OnKamiChosen(string id)
        {
            if (choice != ChoiceKind.Kami) return;
            bool main = player.gods.Count == 0;
            player.AddGod(id);
            if (diag) Debug.Log($"[diag] kami chosen {id} main={main} wave={Wave}");
            var k = Data.KamiOf(id);
            var col = Data.ColorOf(k.color);
            Sfx.Play("descend", -4f, main ? 1.2f : 1.3f);
            Fx.Flash(Gd.WithA(col, main ? 0.5f : 0.4f), 0.5f);
            if (main) hud.Banner(k.weapon + " を授かった", k.weapon_desc, col);
            else hud.Banner(k.name + " が副神となった", k.weapon + " が加わった", col);
            player.pendingLevels = Mathf.Max(0, player.pendingLevels - 1);
            CloseChoice();
        }

        private void OpenBoons(string reason, int minRar, string kamiId)
        {
            PauseForChoice(ChoiceKind.Boon);
            if (diag) Debug.Log($"[diag] choice=boons lv={player.level} gods={player.gods.Count} kami={kamiId}");
            _offerReason = reason; _offerMinRar = minRar; _rerolls = 1;
            string kid = kamiId != "" ? kamiId : BoonsLogic.PickKami(player);
            if (kid == "") { player.pendingLevels = Mathf.Max(0, player.pendingLevels - 1); CloseChoice(); return; }
            _offerKami = kid;
            _offers = BoonsLogic.MakeOfferSplit(player, kid, minRar);
            if (forceBoon != "" && !player.Has(forceBoon))
            {   // ?boon=xxx：その恩恵を上段の先頭に（検証用。autoplay は先頭を選ぶ）
                int fi = _offers.FindIndex(o => o != null && o.Id == forceBoon);
                if (fi > 0 && fi < 3) { var o = _offers[fi]; _offers.RemoveAt(fi); _offers.Insert(0, o); }
                else if (fi < 0) { var def = Data.Boon(forceBoon); if (def != null && def.kami == kid) { _offers.RemoveAt(2); _offers.Insert(0, new Offer { type = "upgrade", boon = def, kami = kid, rar = def.tier ?? Mathf.Max(minRar, 1) }); } }
            }
            if (!_offers.Any(o => BoonsLogic.CanTake(player, o))) { player.pendingLevels = Mathf.Max(0, player.pendingLevels - 1); CloseChoice(); return; }
            Sfx.Play("levelup", -8f);
            ui.ShowBoons(kid, _offers, _rerolls, "神との邂逅");
        }

        private void OnReroll()
        {
            if (choice != ChoiceKind.Boon || _rerolls <= 0) return;
            _rerolls--;
            Sfx.Play("clap", -6f);
            _offers = BoonsLogic.MakeOfferSplit(player, _offerKami, _offerMinRar);
            ui.ShowBoons(_offerKami, _offers, _rerolls, ui.boons.title);
        }

        private void OnBoonChosen(int idx)
        {
            if (choice != ChoiceKind.Boon || idx < 0 || idx >= _offers.Count) return;
            var o = _offers[idx];
            if (!BoonsLogic.CanTake(player, o)) { Sfx.Play("clap", -16f, 0.7f); return; }
            BoonsLogic.Take(player, o);
            if (o.type == "curse") { hud.Banner(o.curse.name, o.curse.desc, new Color(1, 0.4f, 0.5f)); Sfx.Play("doom", -8f, 0.8f); }
            else
            {
                var col = Data.ColorOf(RarityTable.Colors[o.rar]);
                var cur = player.boons[o.boon.id];
                hud.Banner(o.boon.name, Boons.Describe(o.boon, cur.rar, cur.lv), col);
                Sfx.Play("suzu", -6f);
            }
            if (_offerReason == "level") player.pendingLevels = Mathf.Max(0, player.pendingLevels - 1);
            CloseChoice();
        }

        /// <summary>レベルアップ：強化する神を選ぶ → その神の神格が 1 上がる → その神の能力 3 枚を抽選。</summary>
        private void OpenLevelPick()
        {
            if (player.gods.Count == 0) { LevelPickDone(""); return; }
            if (diag) Debug.Log($"[diag] choice=triangle(神を選ぶ) lv={player.level} gods={player.gods.Count} pending={player.pendingLevels}");
            PauseForChoice(ChoiceKind.Miki);
            Sfx.Play("levelup", -8f);
            ui.ShowMiki(new List<string>(player.gods));
        }

        private void LevelPickDone(string id)
        {
            if (id != "" && player.KamiLv(id) < 10) BoonsLogic.MikiApply(player, id);
            OpenBoons("level", (int)Rarity.Common, id);
        }

        private void OnMikiChosen(string id)
        {
            if (choice != ChoiceKind.Miki) return;
            Sfx.Play("suzu", -8f, 1.2f);
            LevelPickDone(id);
        }

        // ---------- 市 ----------

        /// <summary>波を越えたあと、段ごとに 1 回だけ稀に屋台が流れてくる。ボスの 2 つ前の波までに出なければそこで出す。</summary>
        private void MaybeSpawnShop()
        {
            if (player == null || !player.alive || Stages.IsBossWave(Wave + 1)) return;
            int stg = Stages.StageOf(Wave);
            bool must = (Wave % Stages.StageLen) == Stages.StageLen - 2;
            if (!forceShop && (_shopStages.Contains(stg) || Wave < 2 || (!must && Random.value > 0.28f))) return;
            _shopStages.Add(stg);
            stall.Spawn(new Vector2(Gd.Rand(140f, Gd.W - 140f), -70f));
            hud.Banner("市が来た", "触れると入れる", Gd.C_GOLD);
            Sfx.Play("suzu", -6f, 1.4f);
        }

        private void OpenShop()
        {
            PauseForChoice(ChoiceKind.Shop);
            _shop.Clear();
            var items = Data.ShopItems;
            var heals = items.Where(i => i.kind == "heal" || i.kind == "maxhp").ToList();
            var timed = items.Where(i => i.kind != "heal" && i.kind != "maxhp").ToList();
            if (heals.Count > 0) { var it = heals[Random.Range(0, heals.Count)]; _shop.Add(new ShopOffer { type = "item", item = it, price = it.price }); }
            if (timed.Count > 0) { var it = timed[Random.Range(0, timed.Count)]; _shop.Add(new ShopOffer { type = "item", item = it, price = it.price }); }
            var pool = Data.Relics.Where(r => r.shop && !player.relics.Contains(r.id)).ToList();
            for (int k = 0; k < 3 && pool.Count > 0; k++)
            {
                // 格ごとの重み：並 55 / 稀 33 / 秘 12
                float total = 0f; foreach (var r in pool) total += RarWeight(r.rar);
                float roll = Random.value * total; RelicDef pick = pool[pool.Count - 1];
                foreach (var r in pool) { roll -= RarWeight(r.rar); if (roll <= 0f) { pick = r; break; } }
                pool.Remove(pick);
                _shop.Add(new ShopOffer { type = "relic", relic = pick, price = pick.price });
            }
            Sfx.Play("suzu", -6f, 1.2f);
            ui.ShowShop(_shop, player.ryo);
        }
        private static float RarWeight(int rar) => rar >= 3 ? 0.12f : rar == 2 ? 0.33f : 0.55f;

        private void OnShopBuy(int idx)
        {
            if (choice != ChoiceKind.Shop || idx < 0 || idx >= _shop.Count) return;
            var o = _shop[idx];
            if (o.sold || player.ryo < o.price) { Sfx.Play("clap", -16f, 0.7f); return; }
            player.ryo -= o.price; o.sold = true;
            if (o.type == "item") player.UseShopItem(o.item);
            else { player.relics.Add(o.relic.id); player.OnBoonsChanged(); Sfx.Play("levelup", -6f, 1.1f); }
            ui.shop.ryo = player.ryo;
            Fx.Flash(Gd.WithA(Gd.C_GOLD, 0.25f), 0.3f);
        }

        private void OnShopLeave()
        {
            if (choice != ChoiceKind.Shop) return;
            Sfx.Play("clap", -12f);
            CloseChoice();
        }

        private void OpenRelics()
        {
            _relicOffers = BoonsLogic.OfferRelics(player, 3);
            if (_relicOffers.Count == 0) { player.Heal(player.maxHp * 0.5f, true); hud.Banner("討伐の褒賞", "HP を回復した", Gd.C_GOLD); return; }
            PauseForChoice(ChoiceKind.Relic);
            Sfx.Play("levelup", -6f, 0.9f);
            ui.ShowRelics(_relicOffers);
        }

        private void OnRelicChosen(int idx)
        {
            if (choice != ChoiceKind.Relic || idx < 0 || idx >= _relicOffers.Count) return;
            var r = _relicOffers[idx];
            player.relics.Add(r.id);
            player.OnBoonsChanged();
            hud.Banner(r.name, r.desc, Gd.C_GOLD);
            Sfx.Play("levelup", -4f, 1.1f);
            Fx.Flash(Gd.WithA(Gd.C_GOLD, 0.35f), 0.4f);
            _relicOffers = new List<RelicDef>();
            CloseChoice();
        }

        // ---------- 結果 ----------

        private void OnCleared()
        {
            State = GameState.Clear;
            _waveActive = false;
            Fx.Flash(new Color(1, 1, 1, 0.8f), 1f);
            Sfx.Play("flute", 0f); Sfx.Play("suzu", -4f); Sfx.Play("levelup", -4f);
            SaveBest(true);
            overlay.mode = 2;
            var godNames = player.gods.Select(g => Data.KamiOf(g).name).ToList();
            overlay.statsLines = new List<(string, string)>
            {
                ("功徳", Score.ToString()),
                ("位", "Lv." + player.level),
                ("討伐", Kills.ToString()),
                ("神々", godNames.Count > 0 ? string.Join("・", godNames) : "なし"),
                ("神格", player.gods.Count > 0 ? string.Join("・", player.gods.Select(g => "Lv." + player.KamiLv(g))) : "なし"),
            };
            ui.HideCards();
            _overlayDelay = 2.4f;
        }

        public void OnLeveledUp()
        {
            Sfx.Play("suzu", -10f, 1.2f);
            Fx.RingFx(PlayerPos, Gd.C_GOLD, 10f, 120f, 0.5f, 4f);
            Fx.Flash(Gd.WithA(Gd.C_GOLD, 0.25f), 0.3f);
        }

        public void OnPlayerHit() { }

        public void OnPlayerDied()
        {
            combo = 0; comboTier = 0; comboT = 0f;
            Music.Stop();
            State = GameState.Over;
            Time.timeScale = 1f; _hitstop = 0f;
            SaveBest(false);
            overlay.mode = 1;
            var godNames = player.gods.Select(g => Data.KamiOf(g).name).ToList();
            float total = 0f, bestV = 0f; string best = "";
            foreach (var kv in player.kamiDmg) { total += kv.Value; if (kv.Value > bestV) { bestV = kv.Value; best = kv.Key; } }
            string mvp = "なし";
            if (best != "" && total > 0f) mvp = Data.KamiOf(best).weapon + "（" + Mathf.RoundToInt(bestV / total * 100f) + "%）";
            overlay.statsLines = new List<(string, string)>
            {
                ("到達", "第" + Gd.STAGE_KANJI[Stages.StageOf(Mathf.Max(Wave, 1)) - 1] + "の段　第 " + Wave + " 波"),
                ("功徳", Score.ToString()),
                ("討たれた相手", player.lastHitBy != "" ? player.lastHitBy : "不明"),
                ("最も働いた神器", mvp),
                ("神々", godNames.Count > 0 ? string.Join("・", godNames) : "なし"),
            };
            overlay.tip = DeathTip();
            ui.HideCards();
            _overlayDelay = 1.3f;
        }

        private string DeathTip()
        {
            if (player.gods.Count == 0) return "神を迎える前に倒れた。勾玉を優先して拾い、位を上げよう";
            if (player.gods.Count < 3) return "副神の枠が空いていた。位 4 と位 6 で副神を迎えると神器が増え、火力が伸びる";
            if (player.lastHitBy.EndsWith("体当たり")) return "体当たりで倒れた。疾走（短くなぞる／Space）の無敵で抜けよう";
            return "神格は神器を当てるほど上がる。主神の神器が当たる位置取りを意識しよう";
        }

        /// <summary>今回の走りを記録に刻む（名前・功徳・到達・神々）。順位を結果画面に渡す。</summary>
        private void SaveBest(bool cleared)
        {
            var e = new Records.Entry
            {
                run = runId, score = Score, wave = Wave, lv = player.level, gods = string.Join(",", player.gods), cleared = cleared, endless = endless,
                duration = runDuration, familiar = player.familiarId, relics = string.Join(",", player.relics),
                boons = string.Join(",", player.boons.Where(kv => Data.Curse(kv.Key) == null).Select(kv => kv.Key + ":" + kv.Value.lv + ":" + kv.Value.rar)),
                runKey = runKey, stage = Stages.StageOf(Mathf.Max(Wave, 1)),
                kamiLv = string.Join(",", player.gods.Select(g => g + ":" + player.KamiLv(g))),
                curses = string.Join(",", player.boons.Keys.Where(k => Data.Curse(k) != null)),
            };
            overlay.rank = Records.Record(e);
            SubmitGlobal();
        }

        /// <summary>世界のランキングへ送り、順位を結果画面に出す。</summary>
        private void SubmitGlobal()
        {
            overlay.globalRank = 0;
            if (net == null || !net.Configured || !BuildInfo.CanSubmit || Records.LastEntry == null || GetComponent<Autoplay>() != null) return;   // 自動プレイの記録は世界に送らない
            overlay.globalRank = -1;
            var entry = Records.LastEntry;
            net.Submit(entry, ok =>
            {
                if (!ok) { overlay.globalRank = -2; return; }
                net.FetchRank(entry.score, (ok2, rank) => overlay.globalRank = ok2 ? rank : -2);
            });
        }

        /// <summary>名を刻む：Web はブラウザの入力ダイアログ。</summary>
        private void NamePrompt()
        {
            Sfx.Play("select", -10f);
            string r = Net.Prompt("巫女の名（10 文字まで）", Records.PlayerName);
            if (r == null) { if (!Application.isMobilePlatform && Application.platform != RuntimePlatform.WebGLPlayer) hud.Small("名の刻印はブラウザ版で", new Color(0.9f, 0.9f, 1f)); return; }
            OnNameSubmitted(r);
        }

        private void OnNameSubmitted(string n)
        {
            int rid = State == GameState.Title ? -1 : runId;
            Records.SetPlayerName(n, rid);
            Sfx.Play("suzu", -8f);
            Fx.Sparks(new Vector2(Gd.W * 0.5f, Gd.H * 0.5f), Vector2.up, Gd.C_GOLD, 8, 200f);
            var last = Records.LastEntry;
            if (net != null && net.Configured && last != null && last.run == runId && State != GameState.Title && GetComponent<Autoplay>() == null)
            {
                last.name = Records.DisplayName();
                net.Submit(last, ok => { });
            }
        }
    }
}
