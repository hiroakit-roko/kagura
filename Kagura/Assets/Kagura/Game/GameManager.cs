using System.Collections.Generic;
using UnityEngine;
using Kagura.Core;

namespace Kagura.Game
{
    public enum GameState { Title, Play, Over, Clear }

    /// <summary>
    /// ゲーム全体の進行。波の生成（Kagura.Core.WaveBuilder）、弾と敵の使い回し、当たり判定。
    /// 座標は 1 単位 = Godot 版 100px。画面は横 6.4 単位で固定し、縦は端末に合わせて伸びる。
    /// </summary>
    public class GameManager : MonoBehaviour
    {
        public static GameManager I;

        public GameState State = GameState.Title;
        public int Wave;
        public int Score;
        public int Kills;
        public Player player;
        public Rect Bounds;                 // 見えている範囲（単位）
        public float PixelsPerUnit = 100f;  // 画面ピクセル → 単位

        private readonly List<Bullet> _pBullets = new List<Bullet>();
        private readonly List<Bullet> _eBullets = new List<Bullet>();
        private readonly List<Enemy> _enemies = new List<Enemy>();
        private List<SpawnEntry> _plan = new List<SpawnEntry>();
        private int _planI;
        private float _waveT, _between = 1.2f;
        private bool _waveActive;
        private IRng _rng;
        private Transform _world;
        private Camera _cam;
        public Hud hud;

        public Vector3 PlayerPos => player != null ? player.transform.position : Vector3.zero;
        public int EnemyCount { get { int n = 0; foreach (var e in _enemies) if (e.Active) n++; return n; } }
        public int EnemyBulletCount { get { int n = 0; foreach (var b in _eBullets) if (b.Active) n++; return n; } }

        private void Awake()
        {
            I = this;
            Application.targetFrameRate = 60;
            _cam = Camera.main;
            _world = new GameObject("world").transform;
            _rng = new SystemRng(System.Environment.TickCount);
            FitCamera();
        }

        private void Start()
        {
            hud?.ShowTitle(true);
        }

        /// <summary>横 6.4 単位を画面幅に合わせる。縦長端末では縦が伸びる。</summary>
        private void FitCamera()
        {
            if (_cam == null) return;
            _cam.orthographic = true;
            float aspect = (float)Screen.width / Mathf.Max(1, Screen.height);
            float halfW = 3.2f;
            float halfH = Mathf.Max(halfW / aspect, 4.8f);
            _cam.orthographicSize = halfH;
            _cam.transform.position = new Vector3(0, 0, -10);
            Bounds = new Rect(-halfW, -halfH, halfW * 2f, halfH * 2f);
            PixelsPerUnit = Screen.height / (halfH * 2f);
        }

        public void StartGame()
        {
            foreach (var e in _enemies) e.Despawn();
            foreach (var b in _pBullets) b.Vanish();
            foreach (var b in _eBullets) b.Vanish();
            if (player == null)
            {
                var go = new GameObject("player");
                go.transform.SetParent(_world, false);
                player = go.AddComponent<Player>();
            }
            player.hp = player.maxHp;
            player.transform.position = new Vector3(0, Bounds.yMin + 2.0f, 0);
            player.gameObject.SetActive(true);
            Wave = 0; Score = 0; Kills = 0;
            _waveActive = false; _between = 1.2f; _plan.Clear(); _planI = 0;
            State = GameState.Play;
            hud?.ShowTitle(false);
        }

        private void Update()
        {
            if (Screen.width != _lastW || Screen.height != _lastH) { _lastW = Screen.width; _lastH = Screen.height; FitCamera(); }
            if (State != GameState.Play)
            {
                if (UnityEngine.InputSystem.Keyboard.current != null && UnityEngine.InputSystem.Keyboard.current.enterKey.wasPressedThisFrame) StartGame();
                if (UnityEngine.InputSystem.Touchscreen.current != null && UnityEngine.InputSystem.Touchscreen.current.primaryTouch.press.wasPressedThisFrame) StartGame();
                if (UnityEngine.InputSystem.Mouse.current != null && UnityEngine.InputSystem.Mouse.current.leftButton.wasPressedThisFrame) StartGame();
                return;
            }
            float dt = Time.deltaTime;

            // 波の進行
            if (!_waveActive)
            {
                _between -= dt;
                if (_between <= 0f) StartWave();
            }
            else
            {
                _waveT += dt;
                while (_planI < _plan.Count && _plan[_planI].T <= _waveT)
                {
                    if (EnemyCount >= Enemies.EnemyCap) break;
                    var s = _plan[_planI]; _planI++;
                    // Godot 座標（px、上が 0）→ 単位（中央原点、上が +）
                    var pos = new Vector3(s.X / 100f - 3.2f, Bounds.yMax - s.Y / 100f, 0);
                    Spawn(s.Kind, pos);
                }
                if (_planI >= _plan.Count && EnemyCount == 0) ClearWave();
            }

            // 弾と敵の更新・当たり
            var pp = PlayerPos;
            foreach (var b in _pBullets) if (b.Active) b.Tick(dt, Bounds);
            foreach (var b in _eBullets) if (b.Active) b.Tick(dt, Bounds);
            foreach (var e in _enemies)
            {
                if (!e.Active) continue;
                e.Tick(dt, this);
                if (!e.Active) continue;
                // 自機の弾
                foreach (var b in _pBullets)
                {
                    if (!b.Active) continue;
                    float r = b.radius + e.radius;
                    if (((Vector2)(b.transform.position - e.transform.position)).sqrMagnitude <= r * r)
                    {
                        b.Vanish();
                        if (e.TakeDamage(b.damage)) { OnEnemyKilled(e); break; }
                    }
                }
                if (!e.Active) continue;
                // 体当たり
                float rr = e.radius + player.radius;
                if (((Vector2)(e.transform.position - pp)).sqrMagnitude <= rr * rr) player.Hit(12f);
            }
            foreach (var b in _eBullets)
            {
                if (!b.Active) continue;
                float r = b.radius + player.radius;
                if (((Vector2)(b.transform.position - pp)).sqrMagnitude <= r * r) { b.Vanish(); player.Hit(b.damage); }
            }
            hud?.Refresh(this);
        }

        private int _lastW, _lastH;

        private void StartWave()
        {
            Wave++;
            _waveT = 0f; _planI = 0; _waveActive = true;
            if (Stages.IsBossWave(Wave))
            {
                // ボスは未移植：代わりに小鬼を多めに出して波を成立させる
                _plan = new List<SpawnEntry>();
                for (int i = 0; i < 4; i++) _plan.Add(new SpawnEntry { Kind = "oni", X = 640f * (i + 1) / 5f, Y = -46f - i * 30f, T = 0.5f + i * 0.4f });
                hud?.Banner($"第 {Wave} 波　大妖（仮）");
            }
            else
            {
                _plan = WaveBuilder.Build(Wave, _rng);
                hud?.Banner($"第 {Wave} 波");
            }
        }

        private void ClearWave()
        {
            _waveActive = false;
            _between = 1.5f;
            Score += 50 * Wave;
            if (player != null) player.hp = Mathf.Min(player.maxHp, player.hp + 6f);
            if (Stages.IsFinalWave(Wave)) { State = GameState.Clear; hud?.ShowOver(true, this); }
        }

        private void Spawn(string kind, Vector3 pos)
        {
            Enemy e = null;
            foreach (var x in _enemies) if (!x.Active) { e = x; break; }
            if (e == null)
            {
                var go = new GameObject("enemy");
                go.transform.SetParent(_world, false);
                e = go.AddComponent<Enemy>();
                _enemies.Add(e);
            }
            e.Setup(kind, Wave, pos);
        }

        public void SpawnPlayerBullet(Vector3 pos, Vector2 vel, float dmg) =>
            Fire(_pBullets, pos, vel, dmg, true, new Color(0.9f, 0.8f, 1f), 0.05f);

        public void SpawnEnemyBullet(Vector3 pos, Vector2 vel, float dmg, Color col)
        {
            if (EnemyBulletCount >= Enemies.EnemyBulletCap) return;
            Fire(_eBullets, pos, vel, dmg, false, col, 0.05f);
        }

        private void Fire(List<Bullet> pool, Vector3 pos, Vector2 vel, float dmg, bool friendly, Color col, float r)
        {
            Bullet b = null;
            foreach (var x in pool) if (!x.Active) { b = x; break; }
            if (b == null)
            {
                var go = new GameObject(friendly ? "pbullet" : "ebullet");
                go.transform.SetParent(_world, false);
                b = go.AddComponent<Bullet>();
                pool.Add(b);
            }
            b.Fire(pos, vel, dmg, friendly, col, r);
        }

        private void OnEnemyKilled(Enemy e)
        {
            Kills++;
            Score += (int)e.score;
        }

        public void OnPlayerHit() { }

        public void OnPlayerDied()
        {
            State = GameState.Over;
            hud?.ShowOver(false, this);
        }
    }
}
