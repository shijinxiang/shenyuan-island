from pathlib import Path
import importlib.util
import os
import sys

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT.parent.parent
OLD = PROJECT / "整理记录/2026-11-07_打包发布/package_delivery.py"


def main():
    spec = importlib.util.spec_from_file_location("verified_package_writer", OLD)
    packager = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packager)
    packager.PROJECT = PROJECT
    packager.DELIVERY = PROJECT.parent / "深渊岛_交付_2026-11-11"
    packager.RECORD = ROOT / "打包核验"
    packager.RECORD.mkdir(exist_ok=True)
    original_skip = packager.skip
    original_writer = packager.write_package

    def write_package(target, top, files, overrides=None):
        staging = target.with_name(target.stem + ".building.zip")
        result = original_writer(staging, top, files, overrides)
        os.replace(staging, target)
        result["file"] = target.name
        return result

    def skip(relative):
        if original_skip(relative):
            return True
        # These pages and temporary migration copies are regenerated from the retained sources.
        if "排版核验" in relative.parts:
            return True
        if relative.is_relative_to(ROOT.relative_to(PROJECT) / "打包核验"):
            return True
        if relative.is_relative_to(Path("整理记录/2026-11-11_文件整理/打包核验")):
            return True
        return False

    packager.skip = skip
    packager.write_package = write_package
    packager.main()


if __name__ == "__main__":
    main()
