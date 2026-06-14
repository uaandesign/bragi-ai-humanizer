#!/usr/bin/env bash
# Bragi 破绽尺：扫一段文字里的 AI 腔破绽词/句式，给出密度报告。
# 用途：改写前后各跑一遍，用命中数的下降证明"去味"真见效（别凭感觉说"更像人话了"）。
# 只读，不改文件。
#
# 用法: ai-tells-lint.sh <文件>           # 读文件
#       cat draft.md | ai-tells-lint.sh -  # 读 stdin
# 不用 set -e：grep 无命中时退出 1 是正常的（这是报告脚本，空命中不该中止）
set -uo pipefail
export LC_ALL="$(locale -a 2>/dev/null | grep -im1 -E '^(en_US|C)\.UTF-?8$' || echo C)"

SRC="${1:?用法: ai-tells-lint.sh <文件|->}"
if [ "$SRC" = "-" ]; then TEXT="$(cat)"; else TEXT="$(cat "$SRC")"; fi

# 字数（去空白）与句数：BSD grep/wc 对多字节字符类不可靠，优先用 python3 按字符算
if command -v python3 >/dev/null 2>&1; then
  stats=$(printf '%s' "$TEXT" | python3 -c 'import sys,re; t=sys.stdin.read(); print(len(re.sub(r"\s","",t)), max(1,len(re.findall(r"[。！？.!?]",t))))')
  chars=${stats% *}; sentences=${stats#* }
else
  chars=$(printf '%s' "$TEXT" | tr -d '[:space:]' | wc -m | tr -d ' ')
  sentences=$(printf '%s' "$TEXT" | grep -oE '[。！？.!?]' | wc -l | tr -d ' ')
  [ "$sentences" -eq 0 ] && sentences=1
fi

# 破绽词库（命中即计数）
HOLLOW='赋能|抓手|组合拳|闭环|生态|范式|链路|心智|势能|沉淀|对齐|拉通|颗粒度|方法论|底层逻辑|顶层设计|护城河|第一性原理|维度|纵深|全方位|系统性|深层次|端到端|一体化|强有力'
TRANS='值得注意的是|总的来说|总而言之|综上所述|不难发现|由此可见|众所周知|首先|其次|最后|一方面|另一方面'
OPENER='随着.{0,8}的(快速)?发展|在.{0,8}的背景下|在.{0,6}浪潮下|近年来|当今时代'
PARALLEL='不仅.{0,20}更|既.{0,12}又|是.{0,8}更是|既是.{0,12}也是'
ADJINFL='强大的|全面的|深入的|卓越的|显著的?|重要的意义|巨大的|极大地|有力地|扎实地|切实地|持续(优化|提升|推进)|不断(优化|提升|完善)'

count() { printf '%s' "$TEXT" | grep -oE "$1" 2>/dev/null | wc -l | tr -d ' '; }
c_hollow=$(count "$HOLLOW")
c_trans=$(count "$TRANS")
c_opener=$(count "$OPENER")
c_parallel=$(count "$PARALLEL")
c_adj=$(count "$ADJINFL")
total=$((c_hollow + c_trans + c_opener + c_parallel + c_adj))

# 每百字密度
density=$(awk "BEGIN{printf \"%.1f\", $total*100/($chars==0?1:$chars)}")

echo "## Bragi 破绽尺"
echo "- 字数: $chars  句数: $sentences"
echo "- 破绽总命中: $total   密度: ${density} / 百字"
echo ""
echo "| 类别 | 命中 |"
echo "|---|---:|"
echo "| 空心大词（赋能/抓手/闭环…） | $c_hollow |"
echo "| 万能过渡句（值得注意的是…） | $c_trans |"
echo "| 套话开头（随着…的发展） | $c_opener |"
echo "| 排比对仗（不仅…更…） | $c_parallel |"
echo "| 形容词/决心通胀（卓越/持续优化） | $c_adj |"
echo ""

# 命中样例（最多 8 条，带上下文，方便定位）
echo "### 命中样例（最多 8 条）"
printf '%s' "$TEXT" | grep -onE "$HOLLOW|$TRANS|$OPENER|$PARALLEL|$ADJINFL" 2>/dev/null \
  | head -8 | sed 's/^/- /' || echo "（无）"
echo ""
echo "> 改写后再跑一遍，密度应明显下降。注意：这把尺只扫显性破绽，"
echo "> 结构层（总分总、列点强迫症）和肤浅（泛化句）要靠人判断，尺量不到。"
