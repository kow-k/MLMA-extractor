# MLMA extractor (語構成の多重アノテーション解析)

# Script

Multi-layered Morphological Analysis (MLMA) 記法の語構成要素アノテーションから語構成要素を抽出するための Perl script

1. [MLMA extractor](mlma-extractor.pl)

## 実行

`perl mlma-extractor.pl <FILE>`

重要なオプション -r(egularize) と -g(entle)

-r(egularize) は不連続要素の認識を無効化 [後述]
-g(entle) は細分化を抑制 [後述]

FILE には MLMA 記法で語構成が記述してあるとする．

# MLMA 記法

境界記号の優先順位を <...>, [...], {...}, (...) と定めた上であれば，多重構造アノテーションのアルゴリズムは次の通り:

Step 1:
用語の(通常右端にある) 主要部 a  <...>で括り出し，それを元に修飾構造を遠心的に再帰的に認定する．

Step 2:
この境界認定で認識されない構成要素がある場合，a の左側に別の遠心構造の中心 b を見つけ，[...] を使って遠心構造を指定する．

Step 3:
上の2重分析で認定されない遠心構造がある場合，b の左側に別の遠心構造の中心 c を見つけ，{...} を使って遠心構造を指定する．

Step 4:
上の3重分析で認定されない遠心構造がある場合，c の左側に別の遠心構造の中心 d を見つけ，(...)  を使って遠心構造を指定する．

現実的には，3重以上の多重性が必要な場合，PDMA の利用を考える方が無難である (3重以上の多重性が発生する事例の割合は，サンプルデータ中で5%あるかないかのレベル)．

# MLMA の例

- <[ 焼身 < 自殺 ]< 未遂 >>>
- <[ 言語 < 発達 ]< 遅滞 >>>
- <[ 乳汁 < 分泌 ]< 抑制 >>>
- <[[ 十二指 [ 腸 ]][空 [ 腸 ]]]< 吻合 >>
- <[{( 冠状 ) <[{ 動 <[ 脈 }}< 硬化 ]]]< 症 >>>>>>

2. [MLMA 記法の見本](list2-sample-medterms-mlms.txt)

# 重要な動作オプション

## -regularize の効果

デフォールトでは A ~ B ~ C の表記を使って，AC を不連続要素として認識するが，実装は quick and dirty なので，不自然な出力が得られる可能性大．-r(egularize) で入力中の ~ を無視した処理が可能．

## -gentle の効果

MLMA-extractor.pl はデフォールトで別のモードでの下位分割を抑制する．

<[集中<治療]<室>>> の default (= -g なし) 解析結果:

```
## summary:
item 11 has component  1: 室
item 11 has component  2: 治療
item 11 has component  3: 治療室
item 11 has component  4: 集中
item 11 has component  5: 集中治療室
```

-gentle は別のモードの境界を無視する．<[集中<治療]<室>>> の -g あり解析結果:

```
## summary:
item 11 has component  1: 室
item 11 has component  2: 治療室
item 11 has component  3: 集中治療室
```
