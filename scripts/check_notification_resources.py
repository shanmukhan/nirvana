"""Verify source retention rules and, optionally, packaged APK/AAB tones."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TONES = ["nirvana_tone", "nirvana_water_tone", "nirvana_dhyana_tone", "nirvana_knee_tone", "nirvana_eye_tone"]
raw = ROOT / "app/android/app/src/main/res/raw"
keep = ET.parse(raw / "keep.xml").getroot().get("{http://schemas.android.com/tools}keep", "").split(",")
for tone in TONES:
    assert (raw / f"{tone}.wav").is_file(), f"Missing Android tone: {tone}"
    assert f"@raw/{tone}" in keep, f"Missing shrinker keep rule: {tone}"
    assert (ROOT / f"app/ios/Runner/Resources/{tone}.wav").is_file(), f"Missing iOS tone: {tone}"
if len(sys.argv) > 1:
    with zipfile.ZipFile(sys.argv[1]) as archive:
        names = archive.namelist()
    for tone in TONES:
        assert any(name.endswith(f"res/raw/{tone}.wav") for name in names), f"Missing packaged tone: {tone}"
print("All five notification tones and retention rules verified.")
