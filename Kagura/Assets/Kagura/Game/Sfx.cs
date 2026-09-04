using System;
using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>効果音を起動時に合成する（Godot 版 sfx.gd の移植。数式は同じ）。</summary>
    public class Sfx : MonoBehaviour
    {
        public const int SR = 22050;
        public static Sfx I;
        public bool muted;

        private readonly Dictionary<string, AudioClip> _bank = new Dictionary<string, AudioClip>();
        private readonly List<AudioSource> _players = new List<AudioSource>();
        private readonly Dictionary<string, float> _last = new Dictionary<string, float>();
        private int _idx;
        // 実録サンプル（Kenney CC0）を合成音に重ねる：名前 → (Resources/Sfx のファイル名の頭, 本数, 相対 dB)
        private static readonly Dictionary<string, (string prefix, int n, float db)> Layers = new Dictionary<string, (string, int, float)>
        {
            { "explode", ("explosionCrunch_00", 5, -8f) }, { "boom", ("lowFrequency_explosion_00", 2, -2f) },
            { "hit_heavy", ("impactMetal_heavy_00", 5, -10f) }, { "hurt", ("impactPunch_heavy_00", 5, -4f) },
            { "shield", ("impactBell_heavy_00", 5, -8f) }, { "deflect", ("impactMetal_light_00", 5, -8f) },
            { "hit_ice", ("impactGlass_heavy_00", 5, -10f) }, { "dash", ("cloth", 4, -6f) }, { "levelup", ("impactBell_heavy_00", 5, -12f) },
        };
        private readonly Dictionary<string, AudioClip[]> _layerClips = new Dictionary<string, AudioClip[]>();
        private static readonly System.Random _rng = new System.Random(12345);

        public static Sfx Create(Transform parent)
        {
            var go = new GameObject("sfx");
            go.transform.SetParent(parent, false);
            var s = go.AddComponent<Sfx>();
            for (int i = 0; i < 28; i++)
            {
                var a = go.AddComponent<AudioSource>();
                a.playOnAwake = false;
                s._players.Add(a);
            }
            s.BuildBank();
            foreach (var kv in Layers)
            {
                var arr = new AudioClip[kv.Value.n];
                for (int i = 0; i < kv.Value.n; i++) arr[i] = Resources.Load<AudioClip>("Sfx/" + kv.Value.prefix + (kv.Value.prefix == "cloth" ? (i + 1).ToString() : i.ToString()));
                s._layerClips[kv.Key] = arr;
            }
            int loaded = 0, total = 0;
            foreach (var arr in s._layerClips.Values) foreach (var c in arr) { total++; if (c != null) loaded++; }
            Debug.Log("[Kagura] sfx layers loaded " + loaded + "/" + total);
            I = s;
            return s;
        }

        public static void Play(string name, float volDb = 0f, float pitch = 1f, float minGap = 0f)
        {
            if (I != null) I.PlayInternal(name, volDb, pitch, minGap);
        }

        private void PlayInternal(string name, float volDb, float pitch, float minGap)
        {
            if (muted || !_bank.TryGetValue(name, out var clip)) return;
            float gain = Audio.SfxGain;
            if (gain <= 0f) return;
            float now = Time.realtimeSinceStartup;
            if (minGap > 0f && _last.TryGetValue(name, out var last) && now - last < minGap) return;
            _last[name] = now;
            var p = _players[_idx];
            _idx = (_idx + 1) % _players.Count;
            p.clip = clip;
            p.volume = Mathf.Pow(10f, volDb / 20f) * gain;
            p.pitch = pitch;
            p.Play();
            if (_layerClips.TryGetValue(name, out var layer))
            {
                var lc = layer[UnityEngine.Random.Range(0, layer.Length)];
                if (lc != null)
                {
                    var q = _players[_idx];
                    _idx = (_idx + 1) % _players.Count;
                    q.clip = lc;
                    q.volume = Mathf.Pow(10f, (volDb + Layers[name].db) / 20f) * gain;
                    q.pitch = pitch * UnityEngine.Random.Range(0.94f, 1.06f);
                    q.Play();
                }
            }
        }

        private static float Rand() => (float)(_rng.NextDouble() * 2.0 - 1.0);
        private static float Lerp(float a, float b, float t) => a + (b - a) * t;
        private static float Sin(float x) => Mathf.Sin(x);
        private static float Exp(float x) => Mathf.Exp(x);
        private const float TAU = Mathf.PI * 2f;

        private AudioClip Gen(string name, float dur, Func<float, float> f)
        {
            int n = (int)(dur * SR);
            var data = new float[n];
            for (int i = 0; i < n; i++)
            {
                float t = (float)i / SR;
                float v = Mathf.Clamp(f(t), -1f, 1f);
                float fade = Mathf.Min(1f, Mathf.Min(i, n - i) / 64f);
                data[i] = v * fade * (32000f / 32768f);
            }
            var clip = AudioClip.Create(name, n, 1, SR, false);
            clip.SetData(data, 0);
            _bank[name] = clip;
            return clip;
        }

        /// <summary>鈴：非整数倍音の重ね合わせで金属的な余韻</summary>
        private static float Bell(float t, float f, float decay)
        {
            float v = 0f;
            v += Sin(TAU * f * t) * Exp(-t * decay);
            v += Sin(TAU * f * 2.76f * t) * Exp(-t * decay * 1.6f) * 0.5f;
            v += Sin(TAU * f * 5.40f * t) * Exp(-t * decay * 2.4f) * 0.25f;
            v += Sin(TAU * f * 8.93f * t) * Exp(-t * decay * 3.5f) * 0.12f;
            return v;
        }

        private static float Sign(float x) => x > 0f ? 1f : (x < 0f ? -1f : 0f);
        private static float Fmod(float a, float b) => a - b * Mathf.Floor(a / b);

        private void BuildBank()
        {
            Gen("shoot", 0.075f, t => { float e = Exp(-t * 52f); float f = Lerp(1500f, 620f, Mathf.Min(t / 0.075f, 1f)); return (Sin(TAU * f * t) * 0.6f + Sin(TAU * f * 2f * t) * 0.4f) * e * 0.18f; });
            Gen("eshot", 0.11f, t => { float e = Exp(-t * 26f); float f = Lerp(320f, 180f, Mathf.Min(t / 0.11f, 1f)); return Sign(Sin(TAU * f * t)) * e * 0.14f; });
            Gen("hit", 0.055f, t => { float e = Exp(-t * 70f); return (Rand() * 0.7f + Sin(TAU * 900f * t) * 0.3f) * e * 0.20f; });
            Gen("hit_heavy", 0.12f, t => { float e = Exp(-t * 34f); float f = Lerp(420f, 90f, Mathf.Min(t / 0.12f, 1f)); return (Rand() * 0.5f + Sin(TAU * f * t) * 0.6f) * e * 0.34f; });
            Gen("explode", 0.36f, t => { float e = Exp(-t * 11f); float low = Sin(TAU * Lerp(220f, 55f, Mathf.Min(t / 0.36f, 1f)) * t); return (Rand() * 0.55f + low * 0.55f) * e * 0.42f; });
            Gen("boom", 0.9f, t => { float e = Exp(-t * 4.2f); float low = Sin(TAU * Lerp(140f, 28f, Mathf.Min(t / 0.9f, 1f)) * t); return (Rand() * 0.45f + low * 0.75f) * e * 0.6f; });
            Gen("pickup", 0.16f, t => Bell(t, 1760f, 22f) * 0.16f);
            Gen("heal", 0.4f, t => (Bell(t, 880f, 9f) * 0.6f + Bell(t, 1320f, 12f) * 0.4f) * 0.2f);
            Gen("levelup", 0.55f, t => { float[] notes = { 659.25f, 783.99f, 987.77f, 1318.5f }; int idx = Mathf.Min((int)(t / 0.1f), 3); float lt = t - idx * 0.1f; return Bell(lt, notes[idx], 9f) * 0.26f; });
            Gen("hurt", 0.32f, t => { float e = Exp(-t * 8.5f); float f = Lerp(430f, 65f, Mathf.Min(t / 0.32f, 1f)); float saw = Fmod(f * t, 1f) * 2f - 1f; return (saw * 0.65f + Rand() * 0.35f) * e * 0.42f; });
            Gen("shield", 0.22f, t => { float e = Exp(-t * 14f); float f = Lerp(1600f, 700f, Mathf.Min(t / 0.22f, 1f)); return (Sin(TAU * f * t) * 0.6f + Rand() * 0.2f) * e * 0.3f; });
            Gen("chain", 0.16f, t => { float e = Exp(-t * 22f); return (Rand() * 0.5f + Sin(TAU * 2400f * t) * 0.5f) * e * 0.22f; });
            Gen("warn", 0.8f, t => { float e = 1f - Mathf.Min(t / 0.8f, 1f); float f = Lerp(90f, 260f, Mathf.Min(t / 0.8f, 1f)); float wob = Sin(TAU * 7f * t) * 0.5f + 0.5f; return Sign(Sin(TAU * f * t)) * e * (0.25f + wob * 0.2f) * 0.5f; });
            Gen("select", 0.1f, t => { float e = Exp(-t * 24f); return (Sin(TAU * 1200f * t) * 0.7f + Sin(TAU * 2400f * t) * 0.3f) * e * 0.14f; });
            Gen("hover", 0.06f, t => { float e = Exp(-t * 40f); return Sin(TAU * 1800f * t) * e * 0.08f; });
            Gen("gameover", 1.2f, t => { float e = Exp(-t * 2.2f); float f = Lerp(300f, 45f, Mathf.Min(t / 1.2f, 1f)); float saw = Fmod(f * t, 1f) * 2f - 1f; return saw * e * 0.4f; });
            Gen("taiko", 0.55f, t => { float e = Exp(-t * 7f); float f = Lerp(120f, 62f, Mathf.Min(t / 0.12f, 1f)); float skin = Sin(TAU * f * t); float slap = Rand() * Exp(-t * 60f); return (skin * 0.8f + slap * 0.5f) * e * 0.7f; });
            Gen("clap", 0.09f, t => { float e = Exp(-t * 60f); return (Rand() * 0.4f + Sin(TAU * 2600f * t) * 0.4f + Sin(TAU * 3900f * t) * 0.2f) * e * 0.3f; });
            Gen("suzu", 0.7f, t => { float v = 0f; v += Bell(t, 2093f, 6f); v += Bell(Mathf.Max(0f, t - 0.02f), 2637f, 7f) * 0.7f; v += Bell(Mathf.Max(0f, t - 0.045f), 3136f, 8f) * 0.5f; return v * 0.12f; });
            Gen("flute", 1.1f, t => { float atk = Mathf.Min(t / 0.12f, 1f); float rel = 1f - Mathf.Clamp01((t - 0.75f) / 0.35f); float vib = Sin(TAU * 5.5f * t) * 6f; float f = 1046.5f + vib + (t < 0.35f ? 0f : 174f); float breath = Rand() * 0.06f; return (Sin(TAU * f * t) * 0.7f + Sin(TAU * f * 2f * t) * 0.15f + breath) * atk * rel * 0.32f; });
            Gen("descend", 1.4f, t => { float e = 1f - Mathf.Clamp01((t - 0.8f) / 0.6f); float drone = (Sin(TAU * 110f * t) + Sin(TAU * 165f * t) * 0.6f) * Mathf.Min(t / 0.3f, 1f); float bells = Bell(Mathf.Max(0f, t - 0.3f), 1568f, 4f) + Bell(Mathf.Max(0f, t - 0.55f), 2093f, 4.5f); return (drone * 0.35f + bells * 0.4f) * e * 0.5f; });
            Gen("hit_light", 0.09f, t => { float e = Exp(-t * 40f); return (Sin(TAU * 2200f * t) * 0.5f + Sin(TAU * 3300f * t) * 0.3f + Rand() * 0.2f) * e * 0.2f; });
            Gen("hit_thunder", 0.14f, t => { float e = Exp(-t * 24f); float crack = Rand() * Exp(-t * 90f); return (crack * 0.8f + Rand() * 0.3f + Sin(TAU * 180f * t) * 0.4f) * e * 0.3f; });
            Gen("hit_storm", 0.18f, t => { float e = Exp(-t * 16f); float f = Lerp(700f, 180f, Mathf.Min(t / 0.18f, 1f)); return (Rand() * 0.6f + Sin(TAU * f * t) * 0.4f) * e * 0.3f; });
            Gen("hit_ice", 0.16f, t => { float e = Exp(-t * 20f); return (Bell(t, 2960f, 30f) * 0.6f + Rand() * Exp(-t * 80f) * 0.5f) * e * 0.22f; });
            Gen("doom", 0.3f, t => { float e = Exp(-t * 12f); float f = Lerp(90f, 40f, Mathf.Min(t / 0.3f, 1f)); return (Sin(TAU * f * t) * 0.8f + Rand() * 0.35f) * e * 0.5f; });
            Gen("charm", 0.35f, t => { float e = Exp(-t * 7f); float f = 880f + Sin(TAU * 9f * t) * 60f; return (Sin(TAU * f * t) * 0.6f + Sin(TAU * f * 1.5f * t) * 0.3f) * e * 0.2f; });
            Gen("deflect", 0.14f, t => { float e = Exp(-t * 26f); float f = Lerp(900f, 2200f, Mathf.Min(t / 0.14f, 1f)); return (Sin(TAU * f * t) * 0.7f + Rand() * 0.15f) * e * 0.22f; });
            Gen("fox", 0.12f, t => { float e = Exp(-t * 30f); float f = Lerp(1900f, 1200f, Mathf.Min(t / 0.12f, 1f)); return Sin(TAU * f * t) * e * 0.14f; });
            Gen("cast", 0.3f, t => { float e = Exp(-t * 9f); float f = Lerp(300f, 1400f, Mathf.Min(t / 0.3f, 1f)); return (Sin(TAU * f * t) * 0.6f + Sin(TAU * f * 0.5f * t) * 0.3f) * e * 0.26f; });
            Gen("charge", 0.5f, t => { float k = Mathf.Min(t / 0.5f, 1f); float f = Lerp(200f, 1800f, k * k); return Sin(TAU * f * t) * k * 0.16f; });
            Gen("dash", 0.16f, t => { float e = Exp(-t * 18f); float f = Lerp(500f, 1300f, Mathf.Min(t / 0.16f, 1f)); return (Rand() * 0.4f + Sin(TAU * f * t) * 0.4f) * e * 0.2f; });
            Gen("miki", 0.5f, t => { float e = Exp(-t * 6f); float f = Lerp(500f, 900f, Mathf.Min(t / 0.5f, 1f)); float bub = Sin(TAU * f * t) * (0.5f + 0.5f * Sin(TAU * 18f * t)); return bub * e * 0.22f; });
        }
    }
}
