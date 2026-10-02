## Decoders for the compact property tables in proptables.nim.
##
## A range list is a sorted, merged seq[int] of inclusive [lo, hi] pairs.
## proptables.nim stores them as delta-encoded base-32 varints; the case
## maps (simple case folding, simple uppercase) as delta-coded key/delta pairs.

import ./proptables

proc rangeDigit(c: char): int {.inline.} =
  if c >= '0' and c <= '9': ord(c) - 48
  elif c >= 'A' and c <= 'Z': ord(c) - 55
  elif c >= 'a' and c <= 'z': ord(c) - 61
  elif c == '+': 62
  else: 63

proc readVarint(s: string; i: var int): int =
  result = 0
  var shift = 0
  while i < s.len:
    let d = rangeDigit(s[i])
    inc i
    result = result or ((d and 31) shl shift)
    shift += 5
    if d < 32: break

proc decodeRanges*(s: string): seq[int] =
  ## One encoded range list -> flat [lo, hi] pairs.
  result = @[]
  var i = 0
  var prev = 0
  while i < s.len:
    let a = prev + readVarint(s, i)
    let b = a + readVarint(s, i)
    result.add a
    result.add b
    prev = b + 1

var
  propCache: seq[seq[int]] = @[]
  propDone: seq[bool] = @[]

proc propRanges*(idx: int): seq[int] =
  ## The decoded range list rxData[idx] (cached). Indices come from the
  ## rx*Idx tables (general category, script, script extensions, binary
  ## properties, properties of strings).
  if propCache.len == 0:
    for k in 0 ..< rxData.len:
      propCache.add @[]
      propDone.add false
  if not propDone[idx]:
    let d = decodeRanges(rxData[idx])
    propCache[idx] = d
    propDone[idx] = true
  propCache[idx]

proc propLookupName*(names: openArray[string]; idxs: openArray[int]; nm: string): int =
  ## Index into rxData of property value `nm` in a (names, idxs) table pair, or -1.
  for k in 0 ..< names.len:
    if names[k] == nm: return idxs[k]
  -1

var
  foldSrc*: seq[int] = @[]    ## simple case folding: sorted sources
  foldDst*: seq[int] = @[]
  upSrc*: seq[int] = @[]      ## Canonicalize uppercase map: sorted sources
  upDst*: seq[int] = @[]
  caseMapsReady = false

proc decodeMap(s: string; src, dst: var seq[int]) =
  var i = 0
  var prev = 0
  while i < s.len:
    let k = prev + readVarint(s, i)
    let d = readVarint(s, i)
    let delta = if (d and 1) == 1: -(d shr 1) else: d shr 1
    src.add k
    dst.add k + delta
    prev = k + 1

proc initCaseMaps*() =
  ## Decode foldSrc/foldDst and upSrc/upDst (idempotent).
  if caseMapsReady: return
  decodeMap(rxFoldMap, foldSrc, foldDst)
  decodeMap(rxUpperMap, upSrc, upDst)
  caseMapsReady = true

proc caseMapLookup*(src, dst: seq[int]; c: int): int =
  ## dst[i] where src[i] == c, else c itself.
  var lo = 0
  var hi = src.len - 1
  while lo <= hi:
    let mid = (lo + hi) shr 1
    let v = src[mid]
    if v == c: return dst[mid]
    if v < c: lo = mid + 1
    else: hi = mid - 1
  c

proc simpleFold*(c: int): int =
  ## Unicode simple case folding (CaseFolding.txt C+S).
  initCaseMaps()
  caseMapLookup(foldSrc, foldDst, c)

proc canonUpper*(c: int): int =
  ## Simple uppercase mapping as ECMA-262 Canonicalize (non-u) uses it: a
  ## mapping to more than one code point, or from non-ASCII to ASCII, is
  ## dropped (the result is c itself).
  initCaseMaps()
  caseMapLookup(upSrc, upDst, c)
