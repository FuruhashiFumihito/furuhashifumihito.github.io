---
layout: publication
lang: ja
title: "DG-PINN: Differential Game Based Physics-Informed Neural Network for Vehicle Trajectory Prediction"
authors: "Fumihito Furuhashi"
venue: "2025 IEEE 28th International Conference on Intelligent Transportation Systems (ITSC)"
year: 2025
type: conference

# Graphical abstract: 論文ページ冒頭に大きく表示される代表画像。
# 画像ファイルは assets/images/publications/dg-pinn-itsc/ に置く想定。
graphical_abstract:
  src: /assets/images/publications/dg-pinn-itsc/graphical-abstract.png
  alt_ja: "DG-PINN のグラフィカル・アブストラクト: 微分ゲームによる均衡制約と PINN を組み合わせた軌道予測の概要図"
  alt_en: "DG-PINN graphical abstract: differential-game equilibrium constraints coupled with a PINN for trajectory prediction"

# 論文中で使用した図。caption_ja / caption_en を記述するとページ言語に応じて
# 切り替わります。caption のみの場合は言語問わず同じ文言が使われます。
figures:
  - src: /assets/images/publications/dg-pinn-itsc/fig1-architecture.png
    caption_ja: "DG-PINN のネットワーク構成。共有エンコーダが周辺車両の状態系列を埋め込み、微分ゲームの均衡条件を損失項として埋め込んだ PINN デコーダが将来軌道を予測する。"
    caption_en: "Network architecture of DG-PINN. A shared encoder embeds surrounding-vehicle state sequences, and a PINN decoder trained with the equilibrium conditions of a differential game as physics losses predicts the future trajectory."
  - src: /assets/images/publications/dg-pinn-itsc/fig2-loss.png
    caption_ja: "学習に用いた損失関数の内訳。データ適合項に加え、ハミルトン-ヤコビ-アイザックス方程式に由来する均衡制約をソフト制約として与える。"
    caption_en: "Decomposition of the training loss: a data-fidelity term plus soft constraints derived from the Hamilton–Jacobi–Isaacs equilibrium conditions of the differential game."
  - src: /assets/images/publications/dg-pinn-itsc/fig3-results.png
    caption_ja: "高速道路データセットにおける予測軌道の定性比較。既存の回帰型ベースラインに比べ、相互作用下での振る舞いがより物理的に整合的になる。"
    caption_en: "Qualitative comparison of predicted trajectories on a highway dataset. Compared with a purely regression-based baseline, DG-PINN yields interactions that are more physically consistent."

links:
  paper: "https://doi.org/10.1109/ITSC60802.2025.11423521"

abstract: "車両軌道予測は、自動運転車の安全性と快適性を左右する基礎技術である。本稿では、周辺車両との相互作用を非協力微分ゲームとして定式化し、その均衡条件を物理情報ニューラルネットワーク(PINN)の損失項として組み込む DG-PINN を提案する。純粋なデータ駆動手法では説明しにくい譲り合いや加減速挙動に対して、微分ゲーム由来の構造的制約を課すことで、予測の物理整合性と汎化性能を同時に改善することを目指す。"

bibtex: |
  @inproceedings{furuhashi2025dgpinn_itsc,
    author    = {Furuhashi, Fumihito},
    title     = {DG-PINN: Differential Game Based Physics-Informed Neural Network for Vehicle Trajectory Prediction},
    booktitle = {2025 IEEE 28th International Conference on Intelligent Transportation Systems (ITSC)},
    year      = {2025},
    month     = nov,
    address   = {Australia},
    doi       = {10.1109/ITSC60802.2025.11423521}
  }
---
