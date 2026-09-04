using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>BGM。ステージ曲・ボス曲・ラスボス曲を 3 本の AudioSource でクロスフェードする（Godot 版 music.gd の移植）。</summary>
    public class Music : MonoBehaviour
    {
        public static Music I;
        public const float BaseDb = -9f;
        public const float Fade = 1.6f;
        public bool muted;

        private static readonly string[] Tracks = { "title", "stage", "boss", "lastboss" };
        private readonly Dictionary<string, AudioSource> _players = new Dictionary<string, AudioSource>();
        private readonly Dictionary<string, float> _target = new Dictionary<string, float>();
        private readonly Dictionary<string, float> _level = new Dictionary<string, float>();
        private string _current = "";
        private float _duck;
        private AudioLowPassFilter _lpf;
        private float _muffle, _muffleTarget;   // 選択画面・一時停止中はこもった音にする（0..1）

        public string Current => _current;

        public static Music Create(Transform parent)
        {
            var go = new GameObject("music");
            go.transform.SetParent(parent, false);
            var m = go.AddComponent<Music>();
            foreach (var name in Tracks)
            {
                var a = go.AddComponent<AudioSource>();
                a.clip = Resources.Load<AudioClip>("Music/" + name);
                a.loop = true;
                a.playOnAwake = false;
                a.volume = 0f;
                m._players[name] = a;
                m._target[name] = 0f;
                m._level[name] = 0f;
            }
            m._lpf = go.AddComponent<AudioLowPassFilter>();
            m._lpf.cutoffFrequency = 22000f;
            I = m;
            return m;
        }

        private void Update()
        {
            float delta = Time.unscaledDeltaTime;
            _duck = Mathf.Max(0f, _duck - delta);
            _muffle = Mathf.MoveTowards(_muffle, _muffleTarget, delta * 3f);
            if (_lpf != null) _lpf.cutoffFrequency = Mathf.Lerp(22000f, 900f, _muffle);
            foreach (var name in Tracks)
            {
                var p = _players[name];
                float tgt = muted ? 0f : _target[name];
                if (_duck > 0f) tgt *= 0.35f;
                float cur = Mathf.MoveTowards(_level[name], tgt, delta / Fade);
                _level[name] = cur;
                if (cur <= 0.001f)
                {
                    if (p.isPlaying && tgt <= 0f) p.Stop();
                    continue;
                }
                if (!p.isPlaying && p.clip != null) p.Play();
                // 0..1 を dB に（対数で自然なフェード）
                float db = BaseDb + 20f * Mathf.Log10(Mathf.Max(cur, 0.001f));
                p.volume = Mathf.Pow(10f, db / 20f) * Audio.BgmGain;
            }
        }

        public static void Play(string name)
        {
            if (I == null || !I._players.ContainsKey(name)) return;
            if (I._current == name) return;
            I._current = name;
            foreach (var k in Tracks) I._target[k] = k == name ? 1f : 0f;
        }

        public static void Stop()
        {
            if (I == null) return;
            I._current = "";
            foreach (var k in Tracks) I._target[k] = 0f;
        }

        /// <summary>選択画面・一時停止：曲をこもらせる（Unity の AudioLowPassFilter）。</summary>
        public static void Muffle(bool on) { if (I != null) I._muffleTarget = on ? 1f : 0f; }

        public static void Duck(float sec)
        {
            if (I != null) I._duck = Mathf.Max(I._duck, sec);
        }
    }
}
