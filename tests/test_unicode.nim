## Run: nimony c -p:src tests/test_unicode.nim  (then the binary)
import std/syncio
import unicode/[unidata, casenorm, segment, ranges, proptables]

var failures = 0
var total = 0
proc ok(cond: bool; what: string) =
  inc total
  if not cond:
    echo "FAIL ", what
    inc failures

ok(convertCaseCps(@[0x61, 0xDF], true) == @[0x41, 0x53, 0x53], "upper ß -> SS")
ok(convertCaseCps(@[0x391, 0x3A3], false) == @[0x3B1, 0x3C2], "final sigma")
ok(convertCaseCps(@[0x3A3], false) == @[0x3C3], "lone sigma")
ok(normalizeCps(@[0x65, 0x301], true, false) == @[0xE9], "NFC compose")
ok(normalizeCps(@[0xE9], false, false) == @[0x65, 0x301], "NFD decompose")
ok(normalizeCps(@[0xFB01], false, true) == @[0x66, 0x69], "NFKD ligature")
ok(normalizeCps(@[0xAC00], false, false) == @[0x1100, 0x1161], "Hangul decompose")
ok(normalizeCps(@[0x1100, 0x1161, 0x11A8], true, false) == @[0xAC01], "Hangul LVT compose")
ok(cccOf(0x301) == 230, "ccc of U+0301")
ok(isCased(0x41) and not isCased(0x31), "isCased")
ok(simpleFold(0x212A) == 0x6B, "fold Kelvin")
ok(simpleFold(0x41) == 0x61, "fold A")
ok(canonUpper(0x17F) == 0x17F, "long s: no non-ASCII -> ASCII")
ok(canonUpper(0xE9) == 0xC9, "upper e-acute")
let lu = propRanges(propLookupName(rxGcNames, rxGcIdx, "Lu"))
var hasA = false
var k = 0
while k + 1 < lu.len:
  if lu[k] <= 0x41 and 0x41 <= lu[k+1]: hasA = true
  k += 2
ok(hasA, "Lu contains A")
ok(isExtPict(0x1F600), "emoji is Extended_Pictographic")
ok(not isExtPict(0x41), "A is not Extended_Pictographic")
ok(gbOf(0x0D) != gbOf(0x0A) and gbOf(0x41) == 0, "grapheme break props")
ok(wbOf(0x41) != 0, "word break of A")
ok(sbOf(0x2E) != 0, "sentence break of .")
ok(upperSimple.len > 0 and composeData.len > 0, "tables present")

echo total - failures, "/", total, " passed"
if failures > 0: quit 1
