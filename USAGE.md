# Remote Approval 使い方ガイド

iPhoneからPC（macOS / Windows）のClaude Code/Codexを操作するためのガイド

---

## Windowsで使う場合（最短手順）

### Step 1: Windows側

```powershell
# remote-approval ディレクトリに移動
cd "<remote-approvalのディレクトリ>"

# 状態確認
.\setup.ps1 check

# セットアップ
.\setup.ps1 all

# 接続情報（Termius用）
.\status.ps1 connect
```

`setup.ps1 all` で管理者権限が必要と表示された場合は、表示されたコマンドを「管理者PowerShell」で実行する。

### Step 1.5: WSL tmux でCodexを起動

```powershell
# Codexセッションを作成してアタッチ（初回はこれ）
.\tcodex-wsl.cmd

# 今いるディレクトリでCodexセッションを作成してアタッチ
.\tcodex-here-wsl.cmd

# 2回目以降の再接続
.\scodex-wsl.cmd

# セッション一覧
.\sls-wsl.cmd
```

`tmux` セッション内では `Ctrl+B` → `D` でデタッチできる。スマホ接続が切れてもセッションは残る。

補足:
- `tcodex-wsl.cmd` は、既存の `codex` セッションがある場合でも `new` + 既存セッションの選択メニューを表示する（`new` は `codex2`/`codex3`... を自動採番）。
- `scodex-wsl.cmd` は、`codex` セッションが複数ある場合は選択メニューを表示する。

### Step 2: iPhone側（Termius）

`status.ps1 connect` の `Host/User/Port` をそのまま設定して接続する。

### Step 3: 離席監視（任意）

```powershell
.\watch.ps1 start
.\watch.ps1 status
.\watch.ps1 stop
```

---

## Mac再起動後の手順（これだけ覚えればOK）

### Step 1: PCでやること

```bash
# 1. tmuxセッションを作る
tmux new -s claude

# 2. Claude Codeを起動
cd "<作業ディレクトリ>"
claude

# 3. 外出前にデタッチ（画面を残して抜ける）
# Ctrl+B → D
```

これでPCはそのまま放置してOK。

### Step 2: スマホでやること

```bash
# 1. Termiusアプリで「Mac」に接続

# 2. tmuxセッションに入る
tmux attach -t claude

# → Claude Codeの画面が表示される
```

### Step 3: スマホでできること

| できること | 例 |
|-----------|-----|
| プロンプト入力 | 「〇〇を調べて」 |
| 承認作業 | `y` / `n` を入力 |
| ファイル読み書き | Claude Codeが全部やってくれる |
| コマンド実行 | Claude Code経由で何でも |
| 結果の確認 | スクロールして見る |

**つまり、PCの前にいるのと同じことができる。**

---

## 基本の流れ

```
【初回 or Mac再起動後】
Mac: tc → Claude Codeセッション起動（tmux -CC モード）

【離席時】
Claude Codeに「離席する」→ 監視開始 → Slack通知が届く

【スマホから操作】
Termius接続 → sc → セッションにアタッチ → 操作 → Ctrl+B D

【席に戻ったとき】
Claude Codeに「戻りました」→ 監視停止
```

---

## 離席監視機能

離席中にSlack通知を受け取り、スマホから対応できる。

### 監視開始

Claude Codeに「離席する」「監視開始」等と伝えるか、直接コマンドを実行：

```bash
./watch start
```

```powershell
.\watch.ps1 start
```

### 監視停止

Claude Codeに「戻りました」「監視終了」等と伝えるか、直接コマンドを実行：

```bash
./watch stop
```

```powershell
.\watch.ps1 stop
```

### 通知のタイミング

| イベント | 通知内容 | 間隔 |
|---------|---------|------|
| 承認待ち | 🔔 【承認待ち】[セッション名] 入力を待っています | 初回即時、以降5分間隔 |
| エラー検出 | ⚠️ 【エラー検出】[セッション名] 確認が必要かもしれません | 初回即時、以降5分間隔 |
| アイドル | ✅ 【作業完了？】全セッションが15分以上アイドル状態です | 15分放置で1回 |

※ 複数セッション（claude, claude2, codex, codex2等）を同時監視。通知にはセッション名が含まれる。

### 監視の仕組み

```
ユーザー「離席する」
    ↓
watch start（バックグラウンドで監視開始）
    ↓
tmux pipe-pane でセッション出力を監視
    ↓
承認待ち/エラー/アイドル検出 → Slack通知
    ↓
スマホでTermius接続 → sc でアタッチ → 操作
    ↓
ユーザー「戻りました」→ watch stop
```

---

## よく使うコマンド一覧

### tmuxコマンド

| コマンド | 意味 | いつ使う？ |
|---------|------|-----------|
| `tmux new -s claude` | 新しいセッションを作る | 初回 or Mac再起動後 |
| `tmux attach -t claude` | 既存セッションに入る | 2回目以降 |
| `tmux ls` | セッション一覧を見る | セッションがあるか確認 |
| `Ctrl+B → D` | セッションから抜ける（デタッチ） | 外出するとき |
| `exit` | セッションを終了する | 完全に終わりたいとき |

### デタッチの方法（重要）

**Ctrl+B → D** の押し方：
1. `Ctrl` を押しながら `B` を押す
2. 両方離す
3. `D` を押す

これでセッションを「残したまま」抜けられる。

---

## シナリオ別の使い方

### シナリオ1: 朝、仕事前にMacでClaude Codeを起動しておく

```bash
# Macのターミナルで
tmux new -s claude
claude
# Claude Codeが起動する

# 外出前にデタッチ
# Ctrl+B → D
```

### シナリオ2: 外出中にiPhoneから操作

```bash
# iPhoneのTermiusで接続後
tmux attach -t claude

# → Claude Codeの画面が出る
# → プロンプトを入力したり、承認したり

# 終わったらデタッチ
# Ctrl+B → D
```

### シナリオ3: 帰宅後にMacで続きを作業

```bash
# Macのターミナルで
tmux attach -t claude

# → 外出中の続きから作業できる
```

### シナリオ4: セッションがあるか確認したい

```bash
tmux ls

# 出力例:
# claude: 1 windows (created ...)  ← セッションがある
#
# no server running  ← セッションがない（新規作成が必要）
```

---

## トラブルシューティング

### Claude Codeからexitしてしまった（スマホから再接続できない）

**スマホからPCにSSHで入れる状態なら**、PCを触らなくてもスマホ側だけで新しいtmuxセッションを作って、Claude Codeを立ち上げ直せる。

```bash
# 1. 状況確認（任意）
tmux ls

# 2. 新しいtmuxセッションを作る
tmux new -s claude2

# 3. Claude Codeを起動
claude

# 4. 読むだけに戻りたい/切断せず残したいならデタッチ
# Ctrl+B → D

# 5. 次回また入ったら
tmux attach -t claude2
```

**PC側を触らないと無理なケース：**
- PCがスリープ/電源オフ
- 同じWi-Fi内でしかSSHできない設定で、スマホが外にいる
- VPN（Tailscale等）で繋いでたのに切れてる
- 初回ログインや認証が必要で、スマホだけだとやりづらい状態

**チェックポイント:** 「TermiusでPCにSSH接続できてる状態？」
- 接続できてる → 上の手順でスマホだけで新セッションにclaude立てられる
- 接続できてない → 「届く状態を作る」が先

---

### 「already attached」と出る

別の場所で既に接続中。強制的に入るには：
```bash
tmux attach -t claude -d
```

### 「session not found」と出る

セッションがない。新規作成する：
```bash
tmux new -s claude
```

### 「no server running」と出る

tmuxが動いていない。新規作成する：
```bash
tmux new -s claude
```

---

## 接続情報（メモ）

接続情報は端末側で以下を実行して確認する（個別のIP/ユーザー名をドキュメントに固定しない）。

- macOS: `./status connect`
- Windows: `.\status.ps1 connect`

---

## iPhone (Termius) からの接続手順

1. Termiusアプリを開く
2. 「Mac」をタップ
3. 接続されたら以下を入力：

```bash
# セッションがあるか確認
tmux ls

# あれば接続
tmux attach -t claude

# なければ新規作成
tmux new -s claude
claude
```

---

## ワンライナー（コピペ用）

セッションがあれば接続、なければ作成：
```bash
tmux attach -t claude 2>/dev/null || tmux new -s claude
```

Claude Codeも一緒に起動：
```bash
tmux attach -t claude 2>/dev/null || (tmux new -s claude -d && tmux send-keys -t claude 'claude' Enter && tmux attach -t claude)
```

---

## Apple Watchについて

Apple Watchからの操作は実用的ではありません。
- 画面が小さすぎる
- 文字入力が困難

**iPhoneをメインで使ってください。**

---

## 複数ターミナルを使う（tmuxウィンドウ）

Claude Codeを動かしながら、別のターミナルも使いたい場合。

### ウィンドウ操作コマンド

| 操作 | キー |
|-----|------|
| 新しいウィンドウを作る | `Ctrl+B → C` |
| 次のウィンドウに移動 | `Ctrl+B → N` |
| 前のウィンドウに移動 | `Ctrl+B → P` |
| ウィンドウ0に移動 | `Ctrl+B → 0` |
| ウィンドウ1に移動 | `Ctrl+B → 1` |
| ウィンドウ一覧を見る | `Ctrl+B → W` |

### 使用例

```
ウィンドウ0: Claude Code（メイン作業）
ウィンドウ1: 普通のターミナル（ファイル確認など）

Ctrl+B → 0 でClaude Codeに戻る
Ctrl+B → 1 でターミナルに移動
```

### 図で見ると

```
┌─────────────────────────────────────┐
│  tmux セッション "claude"           │
│                                     │
│  ┌─────────┐  ┌─────────┐          │
│  │ウィンドウ0│  │ウィンドウ1│         │
│  │Claude   │  │ターミナル│          │
│  │Code     │  │         │          │
│  └─────────┘  └─────────┘          │
│       ↑                             │
│   Ctrl+B → 0/1 で切り替え           │
└─────────────────────────────────────┘
```

### キー操作のコツ

全て `Ctrl+B` を押してから、次のキーを押す：

1. `Ctrl` を押しながら `B` を押す
2. 両方離す
3. 次のキー（`C`, `N`, `0` など）を押す

---

## ショートカットコマンド一覧

`~/.zshrc` に登録済み。

### PC起動用（iTerm2 -CC モード）

| コマンド | 説明 |
|---------|------|
| `tc` | Claude Codeセッションにアタッチ（なければ新規作成） |
| `tcn` | 新規Claude Codeセッション作成（claude2〜9） |
| `tcodex` | Codexセッションにアタッチ（なければ新規作成） |
| `tcodexn` | 新規Codexセッション作成（codex2〜9） |

### スマホアタッチ用（-CC なし、Termius等で使用）

| コマンド | 説明 |
|---------|------|
| `sc` | 既存セッションにアタッチ（複数あれば選択） |
| `scn` | 新規Claude Codeセッション作成（claude2〜9） |
| `scodex` | 既存セッションにアタッチ（複数あれば選択） |
| `scodexn` | 新規Codexセッション作成（codex2〜9） |

### その他

| コマンド | 説明 |
|---------|------|
| `sls` | tmuxセッション一覧を表示 |
| `cc` | tmux外で直接Claude Code起動（非推奨） |

### `tc` / `sc` の動作

| セッション数 | 動作 |
|-------------|-----------|
| 0個 | 新規「claude」セッション作成 |
| 1個 | 自動でそこに入る |
| 複数 | 一覧表示 → 番号で選択 |

**PC側は `tc` / `tcodex`、スマホ側は `sc` / `scodex` を使う。**

---

## スマホでのスクロール（copy-mode）

Claude Codeの出力中でも、過去のやり取りを遡れる。

### PCでのスクロール/画面崩れ対策（tmux）

tmux内は「端末のスクロール」ではなく「tmuxの履歴」になるので、基本は copy-mode を使う。

| 症状 | 対処 |
|-----|------|
| スクロールが効かない | `Ctrl+B → s`（copy-mode） |
| スマホ接続後にレイアウトが崩れた/更新されない | `Ctrl+B → R`（強制リフレッシュ） or `Ctrl+B → A`（自動リサイズ） |

※ Windowsの `tcodex-wsl.cmd` / `scodex-wsl.cmd` 側で `mouse on` も入れているので、環境によってはマウスホイールでもスクロールできる。

### 操作方法

| 操作 | キー |
|-----|------|
| copy-mode開始 | `Ctrl+B → s` |
| スクロール | `↑` / `↓` / `PageUp` / `PageDown` |
| copy-mode終了 | `q` |

※ `Ctrl+B → [` でも入れるが、`s` の方がスマホで打ちやすい（`~/.tmux.conf` に設定済み）

### copy-modeが効かない時

Claude Codeが出力中で反応しない場合：
1. `Ctrl+C` で出力を止める
2. その後 `Ctrl+B → s`

### 見分け方

- 画面左下に `[0/123]` のような表示が出る
- スクロールしてもClaude Codeに入力されない（閲覧モード）

---

## iPhoneのTermiusでのCtrlキー

Termiusの画面上部に追加キー列（extra keys）がある：
- `Ctrl` `Alt` `Esc` などのボタン
- なければ設定 → Terminal → Extra Keys で有効化

`Ctrl+B` の打ち方：
1. Termiusの `Ctrl` ボタンをタップ
2. `B` を押す
3. （離す）
4. 次のキー（`s`, `D`, `C` など）を押す

---

## コスト・セキュリティについて

### 料金

| サービス | 費用 |
|----------|------|
| Claude Code API | トークン課金（待機中は無料） |
| Tailscale | 無料（個人利用） |
| Termius | 無料（基本機能） |
| SSH | 無料（macOS標準） |

**立ち上げておくだけなら料金はかからない。** 実際にメッセージを送った時だけAPI課金。

### セキュリティ

| 項目 | 状況 |
|------|------|
| Tailscale | 暗号化VPN、外部から直接アクセス不可 |
| SSH | パスワード認証（鍵認証推奨） |
| 経路 | iPhone → Tailscale(暗号化) → Mac のみ |

より安全にするには：
- SSH鍵認証に切り替える
- Tailscaleアカウントの2段階認証を有効化
- Macのログインパスワードを強固に

### 常時スタンバイの注意点

| 項目 | 対策 |
|------|------|
| Macのスリープ | 「ネットワークアクセスによるスリープ解除」ON |
| セッション切れ | tmux使えば復帰可能 |
