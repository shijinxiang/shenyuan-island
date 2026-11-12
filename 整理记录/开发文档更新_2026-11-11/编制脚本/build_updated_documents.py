from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent.parent
OLD = HERE.parent / "开发文档编制_2026-11-07"
SOURCE = OLD / "build_documents.py"


def main():
    source = SOURCE.read_text(encoding="utf-8")
    definitions = source[:source.index("reports=[make(")]
    definitions = definitions.replace("'附录A','附录B'", "'附录A','附录B','附录C'")
    definitions = definitions.replace(
        "maxw=6.65;maxh=3.45 if w>=h else 4.4",
        "maxw=6.65;maxh=3.45 if w>=h else 4.4\n    if number and '实机证据' in str(path):maxh=min(maxh,2.9)"
    )
    definitions = definitions.replace(
        "if source:\n        c.add_run",
        "c.paragraph_format.keep_with_next=False\n    if source:\n        c.add_run"
    )
    namespace = {"__file__": str(SOURCE), "__name__": "reused_document_builder"}
    exec(compile(definitions, str(SOURCE), "exec"), namespace)
    namespace["W"] = HERE
    namespace["OUT"] = HERE / "成稿"
    namespace["OUT"].mkdir(parents=True, exist_ok=True)
    (HERE / "证据图片").mkdir(exist_ok=True)
    entries = json.loads((HERE / "新增图片索引.json").read_text(encoding="utf-8"))
    for entry in entries:
        key = entry["id"].split("_", 1)[0]
        namespace["SOURCES"][key] = entry
    team_flow = namespace["FLOWS"]["team"]
    namespace["FLOWS"]["team"] = (team_flow[0], team_flow[1], "按问题原因确定修改负责人 交接模型文件 参数和运行结果")
    reports = []
    for source_name, output_name in [("完整开发过程.md", "深渊岛_完整开发过程.docx"),
                                     ("三人分工开发记录.md", "深渊岛_三人分工开发文档.docx")]:
        content = (HERE / source_name).read_text(encoding="utf-8")
        for key in re.findall(r"\[FIG (\w+) ", content):
            if key not in namespace["SOURCES"]:
                raise ValueError("Unresolved figure " + key)
            if not Path(namespace["SOURCES"][key]["path"]).is_file():
                raise FileNotFoundError(namespace["SOURCES"][key]["path"])
        result = namespace["make"](HERE / source_name, output_name, "N01")
        reports.append(result)
    (HERE / "编制清单.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps([{k: v for k, v in result.items() if k != "figure_list"} for result in reports], ensure_ascii=False))


if __name__ == "__main__":
    main()
