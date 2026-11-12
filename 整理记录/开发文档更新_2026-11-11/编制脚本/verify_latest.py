from pathlib import Path
import csv
import hashlib
import io
import json
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent.parent
PROJECT = HERE.parent.parent
DELIVERY = PROJECT.parent / "深渊岛_交付_2026-11-11"
CHECK = PROJECT.parent / "交付核验_2026-11-11"


def digest_stream(handle):
    digest = hashlib.sha256()
    for block in iter(lambda: handle.read(4 * 1024 * 1024), b""):
        digest.update(block)
    return digest.hexdigest()


def verify_zip(path, prefix):
    print("Verifying manifest", path.name, flush=True)
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)), "Duplicate archive members"
        manifest = archive.read(prefix + "/文件清单_SHA256.csv").decode("utf-8-sig")
        rows = list(csv.DictReader(io.StringIO(manifest)))
        for index, row in enumerate(rows, 1):
            relative = row["相对路径"]
            info = archive.getinfo(prefix + "/" + relative)
            assert info.file_size == int(row["字节"]), relative
            with archive.open(info) as handle:
                assert digest_stream(handle) == row["SHA256"], relative
            if index % 500 == 0:
                print("Verified", index, "/", len(rows), flush=True)
        with path.open("rb") as handle:
            digest = digest_stream(handle)
    return {"file": path.name, "bytes": path.stat().st_size, "sha256": digest,
            "manifest_files_verified": len(rows), "crc_verified": True}


def verify_migration(source):
    target = CHECK / "迁移工程"
    target.mkdir(parents=True, exist_ok=True)
    prefix = "深渊岛_完整可编辑工程/"
    selected = []
    with zipfile.ZipFile(source) as archive:
        settings = archive.read(prefix + "游戏/project.godot").decode("utf-8-sig")
        assert 'config/version="0.2.0"' in settings
        assert "_mcp_game_helper=" not in settings
        assert "enabled=PackedStringArray()" in settings
        assert not any("/.godot/" in name for name in archive.namelist())
        for name in archive.namelist():
            if not name.startswith(prefix):
                continue
            relative = name[len(prefix):]
            wanted = relative.startswith("游戏/") or relative.startswith("需求/开发过程文档/")
            wanted = wanted or relative in ["运行游戏.cmd", "打开Godot编辑器.cmd", "协作与交付说明.txt"]
            wanted = wanted or (relative.startswith("工具/Godot_4.7.2/") and relative.endswith(".exe") and "/export_templates/" not in relative)
            if not wanted or name.endswith("/"):
                continue
            destination = (target / relative).resolve()
            assert target.resolve() in destination.parents
            destination.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(name) as source_file, destination.open("wb") as output:
                for block in iter(lambda: source_file.read(4 * 1024 * 1024), b""):
                    output.write(block)
            selected.append(relative)
    assert not (target / "游戏/.godot").exists()
    engine = target / "工具/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe"
    log = HERE / "打包核验/迁移首次导入.log"
    console = HERE / "打包核验/迁移导入输出.log"
    with console.open("w", encoding="utf-8") as output:
        process = subprocess.run([str(engine), "--headless", "--path", str(target / "游戏"),
                                  "--import", "--log-file", str(log)], stdout=output, stderr=subprocess.STDOUT)
    text = log.read_text(encoding="utf-8-sig")
    errors = [line for line in text.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
    assert process.returncode == 0 and not errors, errors
    document_report = json.loads((HERE / "文档交付核验.json").read_text(encoding="utf-8"))
    for item in document_report["documents"]:
        relocated = target / "需求/开发过程文档" / Path(item["file"]).name
        with relocated.open("rb") as handle:
            assert digest_stream(handle) == item["sha256"]
    return {"passed": True, "relocated_project": str(target), "initial_import_cache_present": False,
            "files_extracted": len(selected), "import_exit_code": process.returncode,
            "import_errors": errors, "matching_document_hashes": True}


def main():
    results = [verify_zip(DELIVERY / "深渊岛_Windows独立游戏.zip", "深渊岛_Windows独立游戏"),
               verify_zip(DELIVERY / "深渊岛_全部资源与可编辑工程.zip", "深渊岛_完整可编辑工程")]
    migration = verify_migration(DELIVERY / "深渊岛_全部资源与可编辑工程.zip")
    standalone = json.loads((HERE / "独立EXE启动核验.json").read_text(encoding="utf-8-sig"))
    documents = json.loads((HERE / "文档交付核验.json").read_text(encoding="utf-8"))
    dependencies = json.loads((HERE / "运行资源核验.json").read_text(encoding="utf-8"))
    assert standalone["passed"] and documents["passed"] and dependencies["passed"]
    report = {"passed": True, "version": "0.2.0", "date": "2026-11-11", "packages": results,
              "standalone": standalone, "editable_project_migration": migration,
              "documents": documents, "runtime_dependencies": dependencies}
    (DELIVERY / "交付核验.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (HERE / "打包核验/最终交付核验.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (DELIVERY / "SHA256校验.txt").write_text("\n".join(row["sha256"] + "  " + row["file"] for row in results) + "\n", encoding="utf-8")
    print(json.dumps({"passed": True, "packages": results, "migration": migration}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
