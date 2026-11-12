"""检查 Git 暂存区中的文件归类和大文件存储配置。"""

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FORBIDDEN_PARTS = {".godot", "__pycache__", ".godot_ai_update"}
FORBIDDEN_ROOTS = {"_build", "发布", "归档"}
REQUIRED_FILES = {
    "游戏/project.godot",
    "游戏/scenes/coastal_beauty.scn",
    ".gitattributes",
    ".gitignore",
    "README.md",
    "CONTRIBUTING.md",
    "CHANGELOG.md",
}


def git(*arguments, data=None):
    result = subprocess.run(
        ["git", "-c", "core.quotepath=false", *arguments],
        cwd=ROOT,
        input=data,
        capture_output=True,
        check=True,
    )
    return result.stdout


def main():
    entries = []
    for entry in git("ls-files", "--stage", "-z").split(b"\0"):
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        entries.append((raw_path.decode("utf-8"), oid.decode(), stage))

    paths = {path for path, _, _ in entries}
    errors = [f"缺少必需文件 {path}" for path in sorted(REQUIRED_FILES - paths)]
    raw_paths = b"".join(path.encode("utf-8") + b"\0" for path, _, _ in entries)
    attributes = git("check-attr", "--cached", "--stdin", "-z", "filter", data=raw_paths).split(b"\0")
    filters = {
        attributes[index].decode("utf-8"): attributes[index + 2].decode()
        for index in range(0, len(attributes) - 1, 3)
    }
    object_ids = sorted({oid for _, oid, _ in entries})
    sizes_output = git(
        "cat-file", "--batch-check=%(objectname) %(objectsize)",
        data=("\n".join(object_ids) + "\n").encode(),
    )
    sizes = dict(line.split() for line in sizes_output.decode().splitlines())
    lfs_count = 0
    for path, oid, stage in entries:
        parts = Path(path).parts
        if stage != b"0":
            errors.append(f"存在未解决的合并冲突 {path}")
        if set(parts) & FORBIDDEN_PARTS or parts[0] in FORBIDDEN_ROOTS:
            errors.append(f"缓存、归档或发布产物进入版本管理 {path}")
        if path.startswith("工具/Godot_4.7.2/"):
            errors.append(f"本机引擎进入版本管理 {path}")
        if int(sizes[oid]) > 100 * 1024 * 1024:
            errors.append(f"普通 Git 对象超过 100 MiB {path}")
        if filters.get(path) == "lfs":
            lfs_count += 1
            if int(sizes[oid]) > 1024:
                errors.append(f"LFS 文件尚未转换为指针 {path}")

    project = git("show", ":游戏/project.godot").decode("utf-8-sig")
    version_match = re.search(r'^config/version="([^"]+)"$', project, re.MULTILINE)
    if not version_match:
        errors.append("项目缺少版本号")
    for error in errors:
        print(error)
    version = version_match.group(1) if version_match else "unknown"
    print(f"检查 {len(entries)} 个文件，LFS {lfs_count} 个，游戏版本 {version}，问题 {len(errors)} 个")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
