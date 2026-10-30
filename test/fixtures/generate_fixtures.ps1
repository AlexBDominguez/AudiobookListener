# Regenerates the .m4b test fixtures. Requires ffmpeg and ffprobe in PATH.
# Usage (from the repo root): powershell -File test/fixtures/generate_fixtures.ps1
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$src = Join-Path $dir 'src'
$cover = Join-Path $src 'cover.jpg'

# 1. Cover: 64x64 violet JPEG.
ffmpeg -y -loglevel error -f lavfi -i 'color=c=0x8B5CF6:s=64x64' -frames:v 1 $cover

# 2. 90 s, 3 chapters, cover and full metadata.
ffmpeg -y -loglevel error `
  -f lavfi -i 'sine=frequency=440:sample_rate=22050:duration=90' `
  -i (Join-Path $src 'chapters.ffmeta') `
  -i $cover `
  -map 0:a -map 2:v -map_metadata 1 -map_chapters 1 `
  -c:a aac -b:a 32k -ac 1 -af 'volume=0.1' `
  -c:v copy -disposition:v:0 attached_pic `
  (Join-Path $dir 'with_chapters.m4b')

# 3. 30 s, no chapters, no cover, no metadata.
ffmpeg -y -loglevel error `
  -f lavfi -i 'sine=frequency=330:sample_rate=22050:duration=30' `
  -map_metadata -1 -map_chapters -1 `
  -c:a aac -b:a 32k -ac 1 -af 'volume=0.1' `
  (Join-Path $dir 'no_chapters.m4b')

foreach ($f in 'with_chapters.m4b', 'no_chapters.m4b') {
  Write-Host "== $f"
  ffprobe -v error -show_entries format=duration:format_tags -show_chapters -of compact (Join-Path $dir $f)
}
