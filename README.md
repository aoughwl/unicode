# unicode

Pure Unicode 17.0.0 data and lookups for [nimony](https://github.com/nim-lang/nimony),
extracted from the aowljs JavaScript engine. No dependencies beyond nimony's std.

| module | contents |
|---|---|
| `unicode/unidata` | generated tables: simple + multi-code-point upper/lower case maps, canonical combining class, (compatibility) decompositions, canonical compositions |
| `unicode/casenorm` | `convertCaseCps` (full default toUpper/toLower incl. Final_Sigma), `normalizeCps` (NFC/NFD/NFKC/NFKD incl. Hangul), `cccOf`, `isCased`, `isCaseIgnorable`, `bsearchPairs`, `initUnicode` |
| `unicode/proptables` | generated property tables used by ECMAScript regexps: General_Category, Script, Script_Extensions, binary properties, properties of strings (RGI emoji sequences), simple case folding and the Canonicalize uppercase map |
| `unicode/ranges` | decoders for `proptables`: `decodeRanges`, `propRanges(idx)`, `propLookupName`, `simpleFold`, `canonUpper`, `initCaseMaps` / `caseMapLookup` with `foldSrc/foldDst/upSrc/upDst` |
| `unicode/segdata` | generated UAX #29 break properties (grapheme / word / sentence, Extended_Pictographic, Indic_Conjunct_Break) |
| `unicode/segment` | lookups over `segdata`: `gbOf`, `wbOf`, `sbOf`, `isExtPict`, `incbOf`, `parseSegTable`, `rangeLookup` |

Code points are plain `int`s; range lists are flat `seq[int]` of inclusive `[lo, hi]` pairs.

```nim
import unicode/[casenorm, ranges, segment]
echo normalizeCps(@[0x65, 0x301], compose = true, compat = false)   # @[0xE9]
echo simpleFold(0x212A)                                              # 0x6B
echo isExtPict(0x1F600)                                              # true
```

## Regenerating the tables

- `unidata.nim`: `python3 tools/gen_unidata.py --ucd DIR 17.0.0` (UnicodeData.txt, SpecialCasing.txt from the UCD).
- `segdata.nim`: `python3 tools/gen_intl_seg.py` (see the script header for the UCD files it reads).
- `proptables.nim`: generated from the Unicode 17.0.0 UCD by a script that was not preserved
  in the engine repository; the encoding is documented in `ranges.nim`.

## Test

```sh
nimony c -p:src tests/test_unicode.nim   # then run the binary from the nimcache
```

Used by [regex](https://github.com/aoughwl/regex) and the aowljs engine.
