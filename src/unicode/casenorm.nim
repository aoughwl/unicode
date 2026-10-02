## Unicode case conversion and normalization over the tables in unidata.nim:
## simple/multi case maps, canonical combining class, NFC/NFD/NFKC/NFKD.

import std/tables
import ./unidata

proc bsearchPairs*(tbl: openArray[int32]; cp: int): int =
  ## Index of the pair whose first element is cp in a flat sorted pair table,
  ## or -1.
  var lo = 0
  var hi = tbl.len div 2 - 1
  while lo <= hi:
    let mid = (lo + hi) div 2
    let v = int(tbl[mid * 2])
    if v == cp: return mid * 2
    if v < cp: lo = mid + 1 else: hi = mid - 1
  -1

var
  upperMultiIdx* = initTable[int, int]()
  lowerMultiIdx* = initTable[int, int]()
  decompIdx* = initTable[int, int]()
  composeIdx* = initTable[int, int]()
  unicodeReady* = false

proc initUnicode*() =
  if unicodeReady: return
  unicodeReady = true
  var i = 0
  while i < upperMulti.len:
    upperMultiIdx[int(upperMulti[i])] = i
    i += 2 + int(upperMulti[i + 1])
  i = 0
  while i < lowerMulti.len:
    lowerMultiIdx[int(lowerMulti[i])] = i
    i += 2 + int(lowerMulti[i + 1])
  i = 0
  while i < decompData.len:
    decompIdx[int(decompData[i])] = i
    i += 3 + int(decompData[i + 2])
  i = 0
  while i < composeData.len:
    composeIdx[int(composeData[i]) * 0x200000 + int(composeData[i + 1])] = int(composeData[i + 2])
    i += 3

proc cccOf*(cp: int): int =
  if cp < 0x300: return 0
  let k = bsearchPairs(combiningClass, cp)
  if k < 0: 0 else: int(combiningClass[k + 1])

proc isCased*(cp: int): bool =
  bsearchPairs(upperSimple, cp) >= 0 or bsearchPairs(lowerSimple, cp) >= 0 or
    upperMultiIdx.hasKey(cp) or lowerMultiIdx.hasKey(cp) or
    (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x41 and cp <= 0x5A) or
    cp == 0xAA or cp == 0xBA or (cp >= 0x2B0 and cp <= 0x2B8) or
    (cp >= 0x2C0 and cp <= 0x2C1) or (cp >= 0x2E0 and cp <= 0x2E4) or
    cp == 0x345 or cp == 0x37A or (cp >= 0x1D2C and cp <= 0x1D6A) or
    cp == 0x1D78 or (cp >= 0x1D9B and cp <= 0x1DBF) or cp == 0x2071 or
    cp == 0x207F or (cp >= 0x2090 and cp <= 0x209C) or
    (cp >= 0x2160 and cp <= 0x217F) or (cp >= 0x24B6 and cp <= 0x24E9) or
    (cp >= 0x1D400 and cp <= 0x1D7CB) or (cp >= 0x1F130 and cp <= 0x1F149) or
    (cp >= 0x1F150 and cp <= 0x1F169) or (cp >= 0x1F170 and cp <= 0x1F189)

proc isCaseIgnorable*(cp: int): bool =
  # Word_Break MidLetter/MidNumLet/Single_Quote or Mn/Me/Cf/Lm/Sk
  if cp == 0x27 or cp == 0x2E or cp == 0x3A or cp == 0xB7 or cp == 0x387 or
     cp == 0x55F or cp == 0x5F4 or cp == 0x2018 or cp == 0x2019 or
     cp == 0x2024 or cp == 0xFE52 or cp == 0xFE55 or cp == 0xFF07 or
     cp == 0xFF0E or cp == 0xFF1A or cp == 0x2027 or cp == 0xFE13 or cp == 0xAD:
    return true
  if cp >= 0x300 and cp <= 0x36F: return true
  if cccOf(cp) != 0: return true
  if cp >= 0x2B0 and cp <= 0x2FF: return true
  if cp == 0x200B or cp == 0x200C or cp == 0x200D or cp == 0x200E or cp == 0x200F: return true
  # the rest of general category Cf (format controls)
  if (cp >= 0x600 and cp <= 0x605) or cp == 0x61C or cp == 0x6DD or cp == 0x70F or
     cp == 0x890 or cp == 0x891 or cp == 0x8E2 or cp == 0x180E or
     (cp >= 0x202A and cp <= 0x202E) or (cp >= 0x2060 and cp <= 0x2064) or
     (cp >= 0x2066 and cp <= 0x206F) or cp == 0xFEFF or (cp >= 0xFFF9 and cp <= 0xFFFB) or
     cp == 0x110BD or cp == 0x110CD or (cp >= 0x13430 and cp <= 0x1343F) or
     (cp >= 0x1BCA0 and cp <= 0x1BCA3) or (cp >= 0x1D173 and cp <= 0x1D17A) or
     cp == 0xE0001 or (cp >= 0xE0020 and cp <= 0xE007F):
    return true
  false

# --- normalization -------------------------------------------------------------

const
  SBase = 0xAC00
  LBase = 0x1100
  VBase = 0x1161
  TBase = 0x11A7
  LCount = 19
  VCount = 21
  TCount = 28
  NCount = VCount * TCount
  SCount = LCount * NCount

proc decomposeCp*(cp: int; compat: bool; outp: var seq[int]) =
  if cp >= SBase and cp < SBase + SCount:
    let sIndex = cp - SBase
    outp.add LBase + sIndex div NCount
    outp.add VBase + (sIndex mod NCount) div TCount
    let t = TBase + sIndex mod TCount
    if t != TBase: outp.add t
    return
  let d = decompIdx.getOrDefault(cp, -1)
  if d >= 0 and (int(decompData[d + 1]) == 0 or compat):
    for k in 0 ..< int(decompData[d + 2]):
      decomposeCp(int(decompData[d + 3 + k]), compat, outp)
    return
  outp.add cp

proc normalizeCps*(cps: seq[int]; compose: bool; compat: bool): seq[int] =
  initUnicode()
  var d: seq[int] = @[]
  for cp in cps: decomposeCp(cp, compat, d)
  # canonical ordering: stable sort runs of non-starters by ccc
  var i = 0
  while i < d.len:
    if cccOf(d[i]) == 0:
      inc i
      continue
    var j = i
    while j < d.len and cccOf(d[j]) != 0: inc j
    # insertion sort d[i..<j]
    for a in i + 1 ..< j:
      let x = d[a]
      let cx = cccOf(x)
      var b = a
      while b > i and cccOf(d[b - 1]) > cx:
        d[b] = int(d[b - 1] + 0)
        dec b
      d[b] = x
    i = j
  if not compose: return d
  # canonical composition
  result = @[]
  var starterPos = -1
  var lastCcc = -1
  for cp in d:
    let c = cccOf(cp)
    if starterPos >= 0:
      let st = result[starterPos]
      var composed = -1
      # Hangul LV / LVT
      if st >= LBase and st < LBase + LCount and cp >= VBase and cp < VBase + VCount and
         lastCcc == -1:
        composed = SBase + ((st - LBase) * VCount + (cp - VBase)) * TCount
      elif st >= SBase and st < SBase + SCount and ((st - SBase) mod TCount) == 0 and
           cp > TBase and cp < TBase + TCount and lastCcc == -1:
        composed = st + (cp - TBase)
      else:
        let blocked = lastCcc != -1 and (lastCcc == 0 or lastCcc >= c)
        if not blocked:
          composed = composeIdx.getOrDefault(st * 0x200000 + cp, -1)
      if composed >= 0:
        result[starterPos] = composed
        continue
    if c == 0:
      starterPos = result.len
      lastCcc = -1
    else:
      lastCcc = c
    result.add cp
    if c == 0: lastCcc = -1

# ---------------------------------------------------------------------------
# Helpers.

proc convertCaseCps*(cps: seq[int]; upper: bool): seq[int] =
  ## Full (default, locale-independent) toUpperCase / toLowerCase over code
  ## points, including the Final_Sigma context rule.
  initUnicode()
  var outp: seq[int] = @[]
  for i, cp in cps:
    if not upper and cp == 0x3A3:
      # Final_Sigma: preceded by a cased letter (skipping case-ignorables)
      # and not followed by one.
      var j = i - 1
      while j >= 0 and isCaseIgnorable(cps[j]): dec j
      let before = j >= 0 and isCased(cps[j])
      j = i + 1
      while j < cps.len and isCaseIgnorable(cps[j]): inc j
      let after = j < cps.len and isCased(cps[j])
      if before and not after:
        outp.add 0x3C2
      else:
        outp.add 0x3C3
      continue
    if upper:
      let m = upperMultiIdx.getOrDefault(cp, -1)
      if m >= 0:
        for k in 0 ..< int(upperMulti[m + 1]): outp.add int(upperMulti[m + 2 + k])
        continue
      let p = bsearchPairs(upperSimple, cp)
      outp.add (if p >= 0: int(upperSimple[p + 1]) else: cp)
    else:
      let m = lowerMultiIdx.getOrDefault(cp, -1)
      if m >= 0:
        for k in 0 ..< int(lowerMulti[m + 1]): outp.add int(lowerMulti[m + 2 + k])
        continue
      let p = bsearchPairs(lowerSimple, cp)
      outp.add (if p >= 0: int(lowerSimple[p + 1]) else: cp)
  outp
