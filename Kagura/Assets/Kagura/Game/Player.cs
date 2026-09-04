using UnityEngine;
using UnityEngine.InputSystem;

namespace Kagura.Game
{
    /// <summary>自機。キーボード（WASD / 矢印）か、指のドラッグで動く。巫矢は自動で撃つ。</summary>
    public class Player : MonoBehaviour
    {
        public float speed = 3.4f;          // 単位/秒（Godot 版 340px/s）
        public float touchSens = 0.7f;      // 指の移動に対する倍率（Godot 版 Cfg.TOUCH_SENS）
        public float maxHp = 100f;
        public float hp = 100f;
        public float radius = 0.10f;        // 当たり判定（Godot 版 10px）
        public float fireInterval = 0.16f;
        public float bulletDamage = 10f;
        public float invincible;            // 被弾後の無敵（残り秒）

        private float _fireT;
        private Vector2 _lastTouch;
        private bool _touching;
        private SpriteRenderer _body;
        private SpriteRenderer _glow;

        private void Awake()
        {
            _body = gameObject.AddComponent<SpriteRenderer>();
            _body.sprite = SpriteFactory.Diamond();
            _body.color = new Color(0.82f, 0.62f, 1f);
            _body.sortingOrder = 12;
            transform.localScale = Vector3.one * 0.55f;
            var g = new GameObject("glow");
            g.transform.SetParent(transform, false);
            g.transform.localScale = Vector3.one * 2.4f;
            _glow = g.AddComponent<SpriteRenderer>();
            _glow.sprite = SpriteFactory.Glow();
            _glow.color = new Color(0.6f, 0.4f, 1f, 0.35f);
            _glow.sortingOrder = 11;
        }

        private void Update()
        {
            var g = GameManager.I;
            if (g == null || g.State != GameState.Play) return;
            float dt = Time.deltaTime;
            invincible = Mathf.Max(0f, invincible - dt);

            // 移動
            Vector2 move = Vector2.zero;
            var kb = Keyboard.current;
            if (kb != null)
            {
                if (kb.aKey.isPressed || kb.leftArrowKey.isPressed) move.x -= 1f;
                if (kb.dKey.isPressed || kb.rightArrowKey.isPressed) move.x += 1f;
                if (kb.wKey.isPressed || kb.upArrowKey.isPressed) move.y += 1f;
                if (kb.sKey.isPressed || kb.downArrowKey.isPressed) move.y -= 1f;
            }
            Vector3 pos = transform.position;
            pos += (Vector3)(move.normalized * speed * dt);

            var ts = Touchscreen.current;
            if (ts != null && ts.primaryTouch.press.isPressed)
            {
                Vector2 p = ts.primaryTouch.position.ReadValue();
                if (_touching)
                {
                    Vector2 d = (p - _lastTouch) / GameManager.I.PixelsPerUnit * touchSens;
                    pos += (Vector3)d;
                }
                _lastTouch = p;
                _touching = true;
            }
            else
            {
                _touching = false;
                var ms = Mouse.current;
                if (ms != null && ms.leftButton.isPressed)
                {
                    Vector2 p = ms.position.ReadValue();
                    if (_mouseDown) pos += (Vector3)((p - _lastMouse) / GameManager.I.PixelsPerUnit * touchSens);
                    _lastMouse = p; _mouseDown = true;
                }
                else _mouseDown = false;
            }

            var b = g.Bounds;
            pos.x = Mathf.Clamp(pos.x, b.xMin + 0.2f, b.xMax - 0.2f);
            pos.y = Mathf.Clamp(pos.y, b.yMin + 0.3f, b.yMax - 0.6f);
            transform.position = pos;

            // 自動射撃
            _fireT -= dt;
            if (_fireT <= 0f)
            {
                _fireT = fireInterval;
                g.SpawnPlayerBullet(pos + new Vector3(0, 0.2f, 0), new Vector2(0, 9f), bulletDamage);
            }

            _glow.color = new Color(0.6f, 0.4f, 1f, invincible > 0f ? 0.15f + 0.3f * Mathf.PingPong(Time.time * 8f, 1f) : 0.35f);
        }

        private Vector2 _lastMouse;
        private bool _mouseDown;

        public void Hit(float dmg)
        {
            if (invincible > 0f) return;
            hp -= dmg;
            invincible = 0.9f;
            GameManager.I.OnPlayerHit();
            if (hp <= 0f) GameManager.I.OnPlayerDied();
        }
    }
}
