# Remote Approval Tool - AGENTS.md

## トリガーワード
- 「リモート承認」「iPhone承認」「Apple Watch承認」「外出先から承認」
- 「離席する」「監視開始」「ちょっと離れる」→ 監視開始
- 「席に戻りました」「監視終了」「戻った」→ 監視停止

## いつ使うか
- iPhone/Apple WatchからClaude Codeの承認を行いたいとき
- 離席中にSlack通知を受け取りたいとき
- セットアップ方法を確認したいとき

## 基本コマンド

```bash
# 設定状態を確認
./tools/remote-approval/setup check

# 全てセットアップ
./tools/remote-approval/setup all

# 接続情報を表示
./tools/remote-approval/status connect

# 監視開始（離席時）
./tools/remote-approval/watch start

# 監視停止（席に戻ったとき）
./tools/remote-approval/watch stop

# 監視状態確認
./tools/remote-approval/watch status
```

Windows + WSL tmux 運用:

```powershell
.\tools\remote-approval\tcodex-wsl.cmd   # 初回起動（作成+接続）
.\tools\remote-approval\scodex-wsl.cmd   # 再接続
.\tools\remote-approval\sls-wsl.cmd      # 一覧
```

## 仕組み

### リモート承認
```
iPhone (Termius) --SSH→ ローカルIP or Tailscale --→ Mac (Claude Code)
```

- **Termius**: iPhoneからSSH接続するアプリ
- **同じWi-Fi**: ローカルIP（192.168.x.x）で接続（VPN不要）
- **外出先**: Tailscale VPN経由で接続

### 離席監視（複数セッション対応）
```
ユーザー「離席する」
    ↓
watch start（全claude/codexセッションを自動検出・監視開始）
    ↓
各セッションの出力を監視
    ↓
承認待ち/エラー/アイドル検出 → Slack通知（セッション名付き）
    ↓
スマホでTermius接続 → sc/scodex でアタッチ → 操作
    ↓
ユーザー「戻りました」→ watch stop
```

## Slack通知のタイミング

| イベント | 通知内容 | タイミング |
|---------|---------|------|
| 入力待ち | ⏳ 【入力待ち】[セッション名] 操作を待っています | 承認パターン検出で即時 or 1分更新なしで通知、以降5分間隔で再通知 |
| エラー検出 | ⚠️ 【エラー検出】[セッション名] 確認が必要かもしれません | 初回即時、以降5分間隔 |
| 作業完了 | ✅ 【作業完了？】全セッションが15分以上停止中 | 15分放置で1回 |

## コマンド一覧

| 場面 | Claude | Codex |
|-----|--------|-------|
| PC起動 | `tc` / `tcn` | `tcodex` / `tcodexn` |
| スマホアタッチ | `sc` / `scn` | `scodex` / `scodexn` |
| セッション一覧 | `sls` | |

## 詳細

- セットアップ手順: `tools/remote-approval/README.md`
- 日常の操作: `tools/remote-approval/USAGE.md`
