#!/usr/bin/env python3
"""v0.1.88: Super-Maxi 3 braces; Ultra 4 braces; 900 snap kept."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.88.zip"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def md5_file(path: str) -> str:
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")

    assert_("EXTENSION_VERSION = '0.1.88'" in reg, "version")
    assert_("v88" in f_const, "defn v88")
    assert_("'super_maxi' => [950.0, 1600.0, 2200.0]" in f_const, "super three")
    assert_("1400.0, 1600.0, 2200.0" not in f_const, "no super four with 1400")
    assert_("'ultra_maxi' => [950.0, 1600.0, 2200.0, 3000.0]" in f_const, "ultra four")
    assert_("rem = w - base" in f_geom, "900 snap kept")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        const = zf.read("isoframe_stand_designer/products/fabric/constants.rb").decode()
        assert_("'super_maxi' => [950.0, 1600.0, 2200.0]" in const, "zip super")
        assert_("'ultra_maxi' => [950.0, 1600.0, 2200.0, 3000.0]" in const, "zip ultra")

    reinstall = os.path.join(STORE, "docs", "v0188-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.88" in body and md5 in body, "reinstall md5")
    assert_("Ultra" in body and "2200" in body, "reinstall ultra")

    print("OK — v0.1.88 checks passed")
    print(f"Proof: Super 3 / Ultra 4 braces; 900 snap locked; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
