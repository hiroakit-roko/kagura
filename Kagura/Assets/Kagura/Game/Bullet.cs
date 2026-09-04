using UnityEngine;

namespace Kagura.Game
{
    /// <summary>弾（自機・敵の両方）。物理は使わず GameManager が距離で当たりを取る。使い回し前提。</summary>
    public class Bullet : MonoBehaviour
    {
        public Vector2 vel;
        public float damage;
        public float radius = 0.05f;
        public bool friendly;
        public float life = 4f;
        public bool Active;

        private SpriteRenderer _sr;
        private SpriteRenderer _glow;

        private void Awake()
        {
            _sr = gameObject.AddComponent<SpriteRenderer>();
            var g = new GameObject("glow");
            g.transform.SetParent(transform, false);
            _glow = g.AddComponent<SpriteRenderer>();
            _glow.sprite = SpriteFactory.Glow();
        }

        public void Fire(Vector3 pos, Vector2 v, float dmg, bool isFriendly, Color col, float r)
        {
            transform.position = pos;
            vel = v; damage = dmg; friendly = isFriendly; radius = r; life = isFriendly ? 2.5f : 6f;
            Active = true;
            gameObject.SetActive(true);
            _sr.sprite = isFriendly ? SpriteFactory.Capsule() : SpriteFactory.Circle();
            _sr.color = col;
            _sr.sortingOrder = isFriendly ? 6 : 7;
            _glow.sortingOrder = _sr.sortingOrder - 1;
            _glow.color = new Color(col.r, col.g, col.b, 0.55f);
            float s = r * 2f * 2.0f;   // 絵の直径 = 当たりの 2 倍
            transform.localScale = Vector3.one * s;
            _glow.transform.localScale = Vector3.one * 3.2f;
            transform.rotation = Quaternion.Euler(0, 0, Mathf.Atan2(v.y, v.x) * Mathf.Rad2Deg - 90f);
        }

        public void Tick(float dt, Rect bounds)
        {
            life -= dt;
            transform.position += (Vector3)(vel * dt);
            var p = transform.position;
            if (life <= 0f || p.x < bounds.xMin - 0.6f || p.x > bounds.xMax + 0.6f || p.y < bounds.yMin - 0.6f || p.y > bounds.yMax + 1.2f)
                Vanish();
        }

        public void Vanish()
        {
            Active = false;
            gameObject.SetActive(false);
        }
    }
}
