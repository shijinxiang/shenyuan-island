from pathlib import Path
import csv
import hashlib
import io
import json
import zipfile

RECORD = Path(__file__).resolve().parent.parent
PROJECT = RECORD.parent.parent
DELIVERY = PROJECT.parent / "深渊岛_交付_2026-11-11"
PREFIX = "深渊岛_完整可编辑工程/"


def digest(stream):
    value = hashlib.sha256()
    for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
        value.update(block)
    return value.hexdigest()


def main():
    path = DELIVERY / "深渊岛_全部资源与可编辑工程.zip"
    baseline = json.loads((RECORD / "运行工程整理前SHA256.json").read_text(encoding="utf-8"))
    runtime_verified = 0
    expected_exclusions = []
    with zipfile.ZipFile(path) as archive:
        names = set(archive.namelist())
        rows = list(csv.DictReader(io.StringIO(archive.read(PREFIX + "文件清单_SHA256.csv").decode("utf-8-sig"))))
        for index, row in enumerate(rows, 1):
            member = PREFIX + row["相对路径"]
            info = archive.getinfo(member)
            assert info.file_size == int(row["字节"])
            with archive.open(member) as stream:
                assert digest(stream) == row["SHA256"], member
            if index % 500 == 0:
                print("Verified", index, "/", len(rows), flush=True)
        for relative, item in baseline.items():
            if relative == "游戏/project.godot":
                continue
            if ".godot_ai_update" in Path(relative).parts:
                expected_exclusions.append(relative)
                continue
            with archive.open(PREFIX + relative) as stream:
                assert digest(stream) == item["sha256"], relative
            runtime_verified += 1
        settings = archive.read(PREFIX + "游戏/project.godot").decode("utf-8-sig")
        assert 'config/version="0.2.0"' in settings and "_mcp_game_helper=" not in settings
        assert "enabled=PackedStringArray()" in settings
        for name in names:
            relative = name.removeprefix(PREFIX)
            assert not any(part in ["_build", ".godot", "__pycache__", "成稿", "原稿", "排版核验"] for part in Path(relative).parts), name
        assert PREFIX + "归档/06_本轮制作备份与过程脚本.zip" in names
        assert PREFIX + "整理记录/开发文档更新_2026-11-11/编制脚本/build_updated_documents.py" in names
        assert PREFIX + "工具/资产核验/农耕与生存/verify_assets.gd" in names
        documents = json.loads((PROJECT / "整理记录/开发文档更新_2026-11-11/文档交付核验.json").read_text(encoding="utf-8"))
        for item in documents["documents"]:
            relative = "需求/开发过程文档/" + Path(item["file"]).name
            with archive.open(PREFIX + relative) as stream:
                assert digest(stream) == item["sha256"]
    with path.open("rb") as stream:
        checksum = digest(stream)
    result = {"passed": True, "source_zip": path.name, "bytes": path.stat().st_size,
              "sha256": checksum, "manifest_files_verified": len(rows), "crc_verified": True,
              "runtime_files_matching_before_cleanup": runtime_verified,
              "excluded_updater_cache": expected_exclusions,
              "portable_settings_verified": True, "formal_documents_matching": True,
              "temporary_directories_excluded": True}
    (RECORD / "打包核验/最终工程包核验.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    report_path = DELIVERY / "交付核验.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    for package in report["packages"]:
        if package["file"] == path.name:
            for field in ["bytes", "sha256", "manifest_files_verified", "crc_verified"]:
                package[field] = result[field]
    report["file_organization"] = json.loads((RECORD / "整理结果.json").read_text(encoding="utf-8"))
    report["source_package_after_organization"] = result
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (DELIVERY / "SHA256校验.txt").write_text("\n".join(package["sha256"] + "  " + package["file"] for package in report["packages"]) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
