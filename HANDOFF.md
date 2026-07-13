# ザトウムシ増殖シム — 引き継ぎ資料(完全版)

最終更新: 2026-07-13 / これは「現在の状態」を1から説明する資料。過去の更新履歴はgit logを参照。
**コードの正はindex.html**(単一HTML、Three.js 0.160 CDN、約1900行)。
2026-07-13の大更新で 5x5化・巣・砦・10人並列陣・敗北演出・脚の自切・BGMを追加(詳細は§8)。

---

## 0. これは何か

薄緑・半透明のザトウムシ(harvestman)が人間を捕食して群れを増やし、4x4=16エリアの世界を制圧していく見下ろし型ゲーム。白い紙の上のような明るいビジュアル、固定・正射影・ほぼ真上(仰角76°)のカメラ。

**世界観(ユーザー共有済み)**: プレイヤーが操作しているのは小さな虫ではなく巨大な兵器。虫の認知ではこういうシンプルな世界に見えているが、実際には人間と戦争している。子ども・他の成体・カメムシは同種の兵器 → だから死骸は武装した人間のいる地帯に転がっている。

発端はユーザー手描きのコンセプトアート(同フォルダの ザトウムシ*.png/.clip、イラスト2.png=OP/クリア演出等の指示書、kamemushi_ref.jpg=カメムシ参考画像)。

---

## 1. リポジトリ・環境

- **GitHub: https://github.com/medetasimedetasi/zatoumushi (Private)**
- ローカル: `D:\brender\Claude_code`(git管理済み。shot.jpgは.gitignore)
- gh CLI認証済み(`C:\Program Files\GitHub CLI\gh.exe`。新しいシェルならPATHにghあり)
- **運用**: 機能が動いて検証済みになった区切りでコミット&push(ユーザー合意済み)。コミットメッセージは日本語+`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- このPCには**NodeもPythonも無い**。静的配信はPowerShellのHttpListener(リポジトリ内 serve.ps1 のコピーが `C:\Users\gyaku\yukkuri\.claude\serve-zatoumushi.ps1`、port 8124、POST /shot → shot.jpg保存)
- 起動定義: `C:\Users\gyaku\yukkuri\.claude\launch.json` の `zatoumushi` エントリ → `preview_start({name:"zatoumushi"})`
- セッションの作業ディレクトリが `C:\Users\gyaku\yukkuri` の場合あり。ゲーム本体はD:側

## 2. 検証のしかた(重要・ハマりどころ)

Browserペインが非表示だとrAFが止まる。回避用のデバッグフックを本体に内蔵済み:

| フック | 用途 |
|---|---|
| `__step(n)` | nフレーム手動で進める(1呼び出し300程度まで。超えるとjavascript_toolが30秒でタイムアウト) |
| `__shot()` | canvasをJPEG化してPOST /shot → `shot.jpg`。Readツールで画像確認 |
| `__state()` | 全状態JSON(col/row/hp/maxHp/座標/weapon/cell/caught/items/stains/title/ending/ap等)。検証の主力 |
| `__click(x,z)` | クリック移動(タイトル中なら自動でstartGame) |
| `__stage('R'/'L'/'U'/'D')` | 隣エリアへデバッグジャンプ |
| `__start()` | タイトルスキップ(**検証はまずこれを呼ぶ**) |
| `__kids(n)` | 子どもをn匹スポーン(バランステスト用) |
| `__damage(n)` | 成体にダメージ(負数で回復チート、__damage(-5)=実質HP8) |
| `__zoom(v)` | 0.3で寄り、1.18がデフォルト(原点中心) |
| `__item('bug'/'corpse')` | アイテムメッシュを原点に置く(アート確認) |
| `__cells()` | 現ステージの編成セルのアンカー座標/向き(ひき打ち検証) |
| `__spawnAt(x,z,n)` | 指定座標に子どもn匹(陣形テスト用) |
| `__bgm()` | BGMの再生状態(muted/vol/idx/icon) |

`__state()` は追加で `titleKids / lostLegs / legDebris / cells / nestKids` も返す。

**罠**:
- **Editするたびに Browserペインがファイル表示に切り替わる** → 検証前に必ず `navigate` で http://localhost:8124 へ戻す(戻さないと `__shot` が無言で死ぬ)
- 古いセッションのサーバーが8124を掴んで固まることがある → `Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"` でzatoumushiを含むプロセスを探してkill → `preview_start({name:"zatoumushi"})`
- javascript_toolで `let` を使うと再実行時に再宣言エラー → 即時関数 `(()=>{...})()` で包む
- ライブのrAFも並走しているので、ツール呼び出しの合間に状態が進む

典型フロー: navigate → `__start()` → `__step(150)` → `__shot()` → Read shot.jpg / `__state()`

## 3. 現在の仕様(全部実装・検証済み)

### ワールド
- **5x5グリッド**(2026-07-13に4x4から変更)。開始(0,0)=左上、**本拠地(4,4)=右下(赤)**。難度 d=col+row(0〜8)
- 特殊マス: **巣(0,1)=開始の直下・ミニマップ緑**(§8)、**砦(4,0)=右上・大きな家(§8)**。定数 `NEST_COL/ROW`, `FORT_COL/ROW`, `isNest()`, `isFort()`
- カメラは+z側から見下ろす: **画面右=+x=col+1、画面下=+z=row+1**
- 遷移: **枠の完全に外側をクリック**した時だけ意図が立ち、成体が**枠+1.4まで見切れてから**切替(枠内クリック・獲物クリックでは絶対に遷移しない)。グリッド外周は濃い線で塞ぎ、行ける方向だけ◀▲▼▶表示
- ミニマップ(左下DOM): 赤=本拠地、グレー=制圧済、緑枠=現在地。STAGE表記なし
- 地形・岩・アイテムはステージ固定シード(mulberry32)。再訪で同じ配置。死亡跡(シミ)も`stainStore`で復元
- **人間は有限**(`stageRemain`)。狩り尽くすと再POPしない。(0,0)は無人、d1は非武装

### OP(タイトル)
完全にソリッドなマットの●とstart(canvas 1枚)。**start文字付近のクリックだけで開始**。開始すると「きわ」から削れて(BFSで外周から崩壊順)、**剥がれた場所から虫が逃げ出す**(欠け=逃げた虫、フェード無し)。約3.2秒で全崩壊、終盤40チャンクは必ず虫になる、削りカスは仕上げパスで拭き取る。虫は湧き確率0.45・同時70(ユーザー調整済みの塩梅、勝手に変えない)

### ザトウムシ(class Harvestman)
- 歩行は実物準拠: 第2脚(最長)=触角(歩かない、床を本当にtapする)、残り6本=交互三脚歩容+2ボーンIK。歩容連動の胴体運動(支持交替で沈む/中央で持ち上がる/横揺れ/着地sag、全て表示専用)、三脚内微小時差、個体差多数
- **成体はクリック移動が基本+半径3.2だけ自動追尾**(確定仕様)。初期HP3、死骸でmaxHp+1(上限8)
- 捕食=プレスモーション: 押さえ込んで胴体接地。成体0.38秒、**子どもは2.0〜2.6秒じっと食べてから**新しい子どもが生まれる。捕食された人間は**横倒し**でもがく
- 子どもHP2(1発耐える)。**武装人間からユニーク子ども**: rifle→fast(赤・速い)、shotgun→tough(濃緑大柄HP4)、隊長→elite
- フレネル風リムライト、被弾クラウチ、生成時の起き上がり等の演出あり

### 人間・戦闘
- 武器3種(見た目で判別): pistol(赤茶/射程13)、rifle(青灰/18/弾速17)、shotgun(橙茶/7.5/3発扇状)。人数5+2d、武装率[0,0,.3,.5,.65,.8]
- **本拠地(3,3)=30人**: 隊長1+守備隊15(**5人セル×3陣形**=前3後2、開口部を左右から交差射撃)+武装14。d5には3人セルの前哨
- 陣形(braveのみ): スロット維持、味方越しに撃たない(allyBlocks)、人間同士の分離1.25、標的の左右分散、後退はnd<1.2のみ
- **隊長**: 目立つ赤(emissive)・1.55倍・常に成体だけ狙う3点バースト・**子ども4匹未満では押さえ込めない**(灰色パルスで表示)
- 岩=家(ドア付き、要塞壁は除く)。弾を防ぐ遮蔽物。**押し出しは進行方向への接線スライド付き**(壁沿いに回り込める。これが無いと要塞前でスタックする)
- 制圧報酬: HP+2回復+地面に「clear」が左からスライドイン→3秒→右へアウト(太字斜体、地面の上・オブジェクトの下)

### アイテム(食事モーション付き: 1.7秒深く屈む+頭上に小さくポップ表示)
- **成体の死骸**(脚が丸まった姿、d≥2の55%): 成体が食べるとmaxHp+1「♡+1」、上限MAXなら回復「♡回復」
- **カメムシの死体**(参考画像準拠: 薄緑の盾形五角・仰向け・脚が腹上でX字クロス、d≥3の45%): 触れると子ども+3「●+3」
- 本拠地は両方確定配置。取得は一度きり(itemTaken)

### 死亡跡
敵を捕食した場所に**黒いシミ**(5種テクスチャ×ランダム回転/拡縮)。最後まで残り、再訪でも復元

### エンディング
本拠地制圧→「clear」+AP誘導ポップ→中央の**アクセスポイント**(緑ランプのアンテナ)に成体が触れる→`runEnding`のフェーズ: connect(1.8s)→swarm(画面外から子44匹が殺到)→consume(成体を捕食、成体は薄れて消える)→spread(全員成体化・ズームアウト1.85・家々を蹂躙・シミ増殖)→fade(暗転2.4s)→thanks(**THANK YOU FOR PLAYING!** 1文字ずつカクカク跳ねる+リザルト:制圧エリア/最終群れ数)。クリックでリロード。**音楽(カノン)は未実装**

### UI
`♥♥♡ ●×12` のみ(HP+子ども数)。操作説明・敵数表示なし。GAME OVERはDOMラベル+クリックでリロード

## 4. バランス実測値

- 子ども0〜8匹で本拠地突撃 → 捕獲ほぼゼロで壊滅(狙い通り)
- HP8+群れ45で本拠地攻略可(30→0、HP5残しでクリア)
- 道中の総人口≈160+カメムシ5個(+15匹分)なので、探索すれば十分な戦力が作れる
- 難易度思想(ユーザー確定): **直行すると負ける/探索と工夫で勝てる/道中も考え無しだと負ける/プレイスキルで決まる/やり方が複数ある**

## 5. コード地図(主要行)

※ 2026-07-13の追加で行番号は大きくズレた。関数名でgrepするのが確実。主な追加関数:
`addMoundRing / addNestNode / addBigHouse`(巣・砦) / `updateCells`(ひき打ち) / `syncLegLoss`(自切) / `spawnLegDebrisMesh / dropSeveredLeg / rebuildLegDebris`(残る脚) / `gameOver / runDeath / makeGroundWord`(敗北演出) / `startBGM / playBGMCurrent / setVol / setMuted`(BGM・音量UI)

旧マップ(参考・要grep): ステージ寸法・グリッド / groundH / frameCamera(camPan追加) / addAccessPoint / buildRocks(巣/砦/HQ/通常の4分岐) / pushOutOfRocks / addRim / class Harvestman / WEAPONS / CAPTAIN_WPN / allyBlocks / class Human / spawnBullet / popText / showClearText / makeCorpseMesh / makeBugMesh / buildItems(巣は中央corpse) / makeCell(5/3/10人) / spawnHumans(巣/砦/preHQ/HQ/通常) / startEnding / runEnding / updateMinimap(nest緑) / goToStage / buildTitle / startGame(BGM発火) / step / デバッグフック

## 6. 残タスク

**保留中(ユーザー合意、勝手に始めない)**:
- SE(効果音: 捕食・被弾・制圧等)。BGMは実装済み(§8)
- 落書きギミック(草むら=子どもが隠れて弾回避、水たまり=スロー等。白い紙に黒ペンの落書き線画で「見た目=ギミック」を一体化する方針)
- 成体スキル(実生態由来: 威嚇の分泌液=範囲スロー等)
- ファーム要素の拡張(巣の仕組みは§8で最小実装済み。制圧地の巣化・備蓄はv2)

**改善候補(小粒)**:
- カメムシの触角が地形の起伏に埋まることがある
- エンディングspread中の成体が岩に群がる動きはもう少し「襲ってる感」を出せる
- リザルトにプレイ時間や被弾数を足す余地

## 7. ユーザーとの作業の流儀

- 修正案は画像付き指示書でくることが多い。**鵜呑みにせず取捨選択してよい**が、切り捨てた場合は理由を添えて報告する
- ユーザーが調整した塩梅(OPの虫の量、カメラの引き具合zoomScale=1.18、クリック移動+半径3.2自動追尾、有限POP)は**確定仕様**。勝手に変えない
- 変更のたびに`__shot()`で視認確認+数値検証してから報告する。バランスは実測で語る
- 全体検証は「新規→OP→序盤→(__kids/__damageチートで)本拠地→エンディング」の通しが基本
- **ユーザーは非プログラマ**。git/コミット/専門用語は噛み砕いて説明する

## 8. 2026-07-13 追加分の仕様(すべて実装・検証済み)

### 敵AI強化
- **索敵レンジの難度スケール**: `Human.senseR = 5 + max(0, d-2)*2`(d≤2は5、以降+2ずつ)。scaredの閾値に使用
- **編成セルのひき打ち**: `updateCells(dt)` がセルのアンカーを可動化。敵を向いて構え、`kiteR`(5、並列陣は6.5)より近寄られたら陣形を保ったまま`retreatMax`まで後退、離れれば`homeAx/Az`へ復帰。各兵は動くスロットへ追従し常に正面を向くのでひき打ちになる。`activeCells[]`で管理(spawnHumans先頭でクリア)
- **10人並列陣**(d7の2ステージ=(4,3)/(3,4)): `makeCell(...,10)`で前列5+後列5。隊長は`rearGuard=true`で後方(距離9〜13)に控え、`weapon.range=20`に拡張
- **砦(4,0)**: `buildRocks`で大きな家(`addBigHouse`, rocksに追加)+岩の壁(隘路1箇所)。守備隊12はカウント対象。**clear後も家が5秒おきにpistol兵を排出**(humans<12)、**入場ごとに家周辺へ非武装3体**。排出兵/非武装は`h.uncounted=true`で残数・制圧に影響しない
- **制圧判定を変更**: `humans.length===0`ではなく`stageRemain===0 && !stageFlags[k].cleared`で成立(湧き兵が残っていてもclearできる)
- 人数増量: 非HQは`5 + d*2 + (d>=4 ? (d-3)*3 : 0)`。d7=31、本拠地=34。武装率テーブルもd7まで延長

### 巣(0,1) — 子ども全滅時の詰み回避
- ミニマップ常時緑(`.mm.nest`)。中央を盛り土リング(`addMoundRing`, 当たり判定なし)で囲み、中央に成体の死骸アイテム
- 死骸を食べると`nestUnlocked=true`+巣ノード(`addNestNode`)出現。ノードに近づく(半径2.8)と**即1匹→5秒ごとに最大5匹まで**補充。巣の子は`s.fromNest=true`で別枠カウント、減ればまた5匹まで補充
- 関連: `nestNode/nestLight/nestUnlocked/nestSpawnT`

### 脚の自切(ダメージ表現)
- `LEG_AUTOTOMY=true`(安全弁: falseで従来8本脚)、`LEG_LOST_MAX=3`。損失数=`clamp(maxHp-hp,0,3)`。`syncLegLoss()`が毎フレーム同期(成体のみ)
- **歩脚はpair 0,2,3**(pair1は触角/sensory)。落とす順は`[[2,-1],[2,1],[0,-1],[0,1],[3,-1],[3,1]]`=左右交互でバランス維持。**pairを間違えると偏る**(以前のバグ)
- 落ちた脚は`legStore[skey]`に保存して**ずっと残る**(`rebuildLegDebris`でステージ復元)。歩行は表示のみなので破綻しない(this.posは脚に非依存)

### 敗北演出
- `gameOver()`は即リロードせず`death`状態を開始。`step`先頭で`runDeath(dt)`へ分岐。フェーズ: 灰色化(`#grayout`=saturation blend, `#graydark`)→成体にズームイン(`camPanX/Z`+zoomScale)→倒れ込み+1本の脚(`adult._twitchLeg`)がひくひく→地面に「Bust...」(clearと同スタイル`makeGroundWord`)→約3.4秒後「クリックでやり直し」。クリックで`location.reload()`

### 見た目
- 影を少し薄く: HemisphereLight 0.9→1.06 / DirectionalLight 1.55→1.42

### BGM(§音まわり)
- `BGM/` の3曲(`01Mosslight Hush.mp3`/`02Slow Salt Drift.mp3`/`03Forest Drift.mp3`)を**順番に再生→3曲目の次は1曲目にループ**。`startBGM()`をタイトルのstartクリックで発火(自動再生ポリシー対策)。1.5秒フェードイン
- **右上に音量UI**(`#audioui`): ミュートボタン(🔊/🔇)+音量スライダー。`M`キーでもミュート。`bgmVol/bgmMuted`。パネルは`pointerdown`をstopPropagationして盤面に抜けないようにしている
- **配信サーバ対応が必須**: `.claude/serve-zatoumushi.ps1`(動作中)と`serve.ps1`(リポジトリ)両方に、MIMEへ`.mp3=audio/mpeg`等を追加+`UnescapeDataString`でスペース入りファイル名対応済み。**serve.ps1を編集したらpreview_stop→preview_startでサーバ再起動が必要**(HttpListenerは編集を再読込しない)
