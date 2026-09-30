## UAX #29 break-property lookups (grapheme / word / sentence break,
## Extended_Pictographic, Indic_Conjunct_Break) over the tables in segdata.nim.
## The numeric values are the ones gen_intl_seg.py assigns (see segdata.nim).

import ./segdata

var
  segTabsReady = false
  segTabGB: seq[int] = @[]
  segTabWB: seq[int] = @[]
  segTabSB: seq[int] = @[]
  segTabEP: seq[int] = @[]
  segTabInCB: seq[int] = @[]

proc segHex(s: string; a, b: int): int =
  result = 0
  for k in a ..< b:
    let c = s[k]
    let d = (if c >= '0' and c <= '9': ord(c) - ord('0') else: ord(c) - ord('a') + 10)
    result = result * 16 + d

proc parseSegTable*(data: string): seq[int] =
  ## "first:length:value" hex entries, first delta-coded -> flat triples
  ## (first, last, value).
  result = @[]
  var prev = 0
  var i = 0
  while i < data.len:
    var e = i
    while e < data.len and data[e] != ',': inc e
    var c1 = i
    while c1 < e and data[c1] != ':': inc c1
    var c2 = c1 + 1
    while c2 < e and data[c2] != ':': inc c2
    if c1 < e and c2 < e:
      let a = prev + segHex(data, i, c1)
      result.add a
      result.add a + segHex(data, c1 + 1, c2)
      result.add segHex(data, c2 + 1, e)
      prev = a
    i = e + 1

proc initSegTabs*() =
  if segTabsReady: return
  segTabsReady = true
  segTabGB = parseSegTable(segGraphemeProps)
  segTabWB = parseSegTable(segWordProps)
  segTabSB = parseSegTable(segSentenceProps)
  segTabEP = parseSegTable(segExtPict)
  segTabInCB = parseSegTable(segInCB)

proc rangeLookup*(tbl: seq[int]; cp: int): int =
  ## Binary search in a flat (first, last, value) triple table; 0 if absent.
  var lo = 0
  var hi = tbl.len div 3 - 1
  while lo <= hi:
    let mid = (lo + hi) div 2
    let a = tbl[mid * 3]
    let b = tbl[mid * 3 + 1]
    if cp < a: hi = mid - 1
    elif cp > b: lo = mid + 1
    else: return tbl[mid * 3 + 2]
  0

proc gbOf*(cp: int): int =
  ## Grapheme_Cluster_Break value.
  initSegTabs()
  rangeLookup(segTabGB, cp)
proc wbOf*(cp: int): int =
  ## Word_Break value.
  initSegTabs()
  rangeLookup(segTabWB, cp)
proc sbOf*(cp: int): int =
  ## Sentence_Break value.
  initSegTabs()
  rangeLookup(segTabSB, cp)
proc isExtPict*(cp: int): bool =
  initSegTabs()
  rangeLookup(segTabEP, cp) != 0
proc incbOf*(cp: int): int =
  ## Indic_Conjunct_Break value.
  initSegTabs()
  rangeLookup(segTabInCB, cp)
