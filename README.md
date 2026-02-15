# Remote Approval Tool

Claude Code/Codexの承認作業をiPhone/Apple Watchから行うためのセットアップツール（macOS / Windows対応）

## 概要

このツールは、PCで動作しているClaude Code/Codexのツール承認（ファイル編集やコマンド実行の許可）を、手元のiPhoneやApple Watchから行えるようにします。

### 仕組み

```
┌─────────────┐      SSH接続       ┌─────────────┐
│  iPhone     │ ──────────────→   │  Mac        │
│  (Termius)  │    (Tailscale)    │  (Claude    │
│             │ ←──────────────   │   Code)     │
└─────────────┘   ターミナル画面   └─────────────┘
```

- **Termius**: iPhoneからSSH接続するアプリ
- **Tailscale**: 外出先からも安全に接続できるVPN（無料）

---

## セットアップ手順

### Step 1-Windows: Windowsの設定

```powershell
# このディレクトリに移動
cd "<remote-approvalのディレクトリ>"
# 例: このcodexワークスペース内なら
# cd tools/remote-approval

# 設定状態を確認
.\setup.ps1 check

# 可能な範囲を一括セットアップ
.\setup.ps1 all
```

`OpenSSH Server` の有効化は管理者権限が必要です。`setup.ps1 all` 実行時に表示される管理者コマンドを実行してください。

Tailscale 未導入時は次のどちらかで導入します。
- `winget install Tailscale.Tailscale`
- 公式インストーラーを使用

接続情報の表示:

```powershell
.\status.ps1 connect
```

### Step 1.5-Windows: tmuxでCodexセッションを常駐化（推奨）

```powershell
# Codexセッションを作成してアタッチ（なければ新規作成）
.\tcodex-wsl.cmd

# 既存セッションにアタッチ
.\scodex-wsl.cmd

# セッション一覧
.\sls-wsl.cmd
```

`tmux` を使うことで、スマホ側の接続が切れても Codex セッションが維持されます。

補足:
- `.\tcodex-wsl.cmd` は、既存セッションがある場合も `new` / 既存セッションを選ぶメニューが出ます（`new` は `codex2`/`codex3`... を自動採番）。
- `.\scodex-wsl.cmd` は、複数セッションがある場合に接続先の選択メニューが出ます。

### Step 1-Mac: Macの設定

```bash
# このディレクトリに移動
cd "<remote-approvalのディレクトリ>"
# 例: このcodexワークスペース内なら
# cd tools/remote-approval

# 実行権限を付与
chmod +x setup status

# 設定状態を確認
./setup check

# 全てセットアップ（リモートログイン有効化 + Tailscale）
./setup all
```

### Step 2: iPhoneの設定

#### 2-1. Tailscaleのインストール・設定

1. App Storeで「**Tailscale**」をインストール
2. アプリを開いて「**Log in**」をタップ
3. Google/Microsoft/GitHubなどでログイン
   - **重要**: Macと同じアカウントでログイン
4. 「**Allow**」で VPN接続を許可

#### 2-2. Termiusのインストール・設定

1. App Storeで「**Termius**」をインストール（無料）
2. アプリを開いて「**Hosts**」→「**+**」をタップ
3. 「**New Host**」を選択
4. 以下を入力:

```
Alias:    My Mac（任意の名前）
Hostname: [TailscaleのIP]  ← ./status connect で確認
Port:     22
Username: [Macのユーザー名]
Auth:     Password or SSH Key（可能ならSSH鍵推奨）
```

5. 「**Save**」をタップ
6. 作成したホストをタップして接続テスト

### Step 3: 接続情報の確認

```bash
# 接続に必要な情報を表示
./status connect
```

---

## 使い方

### iPhoneから承認する

1. MacでClaude Codeを起動
2. Claude Codeが承認待ちになったら
3. iPhoneでTermiusを開く
4. 設定したホストをタップして接続
5. ターミナル画面が表示される
6. 承認操作を行う:
   - `y` + Enter で承認
   - `n` + Enter で拒否

### よく使うコマンド

```bash
# Claude Codeを起動（新しいセッション）
claude

# 現在のセッションにアタッチ（既に起動中の場合）
# ※ tmuxを使っている場合
tmux attach
```

---

## Apple Watchでの承認

### 対応状況

| 機能 | Apple Watch | 備考 |
|-----|-------------|------|
| 接続状態の確認 | 可能 | Termiusアプリ |
| 簡単なコマンド入力 | 可能 | 音声入力 or 定型文 |
| フルキーボード操作 | 困難 | 画面が小さい |

### Apple Watchで承認する方法

**方法1: Termiusアプリを使う**

1. Apple WatchにTermiusをインストール（iPhoneにインストール済みなら自動で同期）
2. Watchでアプリを開く
3. 設定済みのホストをタップ
4. **音声入力**で `y` と言ってEnter

**方法2: iPhoneのTermiusをWatchから操作**

1. iPhoneでTermiusを開いて接続した状態にしておく
2. WatchのNow Playing機能やハンズフリーで操作

### Apple Watchの制限事項

- 画面が小さいため、複雑な操作は難しい
- 基本的にはiPhoneでの操作を推奨
- Watchは「外出中に緊急で承認が必要」な場合のバックアップ手段

---

## トラブルシューティング

### 接続できない場合

```bash
# 1. SSH（リモートログイン）が有効か確認
./setup check

# 2. Tailscaleが接続されているか確認
tailscale status

# 3. ファイアウォールを確認
# システム設定 → ネットワーク → ファイアウォール
# → オプション → リモートログインを許可
```

### パスワードが通らない場合

- Macのログインパスワードを使用しているか確認
- スペースや特殊文字が含まれている場合は正確に入力

### 外出先から接続できない場合

1. iPhone/MacともにTailscaleがONになっているか確認
2. 同じTailscaleアカウントでログインしているか確認
3. Macがスリープしていないか確認
   - システム設定 → ディスプレイ → 詳細設定 → 「ネットワークアクセスによるスリープ解除」をON

---

## セキュリティについて

- Tailscaleは暗号化されたVPNを使用
- SSH接続はパスワードまたはSSH鍵で認証
- 外部から直接Macに接続されることはない（Tailscale経由のみ）

### より安全にするには

```bash
# SSH鍵認証を設定（パスワード認証より安全）
# 1. iPhoneのTermiusで鍵を生成
# 2. 公開鍵をMacの ~/.ssh/authorized_keys に追加
```

### Slack通知（任意）

離席監視のSlack通知を使う場合は、Webhookを環境変数か `.env` で渡してください（Webhook URLはリポジトリにコミットしない）。

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

または `.env`（bashでsource可能な形式。`tools/remote-approval` 配下で使う場合も同様）:

```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

---

## ファイル構成

```
remote-approval/
├── README.md    ← このファイル（セットアップ手順）
├── USAGE.md     ← 使い方ガイド（日常の操作方法）
├── CLAUDE.md    ← Claude Code向け説明
├── AGENTS.md    ← エージェント向け説明
├── setup        ← macOS向けセットアップスクリプト
├── status       ← macOS向け状態確認スクリプト
├── watch        ← macOS向け離席監視スクリプト
├── setup.ps1    ← Windows向けセットアップスクリプト
├── status.ps1   ← Windows向け状態確認スクリプト
├── watch.ps1    ← Windows向け離席監視スクリプト
├── setup.cmd    ← Windows用ラッパー
├── status.cmd   ← Windows用ラッパー
├── watch.cmd    ← Windows用ラッパー
├── tmux-session-select.sh ← WSL tmux: セッション選択（new/既存）
├── tcodex-wsl.cmd ← WSL tmux: セッション作成/接続
├── tcodex-here-wsl.cmd ← WSL tmux: 現在ディレクトリで作成/接続
├── scodex-wsl.cmd ← WSL tmux: 既存セッション接続
└── sls-wsl.cmd    ← WSL tmux: セッション一覧
```

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `.\setup.ps1 check` | Windows: 現在の設定状態を確認 |
| `.\setup.ps1 all` | Windows: SSH/Tailscaleのセットアップを実行 |
| `.\status.ps1 connect` | Windows: Termius用接続情報を表示 |
| `.\watch.ps1 start` | Windows: 離席監視を開始 |
| `.\watch.ps1 stop` | Windows: 離席監視を停止 |
| `.\watch.ps1 status` | Windows: 監視状態を確認 |
| `.\tcodex-wsl.cmd` | Windows: WSL上のCodex tmuxセッション作成/接続 |
| `.\tcodex-here-wsl.cmd` | Windows: 現在ディレクトリでWSL Codex tmux起動/接続 |
| `.\scodex-wsl.cmd` | Windows: WSL上のCodex tmuxセッションに接続 |
| `.\sls-wsl.cmd` | Windows: WSL上のtmuxセッション一覧 |
| `./setup check` | 現在の設定状態を確認 |
| `./setup mac` | Macの設定（リモートログイン有効化） |
| `./setup tailscale` | Tailscaleのインストール・設定 |
| `./setup all` | 全ての設定を一括で行う |
| `./status` | 接続情報とステータスを表示 |
| `./status connect` | Termiusでの接続設定情報を表示 |
| `./watch start` | 離席監視を開始（Slack通知有効化） |
| `./watch stop` | 離席監視を停止 |
| `./watch status` | 監視状態を確認 |
