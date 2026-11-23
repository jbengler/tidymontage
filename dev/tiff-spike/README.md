# TIFF reading spike (2026-11-23)

Throwaway scripts that checked whether `tiff` (0.1.12) is enough for the TIFF
backend. Run from this folder; `01`–`05`, `07` and `08` expect the files in
`demo_images/`.

- `ifd.R` – minimal pure-R TIFF/BigTIFF IFD walker (`read_ifds()`, `read_tag_raw()`).
  Seed for the metadata reader.
- `writer.R` – minimal uncompressed 16-bit TIFF/BigTIFF writer. Seed for tiny
  synthetic test fixtures.

## Findings

Pixels: `tiff` is enough.

- `readTIFF(path, all = idx, as.is = TRUE)` reads only the requested pages, in
  the requested order, as exact 16-bit integers (~10 ms per 1796² page).
- BigTIFF works (tested on a synthetic file).
- ImageJ hyperstack page index (CZT order): `(t - 1) * C * Z + (z - 1) * C + c`.
- Palette images (photometric = 3): `as.is = TRUE` applies the ColorMap and
  returns RGB. Use `indexed = TRUE` and subtract 1 to get raw values.
- No region reads: crop after reading the full page. One page as an R integer
  matrix is ~12 MB, so projections should keep a running max page by page.

Metadata: `tiff` is not enough, use our own IFD parser.

- `readTIFF(payload = FALSE, info = TRUE, all = TRUE)` returns one row per page
  but only the first `ImageDescription`, and ignores ImageJ private tags.
- ImageJ private tags 50838 (byte counts) / 50839 (data, header `IJIJ`) hold
  `info` (UTF-16 text, here the full ZEN metadata via Bio-Formats), `labl`
  (slice labels), `rang` (display ranges, doubles), `luts` (256×3 bytes per
  channel). ImageJ writes big-endian files.
- ZEN metadata in `info` gives channel names, fluors (Cy3, AF488, DAPI),
  excitation/emission wavelengths and pixel size (`Scaling|Distance|Value`, m).
- Proposed metadata tiers: OME-XML → ImageJ private tags → ImageJ description
  → TIFF ColorMap / resolution tags → user.

OME-TIFF (`*.ome.tif`, Fiji > Save As > OME-TIFF, scripts `07`, `08`):

- Bio-Formats picks the writer from the extension: only `.ome.tif(f)` gets
  OME-XML. The `*_OME.tif` files are plain Bio-Formats TIFFs (ImageJ-style
  description + 16-bit ColorMap per page) and are kept as test data for that case.
- OME-XML (145 KB) is the `ImageDescription` of IFD 1; little-endian; one Image.
- `Pixels`: `DimensionOrder`, `SizeX/Y/Z/C/T`, `PhysicalSizeX/Y/Z` + unit (`µm`),
  `Type = uint16`. `TiffData` maps (C, Z, T) to IFD index explicitly.
- `Channel`: `Name`, `Fluor`, excitation/emission wavelengths, and `Color` as a
  signed 32-bit RGBA integer (here magenta, green, white).
- `StructuredAnnotations` carries the ZEN original metadata (570 entries).
- Bio-Formats also writes a ColorMap here, so pages are palette images: read
  with `indexed = TRUE` and subtract 1. Values then match the ImageJ export
  exactly (the result carries a `color.map` attribute, so drop it before
  comparing with `identical()`).
- Parse the XML from **raw bytes** (`xml2::read_xml(raw)`). Going through
  `rawToChar()` breaks in a non-UTF-8 locale: R escapes the `µ` bytes as
  `<c2><b5>` and xml2 fails with "Unescaped '<' not allowed in attributes values".

ImageJ z-stack (`DIV14Actin-01-Airyscan Processing-02.tif`, scripts `09`, `10`):

- 2024², 16-bit, big-endian, 4 channels × 7 slices = 28 IFDs, 230 MB.
  Walking all IFDs with `read_ifds()` takes ~0.07 s.
- Description: `channels=4`, `slices=7`, no `frames=` (so T = 1),
  `spacing=1.8` (z step, in `unit`), `unit=micron`; x/y resolution 14.1363 px/µm.
- Slice labels (`labl`, one per page) confirm CZT order: `c:1/4 z:1/7`,
  `c:2/4 z:1/7`, … The formula `(t-1)*C*Z + (z-1)*C + c` matches all 28.
- `rang` is 0–65535 for every channel (Fiji default), so it says nothing about
  a sensible display range.
- ZEN colours in `info` are `#AARRGGBB` (alpha first), e.g. `#FFFF00FF` = magenta.
  `luts` agree: magenta, red, green (`0,255,51`), blue.
- Max projection, one channel (7 pages, 2024²): 0.19 s streaming page by page,
  0.13 s in one `readTIFF()` call. All 4 channels < 1 s. One plane = 15.6 MB.
- `ij.R` – `read_ij_meta()` (decodes the ImageJ private tags into a list) and
  `read_description()` (raw bytes of the first `ImageDescription`).
- Fiji's OME-TIFF export of this stack crashed (`NumberFormatException: "8,16"`,
  probably a decimal comma from the German locale), so there is no OME-TIFF z-stack.

Test data gaps:

- No time series yet, and no OME-TIFF with more than one plane per channel.
