# Getting your images in

tidymontage reads **TIFF** and **OME-TIFF** files. Microscopes usually
save their own formats, such as CZI (Zeiss), ND2 (Nikon), LIF (Leica) or
OIR (Olympus). This article shows how to convert them to OME-TIFF, the
format tidymontage reads best: channel names, colours, pixel size and
z-steps are kept in its metadata.

## Single files: ZEN or Fiji

For a few files, export them from the microscope software or Fiji:

- **ZEN** (including the free ZEN lite): use its OME-TIFF export (in
  recent versions an *OME TIFF-Export* method under *Processing*; menus
  differ between ZEN versions).
- **Fiji**: open the file with Bio-Formats, then *File \> Save As \>
  OME-TIFF…*. Keep the options that write z-slices, time points and
  channels into separate files **unticked**, so each image becomes one
  file.

Whichever you use, **the file name must end in `.ome.tif`**. With only
`.tif`, Bio-Formats writes a plain TIFF without the OME metadata, even
from the OME-TIFF dialog.

## Many files: bfconvert

For whole folders, use `bfconvert`, the command line tool of
[Bio-Formats](https://www.openmicroscopy.org/bio-formats/) (the library
Fiji uses to read microscope files). It reads about 150 formats and
needs Java. There are several ways to get it; pick the first one that
fits your computer.

### Option 1: pixi, with Java included (recommended)

[pixi](https://pixi.sh) installs command line tools into your user
folder, without admin rights, on macOS, Linux and Windows. The
Bio-Formats tools from
[Bioconda](https://bioconda.github.io/recipes/bftools/README.html) bring
their own Java, so there is nothing else to install.

1.  Install pixi, following the instructions on <https://pixi.sh>. On
    macOS and Linux this is a single command in the terminal:

    ``` bash
    curl -fsSL https://pixi.sh/install.sh | sh
    ```

    On Windows, run in PowerShell:

    ``` powershell
    powershell -ExecutionPolicy ByPass -c "irm -useb https://pixi.sh/install.ps1 | iex"
    ```

2.  Open a new terminal and install the Bio-Formats tools:

    ``` bash
    pixi global install --channel conda-forge --channel bioconda bftools
    ```

`bfconvert` and `showinf` are now available in every terminal. If you
already use conda or micromamba, the same package works there:

``` bash
micromamba create -n bftools -c conda-forge -c bioconda bftools
micromamba run -n bftools bfconvert ...
```

### Option 2: Bio-Formats with your own Java

1.  **Java**: Bio-Formats needs Java 11 or newer. If `java -version`
    doesn’t work in a terminal, install it, e.g. from
    <https://adoptium.net>.
2.  **Bio-Formats command line tools**: download `bftools.zip` from the
    [Bio-Formats
    downloads](https://www.openmicroscopy.org/bio-formats/downloads/)
    and unzip it, e.g. to your home folder. The folder contains
    `bfconvert` and `showinf` (on Windows `bfconvert.bat` and
    `showinf.bat`). Add it to your `PATH`, or call the tools with their
    full path.

This route gives you the newest Bio-Formats version; the packages of
option 1 can lag behind a little.

### Option 3: containers (Docker, Podman, Apptainer)

If you already work with containers, run `bfconvert` from the
[BioContainers](https://biocontainers.pro) image, which is built from
the same Bioconda package. Pick a version tag from
<https://quay.io/repository/biocontainers/bftools?tab=tags> (the images
have no `latest` tag) and mount the folder with your files:

``` bash
docker run --rm -v "$PWD":/data -w /data quay.io/biocontainers/bftools:<tag> \
  bfconvert -noflat -bigtiff -compression LZW -no-upgrade input.czi output.ome.tif
```

On computing clusters, where Docker is usually not available, Apptainer
(formerly Singularity) runs the same image:

``` bash
apptainer exec docker://quay.io/biocontainers/bftools:<tag> \
  bfconvert -noflat -bigtiff -compression LZW -no-upgrade input.czi output.ome.tif
```

Containers are a good fit for pipelines and clusters. Just for
converting files on a laptop, Docker is a much bigger installation than
options 1 and 2. The images are built for Intel processors; on Apple
silicon Macs they run in emulation and are slower.

### Images on an OMERO server

If your facility keeps images on an
[OMERO](https://www.openmicroscopy.org/omero/) server, you may not need
to convert anything yourself: OMERO can export images as OME-TIFF. Ask
your facility how this is set up.

### The recommended command

``` bash
bfconvert -noflat -bigtiff -compression LZW -no-upgrade input.czi output.ome.tif
```

- `-noflat` keeps resolution pyramids of slide scans together instead of
  writing them as extra images.
- `-bigtiff` allows files larger than 4 GB, and does no harm otherwise.
- `-compression LZW` is lossless. Avoid lossy compression for figures.
- `-no-upgrade` skips the online check for updates.

Two settings help with some files and computers. Set them once in the
terminal before converting:

``` bash
# an English number format: some locales (e.g. German) make Bio-Formats fail
export JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US"
# more memory for large tile or slide scans
export BF_MAX_MEM=4g
```

On Windows (PowerShell), use `$env:JAVA_TOOL_OPTIONS = "..."` and
`$env:BF_MAX_MEM = "4g"` instead.

### Files with several scenes

CZI and LIF files can hold several scenes (positions, wells). Convert
each scene into a file of its own with `-series` (counted from 0):

``` bash
showinf -nopix -noflat -no-upgrade input.czi | grep "Series count"
#> Series count = 3

bfconvert -noflat -bigtiff -compression LZW -no-upgrade -series 0 input.czi input_s1.ome.tif
bfconvert -noflat -bigtiff -compression LZW -no-upgrade -series 1 input.czi input_s2.ome.tif
bfconvert -noflat -bigtiff -compression LZW -no-upgrade -series 2 input.czi input_s3.ome.tif
```

Don’t convert all scenes at once with a file name pattern: that writes a
*multi-file* OME-TIFF, whose files refer to each other, and
[`read_images()`](https://jbengler.github.io/tidymontage/reference/read_images.md)
reads single-file OME-TIFFs only.

### A whole folder

This script converts all CZI files of a folder `raw_data` into a folder
`ome-tiff`, one file per scene (macOS and Linux):

``` bash
export JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US"
export BF_MAX_MEM=4g
mkdir -p ome-tiff

for f in raw_data/*.czi; do
  name=$(basename "$f" .czi)
  n=$(showinf -nopix -noflat -no-upgrade "$f" | sed -n 's/^Series count = //p')
  if [ "$n" = "1" ]; then
    bfconvert -noflat -bigtiff -compression LZW -no-upgrade "$f" "ome-tiff/$name.ome.tif"
  else
    for i in $(seq 0 $((n - 1))); do
      bfconvert -noflat -bigtiff -compression LZW -no-upgrade -series "$i" "$f" "ome-tiff/${name}_s$((i + 1)).ome.tif"
    done
  fi
done
```

On Windows (PowerShell), for files with one scene each:

``` powershell
$env:JAVA_TOOL_OPTIONS = "-Duser.language=en -Duser.country=US"
$env:BF_MAX_MEM = "4g"
New-Item -ItemType Directory -Force ome-tiff | Out-Null

Get-ChildItem raw_data -Filter *.czi | ForEach-Object {
  bfconvert.bat -noflat -bigtiff -compression LZW -no-upgrade $_.FullName "ome-tiff\$($_.BaseName).ome.tif"
}
```

### From R

To keep the conversion in the same script as the figure, call
`bfconvert` from R. Files that were converted before are skipped:

``` r

bfconvert <- "bfconvert" # or the full path, e.g. "~/bftools/bfconvert"
Sys.setenv(JAVA_TOOL_OPTIONS = "-Duser.language=en -Duser.country=US", BF_MAX_MEM = "4g")

files <- list.files("raw_data", pattern = "\\.czi$", full.names = TRUE)
dir.create("ome-tiff", showWarnings = FALSE)

for (f in files) {
  out <- file.path("ome-tiff", sub("\\.czi$", ".ome.tif", basename(f)))
  if (file.exists(out)) next
  system2(bfconvert, c("-noflat", "-bigtiff", "-compression", "LZW", "-no-upgrade", shQuote(f), shQuote(out)))
}
```

## Check the result

Read the converted files and check where their metadata came from.
OME-TIFFs should show `ome-xml` for both the metadata and the pixel
size:

``` r

library(tidymontage)
library(dplyr)

read_images("ome-tiff") |>
  distinct(file = basename(filepath), channel, color, pixel_size, meta_source, pixel_size_source)
```

If `meta_source` says `imagej` or `tiff`, the file was not written as
OME-TIFF; most often its name doesn’t end in `.ome.tif`. If `pixel_size`
is `NA`, scale bars can’t be drawn: check the calibration in the
original file.
