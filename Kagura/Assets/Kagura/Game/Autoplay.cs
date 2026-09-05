using System.Collections.Generic;
using UnityEngine;

namespace Kagura.Game
{
    /// <summary>
    /// 開発用の自動プレイ（Godot 版 autoplay.gd の要点）。URL に autoplay / cleartest があるときだけ GameManager が生成する。
    ///   autoplay  ：人間に近い動きで進め、選択画面は 1 番目を選ぶ。倒れたら題目からやり直す
    ///   cleartest ：加えて無敵・威力 12 倍で踏破まで走る
    /// </summary>
    public class Autoplay : MonoBehaviour
    {
        public bool god;
        public int startWave;   // URL の wave=N：その波の直前から始める（検証用）
        private float _t, _stateT, _castT, _callT;
        private GameState _last = GameState.Title;
        private ChoiceKind _lastChoice = ChoiceKind.None;

        private void Update()
        {
            var g = GameManager.I;
            if (g == null) return;
            float dt = Time.unscaledDeltaTime;
            _t += dt;
            if (g.State != _last || g.choice != _lastChoice) { _stateT = 0f; _last = g.State; _lastChoice = g.choice; }
            _stateT += dt;
            var p = g.player;
            if (p != null) { p.godMode = god; p.dmgMult = god ? 12f : 1f; }

            switch (g.State)
            {
                case GameState.Title:
                    if (_stateT > 1.2f && !g.ranking.visible) g.StartGame();
                    break;
                case GameState.Choice:
                    if (_stateT < 1.6f) break;
                    var ui = g.ui;
                    switch (g.choice)
                    {
                        case ChoiceKind.Story: ui.story.Hide(); ui.OnStoryDone?.Invoke(); break;
                        case ChoiceKind.Familiar: ui.OnFamiliarChosen?.Invoke(Familiar.LIST[1].id); break;
                        case ChoiceKind.Kami:
                            if (ui.confirm.visible) { ui.confirm.Hide(); ui.confirm.onOk?.Invoke(); }
                            else if (ui.kami.ids.Count > 0) { ui.kami.Hide(); ui.AskContract(ui.kami.ids[0], ui.kami.role, () => ui.OnKamiChosen?.Invoke(ui.kami.ids[0])); _stateT = 0.8f; }
                            break;
                        case ChoiceKind.Boon: if (ui.boons.offers.Count > 0) ui.OnBoonChosen?.Invoke(0); break;
                        case ChoiceKind.Miki: if (ui.miki.ids.Count > 0) ui.OnMikiChosen?.Invoke(ui.miki.ids[0]); break;
                        case ChoiceKind.Relic: if (ui.relic.offers.Count > 0) ui.OnRelicChosen?.Invoke(0); break;
                        case ChoiceKind.Shop:
                            {
                                int buy = -1;
                                for (int i = 0; i < ui.shop.offers.Count; i++) if (!ui.shop.offers[i].sold && ui.shop.offers[i].price <= ui.shop.ryo) { buy = i; break; }
                                if (buy >= 0 && _stateT < 4f) { ui.OnShopBuy?.Invoke(buy); _stateT = 1.6f; }
                                else ui.OnShopLeave?.Invoke();
                                break;
                            }
                    }
                    break;
                case GameState.Play:
                    if (p == null || !p.alive) break;
                    if (startWave > 1 && g.Wave == 0) g.Wave = startWave - 1;
                    {
                        // 近くの敵に横位置を合わせつつ、画面下寄りに留まる
                        var pp = p.pos;
                        float wantX = Gd.W * 0.5f + Mathf.Sin(_t * 0.9f) * Gd.W * 0.35f;
                        float best = float.MaxValue;
                        foreach (var e in g.EnemyList()) { float d = Mathf.Abs(e.pos.y - pp.y); if (d < best) { best = d; wantX = e.pos.x; } }
                        // 勾玉が近くにあればそちらへ
                        float wantY = Gd.H * (0.74f + 0.10f * Mathf.Sin(_t * 0.31f));
                        // 市の屋台が流れてきたら触れに行く
                        if (g.stall != null && g.stall.Active && g.stall.pos.y > 120f) { wantX = g.stall.pos.x; wantY = g.stall.pos.y; }
                        var dir = Vector2.zero;
                        float dx = pp.x - wantX, dy = pp.y - wantY;
                        if (dx > 14f) dir.x = -1f; else if (dx < -14f) dir.x = 1f;
                        if (dy > 20f) dir.y = -1f; else if (dy < -20f) dir.y = 1f;
                        p.autoDir = dir;
                        _castT += dt; _callT += dt;
                        if (_castT > 3f) { _castT = 0f; p.autoCast = true; }
                        if (_callT > 6f) { _callT = 0f; if (!g.fullCall) p.autoCall = true; }
                    }
                    break;
                case GameState.Over:
                    if (p != null) p.autoDir = Vector2.zero;
                    if (_stateT > 4f && g.overlay.visible) g.ShowTitle();
                    break;
                case GameState.Clear:
                    if (_stateT > 30f && g.overlay.visible) g.ContinueEndless();
                    break;
            }
        }
    }
}
