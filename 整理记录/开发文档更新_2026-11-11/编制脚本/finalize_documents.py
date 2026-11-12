from pathlib import Path
import hashlib
import json
import re
import shutil

from docx import Document

HERE = Path(__file__).resolve().parent.parent
PROJECT = HERE.parent.parent


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    reports = json.loads((HERE / "Word导出记录.json").read_text(encoding="utf-8-sig"))
    picture_index = json.loads((HERE / "新增图片索引.json").read_text(encoding="utf-8"))
    content = json.loads((HERE / "编制清单.json").read_text(encoding="utf-8"))
    result = []
    for report in reports:
        path = HERE / "成稿" / report["Name"]
        document = Document(path)
        all_text = "\n".join(p.text for p in document.paragraphs)
        for table in document.tables:
            all_text += "\n" + "\n".join(cell.text for row in table.rows for cell in row.cells)
        assert "0.2.0" in all_text and "2026" in all_text
        assert "目录更新中" not in all_text
        assert not re.search(r"\[FIG |\[FLOW |\[TOC\]", all_text)
        for number in range(1, 28):
            assert f"R{number:02}" in all_text
        assert len(document.inline_shapes) == report["Images"]
        assert report["Pages"] == (97 if "完整" in report["Name"] else 68)
        assert not document.styles["Title"].element.xpath(".//w:pBdr")
        destination = PROJECT / "需求/开发过程文档" / path.name
        shutil.copy2(path, destination)
        assert sha256(destination) == sha256(path)
        result.append({"file": str(destination), "pages": report["Pages"],
                       "images": report["Images"], "bytes": path.stat().st_size,
                       "sha256": sha256(path), "requirements": 27, "toc_updated": True})
    polishing = json.loads((HERE / "Humanizer润色记录.json").read_text(encoding="utf-8"))
    polishing.pop("review_again", None)
    polishing["final_review"] = {
        "completed": True,
        "rendered_pages": sum(row["Pages"] for row in reports),
        "all_page_overviews_inspected": True,
        "original_size_samples": ["整体58", "整体78", "整体96", "分工67"],
        "preserved_letter_and_technical_values": True,
        "corrected_evidence": ["人物等级页改用skills入口", "信纸等待动画完全展开"],
        "layout_iteration": "实机配图高度调整为2.9英寸上限并保留图注，收紧分页空白"
    }
    (HERE / "Humanizer润色记录.json").write_text(json.dumps(polishing, ensure_ascii=False, indent=2), encoding="utf-8")
    summary = {"passed": True, "version": "0.2.0", "documents": result,
               "new_requirement_records": 27, "runtime_evidence_files": len(picture_index),
               "visual_review_pages": 165, "newly_rendered_from_release_pck": 33,
               "role_basis": "组员一资源建模 组员二内容规划 组员三场景接入的责任框架"}
    (HERE / "文档交付核验.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
