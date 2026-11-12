from pathlib import Path
import importlib.util
import json

import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent.parent
RENDERER = Path(r"C:\Users\SHIJINXIANG\.codex\plugins\cache\openai-primary-runtime\documents\26.1110.11258\skills\documents\render_docx.py")


def main():
    spec = importlib.util.spec_from_file_location("canonical_docx_renderer", RENDERER)
    renderer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(renderer)
    reports = json.loads((HERE / "Word导出记录.json").read_text(encoding="utf-8-sig"))
    font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 18)
    results = []
    for report in reports:
        pdf = Path(report["PDF"])
        output = pdf.parent / "页面_终审"
        output.mkdir(exist_ok=True)
        renderer.convert_to_pdf = lambda *args, _pdf=str(pdf), **kwargs: (_pdf, "Microsoft Word via bundled PowerShell STA")
        images = renderer.rasterize(str(HERE / "成稿" / report["Name"]), str(output), 120, verbose=False, emit_pdf=False)
        document = pdfium.PdfDocument(str(pdf))
        pages = []
        for number, page in enumerate(document):
            text_page = page.get_textpage()
            text = text_page.get_text_range()
            rectangle = text_page.get_rect(0) if text_page.count_rects() else None
            pages.append({"page": number + 1, "characters": len(text), "text": text, "first_text_rect": rectangle})
            text_page.close()
            page.close()
        document.close()
        (pdf.parent / "页面文字.json").write_text(json.dumps(pages, ensure_ascii=False, indent=2), encoding="utf-8")
        for start in range(0, len(images), 6):
            sheet = Image.new("RGB", (1800, 1650), "#e3e6e8")
            draw = ImageDraw.Draw(sheet)
            for offset, image_path in enumerate(images[start:start + 6]):
                image = Image.open(image_path).convert("RGB")
                image.thumbnail((575, 755))
                x = (offset % 3) * 600 + 12
                y = (offset // 3) * 825 + 8
                sheet.paste(image, (x, y))
                draw.text((x + 4, y + 765), f"第{start + offset + 1}页", font=font, fill="black")
            sheet.save(pdf.parent / f"终审总览_{start // 6 + 1:02}.jpg", quality=94)
        results.append({"document": report["Name"], "pages": len(images),
                        "empty_body_pages": [p["page"] for p in pages if p["characters"] < 30],
                        "sparse_pages": [p["page"] for p in pages if p["characters"] < 110],
                        "contact_sheets": (len(images) + 5) // 6})
    (HERE / "页面检查清单.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(results, ensure_ascii=False))


if __name__ == "__main__":
    main()
