"""建立本次清理清单，并验证重复文件与历史备份。删除和移动由原生PowerShell执行。"""
from collections import Counter
from pathlib import Path
import csv
import hashlib
import io
import json
import os
import zipfile

PROJECT = Path(__file__).resolve().parents[2]
WORKSPACE = PROJECT.parent
RECORD = PROJECT / "整理记录/2026-11-11_文件整理"
DOC = PROJECT / "整理记录/开发文档更新_2026-11-11"


def digest(handle):
    result = hashlib.sha256()
    for block in iter(lambda: handle.read(4 * 1024 * 1024), b""):
        result.update(block)
    return result.hexdigest()


def file_digest(path):
    with path.open("rb") as handle:
        return digest(handle)


def describe(path, reason):
    path = path.resolve()
    if not path.is_relative_to(WORKSPACE.resolve()) or path == WORKSPACE.resolve():
        raise ValueError("Unexpected cleanup path " + str(path))
    entries = [path] if path.is_file() else [p for p in path.rglob("*") if p.is_file()]
    return {"path": str(path), "reason": reason, "files": len(entries),
            "bytes": sum(p.stat().st_size for p in entries)}


def main():
    RECORD.mkdir(exist_ok=True)
    delete_dirs = []
    delete_files = []
    duplicate_checks = []

    def remove_dir(relative, reason):
        path = PROJECT / relative
        if path.is_dir():
            delete_dirs.append(describe(path, reason))

    remove_dir("_build", "已完成导出的临时工程副本和导入缓存")
    validation = WORKSPACE / "交付核验_2026-11-11"
    evidence = json.loads((WORKSPACE / "深渊岛_交付_2026-11-11/交付核验.json").read_text(encoding="utf-8"))
    assert evidence["passed"] and evidence["editable_project_migration"]["passed"]
    if validation.is_dir():
        delete_dirs.append(describe(validation, "独立启动与迁移检查已经完成，结果已保存"))
    remove_dir("游戏/.godot/shader_cache", "可自动重新编译的GPU着色器缓存")
    remove_dir("整理记录/开发文档更新_2026-11-11/排版核验", "由Word文档重新生成的PDF与逐页图片缓存")

    current_docs = PROJECT / "需求/开发过程文档"
    stage = DOC / "成稿"
    if stage.exists():
        for path in stage.glob("*.docx"):
            # Word can leave a task-owned lock file after a failed conversion.
            if path.name.startswith("~$"):
                continue
            other = current_docs / path.name
            assert file_digest(path) == file_digest(other), path.name
            duplicate_checks.append({"duplicate": str(path), "canonical": str(other), "sha256": file_digest(path)})
        delete_dirs.append(describe(stage, "已与需求目录正式Word文档逐文件校验一致的成稿副本"))

    old_source = WORKSPACE / "深渊岛_交付_2026-11-07/深渊岛_全部资源与可编辑工程.zip"
    originals = DOC / "原稿"
    if originals.exists():
        with zipfile.ZipFile(old_source) as archive:
            for path in originals.glob("*.docx"):
                member = "深渊岛_完整可编辑工程/需求/开发过程文档/" + path.name
                with archive.open(member) as handle:
                    assert digest(handle) == file_digest(path), path.name
                duplicate_checks.append({"duplicate": str(path), "canonical_archive": str(old_source), "member": member, "sha256": file_digest(path)})
        delete_dirs.append(describe(originals, "与11月7日历史工程包逐文件校验一致的原稿重复副本"))

    for directory in PROJECT.rglob("__pycache__"):
        if not any(directory.is_relative_to(Path(row["path"])) for row in delete_dirs):
            delete_dirs.append(describe(directory, "Python可重建字节码缓存"))

    frames = PROJECT / "素材/06_游戏场景资产/海岸生存/animation_frames"
    if frames.is_dir():
        from PIL import Image
        for name in ["Crawl", "Swim", "Attack"]:
            image = Image.open(frames.parent / (name + "_actual.gif"))
            assert image.n_frames > 1
        delete_dirs.append(describe(frames, "动画GIF及BLEND源工程已保留，清理可重渲染的逐帧PNG"))
    shark_frames = PROJECT / "素材/06_游戏场景资产/海岸生存/鲨鱼游泳修复/frames"
    if shark_frames.is_dir():
        from PIL import Image
        gifs = list(shark_frames.parent.glob("*.gif"))
        assert gifs and any(Image.open(path).n_frames > 1 for path in gifs)
        delete_dirs.append(describe(shark_frames, "鲨鱼GIF及绑定源工程已保留，清理逐帧PNG缓存"))

    # Preserve unique model backups and completed one-off conversion scripts in a verified archive.
    archive_dirs = [
        PROJECT / "素材/06_游戏场景资产/狩猎与烹饪/剥皮小刀/备份_低位前",
        PROJECT / "素材/06_游戏场景资产/狩猎与烹饪/剥皮小刀/备份_初版",
        PROJECT / "素材/06_游戏场景资产/农耕与伐木/verify_godot",
    ]
    backup_files = list((PROJECT / "素材").rglob("*.blend1"))
    one_off = [DOC / name for name in ["show_diagnostic_word.ps1", "word_pdf_diagnostic.ps1", "word_status.ps1", "release_smoke.gd", "export_qa_release.ps1", "render_when_ready.ps1"]]
    preserved = {path for path in backup_files + one_off if path.is_file()}
    for directory in archive_dirs:
        if directory.exists():
            preserved.update(path for path in directory.rglob("*") if path.is_file() and ".godot" not in path.parts and "__pycache__" not in path.parts)
    for path in (PROJECT / "_build").rglob("*"):
        if path.is_file() and len(path.relative_to(PROJECT / "_build").parts) == 2 and path.suffix in [".log", ".json"]:
            preserved.add(path)

    archive_path = PROJECT / "归档/06_本轮制作备份与过程脚本.zip"
    assert not archive_path.exists(), "Archive already exists; inspect the existing cleanup record before rerunning"
    manifest = []
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=4) as archive:
        for path in sorted(preserved):
            relative = path.relative_to(PROJECT).as_posix()
            checksum = file_digest(path)
            archive.write(path, relative)
            manifest.append({"relative_path": relative, "bytes": path.stat().st_size, "sha256": checksum})
        archive.writestr("文件清单_SHA256.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None
        for row in manifest:
            with archive.open(row["relative_path"]) as handle:
                assert digest(handle) == row["sha256"]
    index = PROJECT / "归档/归档内容索引.csv"
    with index.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        for row in manifest:
            writer.writerow([archive_path.relative_to(PROJECT).as_posix(), row["relative_path"], row["bytes"], row["sha256"]])
    (RECORD / "新增归档核验.json").write_text(json.dumps({"archive": str(archive_path), "sha256": file_digest(archive_path), "files": manifest, "crc_verified": True}, ensure_ascii=False, indent=2), encoding="utf-8")

    for directory in archive_dirs:
        if directory.is_dir():
            delete_dirs.append(describe(directory, "已逐文件核对SHA256的制作备份或验证工程已归档"))
    for path in backup_files + one_off:
        if path.is_file() and not any(path.is_relative_to(Path(row["path"])) for row in delete_dirs):
            delete_files.append(describe(path, "已归档并核对SHA256的制作备份或完成的一次性脚本"))

    for path in DOC.iterdir():
        if not path.is_file():
            continue
        if path.name.endswith("进程.txt") or (path.suffix == ".log" and path.stat().st_size == 0) or path.name.startswith("实机总览_"):
            delete_files.append(describe(path, "失效进程号、空日志或可由原始图片重建的总览"))

    older = PROJECT / "整理记录/开发文档编制_2026-11-07"
    for folder in older.iterdir():
        if folder.is_dir() and folder.name.startswith("深渊岛_"):
            for path in folder.iterdir():
                if path.is_dir() and path.name == "页面":
                    delete_dirs.append(describe(path, "历史文档PDF可再次光栅化生成的页面缓存"))
                elif path.is_file() and path.name.startswith("总览-") and path.suffix.lower() == ".jpg":
                    delete_files.append(describe(path, "可由历史文档PDF重新生成的页面总览"))

    old_release = WORKSPACE / "深渊岛_交付_2026-11-07"
    loose = old_release / "Windows独立游戏"
    if loose.is_dir():
        with zipfile.ZipFile(old_release / "深渊岛_Windows独立游戏.zip") as archive:
            for path in loose.rglob("*"):
                if path.is_file() and path.name != ".gdignore":
                    member = "深渊岛_Windows独立游戏/" + path.relative_to(loose).as_posix()
                    with archive.open(member) as handle:
                        assert digest(handle) == file_digest(path)
        delete_dirs.append(describe(loose, "与同版本ZIP逐文件核验一致的旧版解压运行副本"))

    # Only directory operations not already covered by an outer deletion are kept.
    delete_dirs.sort(key=lambda row: len(Path(row["path"]).parts))
    pruned = []
    for row in delete_dirs:
        if not any(Path(row["path"]).is_relative_to(Path(parent["path"])) for parent in pruned):
            pruned.append(row)
    delete_files = list({row["path"]: row for row in delete_files if not any(Path(row["path"]).is_relative_to(Path(directory["path"])) for directory in pruned)}.values())
    plan = {"workspace": str(WORKSPACE), "delete_directories": pruned, "delete_files": delete_files,
            "historical_delivery_move": {"source": str(old_release), "target": str(WORKSPACE / "历史交付" / old_release.name)},
            "duplicate_checks": duplicate_checks, "archived_unique_files": len(manifest),
            "archive": str(archive_path)}
    (RECORD / "清理执行清单.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"delete_directories": len(pruned), "delete_files": len(delete_files), "removed_files": sum(row["files"] for row in pruned + delete_files), "GiB": round(sum(row["bytes"] for row in pruned + delete_files) / 2**30, 3), "archived_unique_files": len(manifest)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
