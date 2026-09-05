using System;
using System.Collections.Generic;

namespace Kagura.Core
{
    /// <summary>神（主神・副神）。export/data/kami.json の 1 件。</summary>
    [Serializable]
    public class KamiDef
    {
        public string id;
        public string name;
        public string kana;
        public string title;
        public float[] color;   // r, g, b, a
        public float[] color2;
        public string emblem;
        public string role;
        public string weapon;
        public string weapon_desc;
        public string cast;
        public string cast_desc;
        public string call;
        public string call_desc;
        public string call_line;
        public string status;
        public string status_desc;
        public string cost;
        public string flavor;
        public string mark;
        public string intro;
        public string[] lines;
    }

    /// <summary>
    /// 能力（恩恵）。神の能力は tier（凡/稀/秀）を持ち、伝説・双神は rar を持つ。
    /// export/data/boons.json の 1 件。
    /// </summary>
    [Serializable]
    public class BoonDef
    {
        public string id;
        public string kami;
        public string kami2;     // 双神のときだけ
        public int? tier;        // 神の能力：Rarity（設計上の格）
        public int? rar;         // 伝説 / 双神
        public string name;
        public string desc;      // {v} に現在値が入る
        public float @base;
        public string fmt;       // pct / num / sec / sec_down / x
        public int? maxlv;

        public int MaxLevel => maxlv ?? 3;   // JSON の maxlv と名前が被らないように
        public bool IsGodUpgrade => tier.HasValue && string.IsNullOrEmpty(kami2) && !rar.HasValue;
        public bool IsLegendary => rar.HasValue && rar.Value == (int)Rarity.Legendary;
        public bool IsDuo => rar.HasValue && rar.Value == (int)Rarity.Duo;
        /// <summary>value 計算に使う格。tier があればそれ、無ければ rar。</summary>
        public int Grade => tier ?? rar ?? 0;
    }

    /// <summary>神宝（ボス撃破の褒賞、常時効果）。</summary>
    [Serializable]
    public class RelicDef
    {
        public string id;
        public string name;
        public string mark;
        public string desc;
        public bool shop;        // 市で売る神宝（討伐の褒賞には出ない）
        public int rar;          // 市の神宝の格：1 並 / 2 稀 / 3 秘
        public int price;        // 両
    }

    /// <summary>市の品（団子・時限の札）。kind: heal / maxhp / buff_dmg / buff_rate / buff_speed / shield / gauge。</summary>
    [Serializable]
    public class ShopItemDef
    {
        public string id;
        public string name;
        public string desc;
        public int price;
        public string kind;
        public float value;
        public float sec;
    }

    /// <summary>禍（契約の代償として選ぶ呪い）。</summary>
    [Serializable]
    public class CurseDef
    {
        public string id;
        public string name;
        public string gain;
        public string loss;
        public string desc;
    }

    /// <summary>波の中で 1 体の敵を出す予定。</summary>
    public struct SpawnEntry
    {
        public string Kind;
        public float X;
        public float Y;
        public float T;
    }
}
