from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_ALIGN_VERTICAL, WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "deliverables"
ASSET_DIR = OUT_DIR / "report_assets"
OUTPUT = OUT_DIR / "Bao_cao_do_an_ComZone.docx"

FONT = "Times New Roman"
INK = "000000"
BLUE = "17365D"
LIGHT_BLUE = "DCE6F1"
LIGHT_GRAY = "F2F2F2"
MID_GRAY = "666666"
RED = "A61C00"
GREEN = "38761D"


def set_run_font(run, size=13, bold=None, italic=None, color=INK):
    run.font.name = FONT
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), FONT)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), FONT)
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT)
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    return run


def shade_cell(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def set_table_borders(table, color="B7B7B7", size="4"):
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = borders.find(qn(f"w:{edge}"))
        if tag is None:
            tag = OxmlElement(f"w:{edge}")
            borders.append(tag)
        tag.set(qn("w:val"), "single")
        tag.set(qn("w:sz"), size)
        tag.set(qn("w:space"), "0")
        tag.set(qn("w:color"), color)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    header = OxmlElement("w:tblHeader")
    header.set(qn("w:val"), "true")
    tr_pr.append(header)


def prevent_row_split(row):
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = tr_pr.find(qn("w:cantSplit"))
    if cant_split is None:
        cant_split = OxmlElement("w:cantSplit")
        tr_pr.append(cant_split)
    cant_split.set(qn("w:val"), "1")


def set_cell_width(cell, width_cm):
    cell.width = Cm(width_cm)
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_w = tc_pr.find(qn("w:tcW"))
    if tc_w is None:
        tc_w = OxmlElement("w:tcW")
        tc_pr.append(tc_w)
    tc_w.set(qn("w:w"), str(int(width_cm / 2.54 * 1440)))
    tc_w.set(qn("w:type"), "dxa")


def set_table_fixed(table, widths_cm):
    table.autofit = False
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl_pr = table._tbl.tblPr
    layout = tbl_pr.find(qn("w:tblLayout"))
    if layout is None:
        layout = OxmlElement("w:tblLayout")
        tbl_pr.append(layout)
    layout.set(qn("w:type"), "fixed")
    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    total = int(sum(widths_cm) / 2.54 * 1440)
    tbl_w.set(qn("w:w"), str(total))
    tbl_w.set(qn("w:type"), "dxa")
    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in widths_cm:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(int(width / 2.54 * 1440)))
        grid.append(col)
    for row in table.rows:
        prevent_row_split(row)
        for idx, cell in enumerate(row.cells):
            set_cell_width(cell, widths_cm[min(idx, len(widths_cm) - 1)])
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_table_borders(table)


def paragraph_keep_with_next(paragraph):
    p_pr = paragraph._p.get_or_add_pPr()
    keep = OxmlElement("w:keepNext")
    p_pr.append(keep)


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run()
    fld_begin = OxmlElement("w:fldChar")
    fld_begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    fld_sep = OxmlElement("w:fldChar")
    fld_sep.set(qn("w:fldCharType"), "separate")
    txt = OxmlElement("w:t")
    txt.text = "1"
    fld_end = OxmlElement("w:fldChar")
    fld_end.set(qn("w:fldCharType"), "end")
    run._r.extend([fld_begin, instr, fld_sep, txt, fld_end])
    set_run_font(run, 11)


def add_toc(paragraph):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    begin.set(qn("w:dirty"), "true")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = ' TOC \\o "1-3" \\h \\z \\u '
    sep = OxmlElement("w:fldChar")
    sep.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = "Nhấn Ctrl+A rồi F9 để cập nhật mục lục."
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instr, sep, text, end])
    set_run_font(run, 13)


def add_body(doc, text, *, bold_lead=None, italic=False, indent=True, after=4):
    p = doc.add_paragraph(style="Normal")
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.first_line_indent = Cm(1.0) if indent else Cm(0)
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.line_spacing = 1.3
    if bold_lead and text.startswith(bold_lead):
        set_run_font(p.add_run(bold_lead), bold=True)
        set_run_font(p.add_run(text[len(bold_lead):]), italic=italic)
    else:
        set_run_font(p.add_run(text), italic=italic)
    return p


def add_note(doc, label, text, fill=LIGHT_BLUE):
    table = doc.add_table(rows=1, cols=1)
    set_table_fixed(table, [16.0])
    set_repeat_table_header(table.rows[0])
    shade_cell(table.cell(0, 0), fill)
    p = table.cell(0, 0).paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.3
    set_run_font(p.add_run(label + ": "), bold=True)
    set_run_font(p.add_run(text))
    doc.add_paragraph().paragraph_format.space_after = Pt(1)
    return table


def add_bullets(doc, items, level=0):
    for item in items:
        p = doc.add_paragraph(style="List Bullet" if level == 0 else "List Bullet 2")
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.3
        set_run_font(p.add_run(item))


def new_numbering_id(doc, style_name="List Number"):
    numbering = doc.part.numbering_part.element
    style = doc.styles[style_name]
    base_num_id = style._element.pPr.numPr.numId.val
    base_num = numbering.xpath(f'./w:num[@w:numId="{base_num_id}"]')[0]
    abstract_id = base_num.find(qn("w:abstractNumId")).get(qn("w:val"))
    used = [int(node.get(qn("w:numId"))) for node in numbering.xpath("./w:num")]
    num_id = max(used, default=0) + 1
    num = OxmlElement("w:num")
    num.set(qn("w:numId"), str(num_id))
    abstract = OxmlElement("w:abstractNumId")
    abstract.set(qn("w:val"), str(abstract_id))
    num.append(abstract)
    override = OxmlElement("w:lvlOverride")
    override.set(qn("w:ilvl"), "0")
    start = OxmlElement("w:startOverride")
    start.set(qn("w:val"), "1")
    override.append(start)
    num.append(override)
    numbering.append(num)
    return num_id


def add_numbers(doc, items):
    num_id = new_numbering_id(doc)
    for item in items:
        p = doc.add_paragraph(style="List Number")
        num_pr = p._p.get_or_add_pPr().get_or_add_numPr()
        num_pr.get_or_add_ilvl().val = 0
        num_pr.get_or_add_numId().val = num_id
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.3
        set_run_font(p.add_run(item))


def add_heading(doc, text, level=1):
    p = doc.add_paragraph(style=f"Heading {level}")
    p.add_run(text)
    paragraph_keep_with_next(p)
    return p


def add_table(doc, headers, rows, widths, caption=None):
    if caption:
        p = doc.add_paragraph(style="Caption")
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        set_run_font(p.add_run(caption), 12, bold=True)
        paragraph_keep_with_next(p)
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    hdr = table.rows[0]
    set_repeat_table_header(hdr)
    for i, h in enumerate(headers):
        shade_cell(hdr.cells[i], LIGHT_BLUE)
        p = hdr.cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.15
        set_run_font(p.add_run(str(h)), 12, bold=True)
    for row in rows:
        cells = table.add_row().cells
        for i, val in enumerate(row):
            p = cells[i].paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.15
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if i == 0 else WD_ALIGN_PARAGRAPH.LEFT
            set_run_font(p.add_run(str(val)), 12)
    set_table_fixed(table, widths)
    doc.add_paragraph().paragraph_format.space_after = Pt(1)
    return table


def find_font(size=28, bold=False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/Library/Fonts/Times New Roman Bold.ttf" if bold else "/Library/Fonts/Times New Roman.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def wrap_text(draw, text, font, max_width):
    words = text.split()
    lines, current = [], ""
    for word in words:
        candidate = word if not current else current + " " + word
        if draw.textbbox((0, 0), candidate, font=font)[2] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_box(draw, xy, title, subtitle="", fill="#F4F7FB", outline="#17365D"):
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=18, fill=fill, outline=outline, width=3)
    title_font = find_font(27, True)
    text_font = find_font(22, False)
    title_lines = wrap_text(draw, title, title_font, x2 - x1 - 30)
    subtitle_lines = wrap_text(draw, subtitle, text_font, x2 - x1 - 30) if subtitle else []
    line_h = 34
    total_h = len(title_lines) * line_h + len(subtitle_lines) * 29 + (8 if subtitle_lines else 0)
    y = y1 + (y2 - y1 - total_h) / 2
    for line in title_lines:
        bbox = draw.textbbox((0, 0), line, font=title_font)
        draw.text(((x1 + x2 - (bbox[2] - bbox[0])) / 2, y), line, font=title_font, fill="#17365D")
        y += line_h
    if subtitle_lines:
        y += 8
    for line in subtitle_lines:
        bbox = draw.textbbox((0, 0), line, font=text_font)
        draw.text(((x1 + x2 - (bbox[2] - bbox[0])) / 2, y), line, font=text_font, fill="#333333")
        y += 29


def arrow(draw, start, end, color="#666666", width=4):
    draw.line([start, end], fill=color, width=width)
    x2, y2 = end
    x1, y1 = start
    import math
    angle = math.atan2(y2 - y1, x2 - x1)
    length = 16
    for delta in (2.55, -2.55):
        p = (x2 + length * math.cos(angle + delta), y2 + length * math.sin(angle + delta))
        draw.line([end, p], fill=color, width=width)


def make_architecture(path):
    img = Image.new("RGB", (1500, 950), "white")
    d = ImageDraw.Draw(img)
    draw_box(d, (70, 80, 430, 260), "Người dùng", "Customer • Seller • Moderator • Admin", "#FFF4F4", "#A61C00")
    draw_box(d, (570, 55, 930, 285), "Ứng dụng Flutter", "Giao diện responsive • State cục bộ • Stream realtime", "#EDF4FB", "#17365D")
    draw_box(d, (1070, 80, 1430, 260), "Firebase Authentication", "Email/Password • Google • Phone OTP", "#FFF8E8", "#C27C0E")
    draw_box(d, (140, 440, 500, 665), "Cloud Firestore", "Dữ liệu nghiệp vụ • Transaction • Realtime snapshot", "#EEF7EE", "#38761D")
    draw_box(d, (570, 440, 930, 665), "Cloud Functions", "Đấu giá • Mật khẩu Admin • Scheduler", "#F6F0FA", "#674EA7")
    draw_box(d, (1000, 440, 1360, 665), "Firebase Security Rules", "RBAC • Owner check • Chặn ghi tài chính từ client", "#F7F7F7", "#555555")
    draw_box(d, (570, 760, 930, 900), "Tài nguyên cục bộ", "Ảnh bìa • Seed ComZone • Manifest", "#FFF4F4", "#A61C00")
    arrow(d, (430, 170), (570, 170))
    arrow(d, (930, 150), (1070, 150))
    arrow(d, (750, 285), (750, 440))
    arrow(d, (650, 285), (410, 440))
    arrow(d, (850, 285), (1130, 440))
    arrow(d, (570, 555), (500, 555))
    arrow(d, (930, 555), (1000, 555))
    arrow(d, (750, 760), (750, 665))
    img.save(path, quality=95)


def make_actor_map(path):
    img = Image.new("RGB", (1500, 1000), "white")
    d = ImageDraw.Draw(img)
    draw_box(d, (555, 370, 945, 630), "Hệ thống ComZone", "Mua bán • Trao đổi • Đấu giá truyện tranh", "#EDF4FB", "#17365D")
    actors = [
        ((60, 80, 430, 310), "Khách hàng", "Đăng ký/đăng nhập; tìm kiếm; mua; đấu giá; trao đổi; chat; ví"),
        ((1070, 80, 1440, 310), "Người bán", "Đăng ký Seller; quản lý kho; xử lý đơn; doanh thu; tạo đấu giá"),
        ((60, 690, 430, 920), "Moderator", "Duyệt nội dung; xử lý đấu giá; kiểm duyệt phản hồi"),
        ((1070, 690, 1440, 920), "Admin", "Dashboard; người dùng; danh mục; đơn hàng; ví; cấu hình"),
    ]
    for box, title, sub in actors:
        draw_box(d, box, title, sub, "#FFF8E8" if title in ("Khách hàng", "Người bán") else "#F6F0FA", "#C27C0E" if title in ("Khách hàng", "Người bán") else "#674EA7")
    arrow(d, (430, 245), (555, 425))
    arrow(d, (1070, 245), (945, 425))
    arrow(d, (430, 805), (555, 575))
    arrow(d, (1070, 805), (945, 575))
    img.save(path, quality=95)


def make_order_flow(path):
    img = Image.new("RGB", (1600, 560), "white")
    d = ImageDraw.Draw(img)
    labels = [
        ("Chọn truyện", "Kiểm tra trạng thái và tồn kho"),
        ("Giỏ hàng", "Chọn số lượng và thông tin nhận hàng"),
        ("Transaction", "Tạo đơn và trừ tồn kho atomically"),
        ("Seller xử lý", "Chờ xác nhận → Đang xử lý → Đang giao"),
        ("Hoàn tất", "Đã giao; ghi nhận doanh thu Seller"),
    ]
    x = 45
    for i, (title, sub) in enumerate(labels):
        draw_box(d, (x, 150, x + 260, 410), title, sub, "#EDF4FB" if i % 2 == 0 else "#F8F8F8", "#17365D")
        if i < len(labels) - 1:
            arrow(d, (x + 260, 280), (x + 315, 280))
        x += 315
    img.save(path, quality=95)


def make_auction_flow(path):
    img = Image.new("RGB", (1600, 950), "white")
    d = ImageDraw.Draw(img)
    top = [
        ("Seller tạo yêu cầu", "Truyện hoạt động, còn hàng; 1–7 ngày"),
        ("Moderator duyệt", "Chọn giờ bắt đầu hoặc nhập lý do từ chối"),
        ("Phiên hoạt động", "Khóa truyện khỏi bán thường"),
        ("Người mua đặt cọc", "Chuyển balance sang heldBalance"),
    ]
    bottom = [
        ("Ra giá / Mua ngay", "Transaction kiểm tra bước giá và quyền"),
        ("Xác định người thắng", "Scheduler đồng bộ trạng thái"),
        ("Thanh toán", "Khấu trừ cọc; trả Seller; tạo đơn"),
        ("Hoàn/thu cọc", "Hoàn người thua hoặc thu khi quá hạn"),
    ]
    x_positions = [45, 430, 815, 1200]
    for x, (title, sub) in zip(x_positions, top):
        draw_box(d, (x, 90, x + 330, 350), title, sub, "#FFF8E8", "#C27C0E")
    for i in range(3):
        arrow(d, (x_positions[i] + 330, 220), (x_positions[i+1], 220))
    for x, (title, sub) in zip(reversed(x_positions), bottom):
        draw_box(d, (x, 600, x + 330, 860), title, sub, "#EEF7EE", "#38761D")
    arrow(d, (1365, 350), (1365, 600))
    for i in range(3, 0, -1):
        arrow(d, (x_positions[i], 730), (x_positions[i-1] + 330, 730))
    img.save(path, quality=95)


def add_figure(doc, path, caption, width_cm=15.5):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(3)
    shape = p.add_run().add_picture(str(path), width=Cm(width_cm))
    doc_pr = shape._inline.docPr
    doc_pr.set("title", caption)
    doc_pr.set("descr", caption)
    cap = doc.add_paragraph(style="Caption")
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.paragraph_format.space_after = Pt(6)
    set_run_font(cap.add_run(caption), 12, italic=True)


def configure_styles(doc):
    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = FONT
    normal._element.rPr.rFonts.set(qn("w:ascii"), FONT)
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), FONT)
    normal.font.size = Pt(13)
    pf = normal.paragraph_format
    pf.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    pf.line_spacing = 1.3
    pf.space_before = Pt(0)
    pf.space_after = Pt(4)

    heading_specs = {
        "Heading 1": (16, True, False, WD_ALIGN_PARAGRAPH.CENTER, 18, 12),
        "Heading 2": (14, True, False, WD_ALIGN_PARAGRAPH.LEFT, 12, 6),
        "Heading 3": (13, True, True, WD_ALIGN_PARAGRAPH.LEFT, 9, 4),
    }
    for name, (size, bold, italic, align, before, after) in heading_specs.items():
        style = styles[name]
        style.font.name = FONT
        style._element.rPr.rFonts.set(qn("w:ascii"), FONT)
        style._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
        style._element.rPr.rFonts.set(qn("w:eastAsia"), FONT)
        style.font.size = Pt(size)
        style.font.bold = bold
        style.font.italic = italic
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.paragraph_format.alignment = align
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True
        style.paragraph_format.keep_together = True
        style.paragraph_format.line_spacing = 1.15
        if name == "Heading 1":
            style.paragraph_format.page_break_before = True
            style.paragraph_format.first_line_indent = Cm(0)

    caption = styles["Caption"]
    caption.font.name = FONT
    caption._element.rPr.rFonts.set(qn("w:ascii"), FONT)
    caption._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
    caption.font.size = Pt(12)
    caption.font.italic = True
    caption.font.color.rgb = RGBColor(0, 0, 0)

    for name in ("List Bullet", "List Bullet 2", "List Number"):
        style = styles[name]
        style.font.name = FONT
        style._element.rPr.rFonts.set(qn("w:ascii"), FONT)
        style._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
        style.font.size = Pt(13)
        style.paragraph_format.line_spacing = 1.3
        style.paragraph_format.space_after = Pt(2)

    if "Source Code" not in styles:
        code = styles.add_style("Source Code", WD_STYLE_TYPE.PARAGRAPH)
    else:
        code = styles["Source Code"]
    code.font.name = "Courier New"
    code._element.rPr.rFonts.set(qn("w:ascii"), "Courier New")
    code._element.rPr.rFonts.set(qn("w:hAnsi"), "Courier New")
    code.font.size = Pt(10)
    code.paragraph_format.left_indent = Cm(0.7)
    code.paragraph_format.right_indent = Cm(0.7)
    code.paragraph_format.space_before = Pt(3)
    code.paragraph_format.space_after = Pt(5)
    code.paragraph_format.line_spacing = 1.05


def configure_sections(doc):
    for section in doc.sections:
        section.page_width = Cm(21.0)
        section.page_height = Cm(29.7)
        section.top_margin = Cm(2.0)
        section.bottom_margin = Cm(2.0)
        section.left_margin = Cm(3.0)
        section.right_margin = Cm(2.0)
        section.header_distance = Cm(1.0)
        section.footer_distance = Cm(1.0)


def add_cover(doc):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(2)
    set_run_font(p.add_run("[TÊN TRƯỜNG ĐẠI HỌC]"), 14, bold=True)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(28)
    set_run_font(p.add_run("[KHOA / VIỆN CÔNG NGHỆ THÔNG TIN]"), 14, bold=True)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(25)
    set_run_font(p.add_run("BÁO CÁO ĐỒ ÁN CƠ SỞ"), 18, bold=True)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(34)
    set_run_font(p.add_run("XÂY DỰNG ỨNG DỤNG MUA BÁN, TRAO ĐỔI\nVÀ ĐẤU GIÁ TRUYỆN TRANH COMZONE\nTRÊN NỀN TẢNG FLUTTER VÀ FIREBASE"), 20, bold=True, color=BLUE)
    meta = [
        ("Sinh viên thực hiện:", "[HỌ VÀ TÊN SINH VIÊN]"),
        ("Mã số sinh viên:", "[MÃ SỐ SINH VIÊN]"),
        ("Lớp:", "[TÊN LỚP]"),
        ("Giảng viên hướng dẫn:", "[HỌ VÀ TÊN GIẢNG VIÊN]"),
    ]
    table = doc.add_table(rows=len(meta), cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_repeat_table_header(table.rows[0])
    for i, (label, value) in enumerate(meta):
        table.cell(i, 0).width = Cm(5.3)
        table.cell(i, 1).width = Cm(9.5)
        for j, text in enumerate((label, value)):
            p = table.cell(i, j).paragraphs[0]
            p.paragraph_format.space_after = Pt(2)
            set_run_font(p.add_run(text), 13, bold=(j == 0))
            set_cell_margins(table.cell(i, j), 40, 60, 40, 60)
    tbl_pr = table._tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = OxmlElement(f"w:{edge}")
        tag.set(qn("w:val"), "nil")
        borders.append(tag)
    tbl_pr.append(borders)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(80)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_run_font(p.add_run("[ĐỊA DANH], 2026"), 13, bold=True)


def add_front_matter(doc):
    add_heading(doc, "LỜI CAM ĐOAN", 1)
    add_body(doc, "Tôi cam đoan nội dung báo cáo này được xây dựng trên cơ sở mã nguồn và kết quả triển khai thực tế của đồ án ComZone. Các phần tham khảo được ghi rõ trong danh mục tài liệu tham khảo. Những số liệu về cấu trúc mã nguồn, dữ liệu seed và kiểm thử được đối chiếu trực tiếp tại thời điểm lập báo cáo.")
    add_body(doc, "Sinh viên chịu trách nhiệm về tính trung thực của nội dung, kết quả và các sản phẩm phần mềm được trình bày trong báo cáo.")
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p.paragraph_format.space_before = Pt(28)
    set_run_font(p.add_run("Sinh viên thực hiện\n(Ký và ghi rõ họ tên)"), 13, italic=True)

    add_heading(doc, "LỜI CẢM ƠN", 1)
    add_body(doc, "Em xin chân thành cảm ơn giảng viên hướng dẫn đã định hướng, góp ý và hỗ trợ trong quá trình phân tích, xây dựng và hoàn thiện đồ án. Những nhận xét về nghiệp vụ, kiến trúc và cách trình bày đã giúp sản phẩm có cấu trúc rõ ràng và bám sát mục tiêu học phần.")
    add_body(doc, "Em cũng cảm ơn quý thầy cô trong khoa đã cung cấp nền tảng kiến thức về lập trình ứng dụng, cơ sở dữ liệu, phân tích thiết kế hệ thống và an toàn thông tin. Cuối cùng, em cảm ơn gia đình, bạn bè đã động viên và hỗ trợ trong quá trình thực hiện.")

    add_heading(doc, "TÓM TẮT ĐỒ ÁN", 1)
    add_body(doc, "Đồ án xây dựng ComZone, một ứng dụng đa nền tảng hỗ trợ mua bán, trao đổi và đấu giá truyện tranh. Ứng dụng được phát triển bằng Flutter, sử dụng Firebase Authentication để xác thực, Cloud Firestore để lưu trữ dữ liệu nghiệp vụ theo thời gian thực, Cloud Functions cho các thao tác đặc quyền và giao dịch tài chính, cùng Firebase Security Rules để kiểm soát truy cập theo vai trò.")
    add_body(doc, "Hệ thống phục vụ bốn nhóm tác nhân chính gồm khách hàng, người bán, moderator và quản trị viên. Các chức năng nổi bật bao gồm đăng ký/đăng nhập, khôi phục mật khẩu bằng email hoặc OTP điện thoại, duyệt danh mục, giỏ hàng, đặt mua, quản lý đơn, đăng ký người bán, quản lý kho, đấu giá có đặt cọc, trao đổi truyện, chat thời gian thực, thông báo, ví và quản trị dữ liệu.")
    add_body(doc, "Giải pháp tập trung vào tính nhất quán dữ liệu và an toàn: đơn hàng được tạo đồng thời với thao tác trừ tồn kho trong transaction; dữ liệu đấu giá và ví được cập nhật phía Cloud Functions; mật khẩu không lưu tại Firestore; phân quyền được kiểm tra tại cả giao diện, dịch vụ và Security Rules. Kết quả kiểm thử tại thời điểm hoàn thiện báo cáo ghi nhận 35 kiểm thử Flutter và 2 kiểm thử Node.js đều đạt.")
    add_note(doc, "Từ khóa", "Flutter, Firebase, Cloud Firestore, Cloud Functions, truyện tranh, thương mại điện tử, đấu giá, trao đổi, RBAC.")

    add_heading(doc, "DANH MỤC TỪ VIẾT TẮT", 1)
    add_table(doc, ["Từ viết tắt", "Nghĩa"], [
        ("API", "Application Programming Interface – giao diện lập trình ứng dụng"),
        ("CRUD", "Create, Read, Update, Delete – tạo, đọc, cập nhật, xóa"),
        ("Firebase Auth", "Dịch vụ Firebase Authentication"),
        ("Firestore", "Cloud Firestore – cơ sở dữ liệu NoSQL dạng tài liệu"),
        ("OTP", "One-Time Password – mật khẩu dùng một lần"),
        ("RBAC", "Role-Based Access Control – kiểm soát truy cập theo vai trò"),
        ("SDK", "Software Development Kit – bộ công cụ phát triển phần mềm"),
        ("UI/UX", "Giao diện người dùng / trải nghiệm người dùng"),
        ("UID", "Định danh duy nhất của người dùng trong Firebase Auth"),
    ], [3.4, 12.6], caption="Bảng 1. Danh mục từ viết tắt")

    add_heading(doc, "MỤC LỤC", 1)
    p = doc.add_paragraph()
    add_toc(p)
    add_note(doc, "Cách cập nhật", "Mở file bằng Microsoft Word, nhấn Ctrl+A (hoặc Command+A trên macOS), sau đó nhấn F9 và chọn cập nhật toàn bộ mục lục.", fill=LIGHT_GRAY)


def chapter_1(doc):
    add_heading(doc, "CHƯƠNG 1. TỔNG QUAN ĐỀ TÀI", 1)
    add_heading(doc, "1.1. Lý do chọn đề tài", 2)
    add_body(doc, "Thị trường truyện tranh cũ và các ấn phẩm sưu tầm có đặc điểm phân tán: người mua khó tìm đúng phiên bản, tình trạng và mức giá; người bán thiếu công cụ quản lý kho và đơn hàng; các giao dịch trao đổi hoặc đấu giá thường diễn ra qua nhiều kênh riêng lẻ. Việc xây dựng một nền tảng chuyên biệt giúp chuẩn hóa dữ liệu truyện, tập trung hoạt động mua bán và tạo ra quy trình giao dịch minh bạch hơn.")
    add_body(doc, "Flutter phù hợp với mục tiêu phát triển đa nền tảng từ một mã nguồn. Firebase cung cấp nhóm dịch vụ xác thực, cơ sở dữ liệu thời gian thực, hàm phía máy chủ và cơ chế phân quyền, giúp đồ án tập trung vào nghiệp vụ mà vẫn bảo đảm được luồng dữ liệu chính. Vì vậy, đề tài lựa chọn xây dựng ComZone bằng Flutter và Firebase.")

    add_heading(doc, "1.2. Mục tiêu của đồ án", 2)
    add_heading(doc, "1.2.1. Mục tiêu tổng quát", 3)
    add_body(doc, "Xây dựng ứng dụng mua bán, trao đổi và đấu giá truyện tranh có thể chạy trên nhiều nền tảng, hỗ trợ đầy đủ luồng của khách hàng, người bán và bộ phận quản trị; dữ liệu được đồng bộ theo thời gian thực, các thao tác nhạy cảm được kiểm soát bằng phân quyền và transaction.")
    add_heading(doc, "1.2.2. Mục tiêu cụ thể", 3)
    add_bullets(doc, [
        "Xây dựng quy trình đăng ký, đăng nhập và khôi phục mật khẩu bằng email hoặc OTP điện thoại.",
        "Tổ chức danh mục truyện theo thể loại, tình trạng, phiên bản và hàng hóa kèm theo; hỗ trợ tìm kiếm, lọc, sắp xếp và lưu truyện yêu thích.",
        "Triển khai giỏ hàng, thanh toán, tạo đơn, theo dõi trạng thái và quản lý đơn theo vai trò người mua/người bán.",
        "Triển khai quy trình đăng ký người bán, duyệt hồ sơ, quản lý kho, doanh thu và yêu cầu bán truyện.",
        "Triển khai đấu giá có yêu cầu, kiểm duyệt, đặt cọc, ra giá, mua ngay, xác định người thắng, thanh toán và xử lý quá hạn.",
        "Hỗ trợ trao đổi truyện, chat thời gian thực, thông báo, ví và lịch sử giao dịch.",
        "Xây dựng Admin Hub để quản lý người dùng, danh mục, đơn hàng, yêu cầu, đấu giá, ví và dữ liệu seed.",
        "Thiết lập kiểm soát truy cập theo vai trò và kiểm thử các quy tắc nghiệp vụ cốt lõi.",
    ])

    add_heading(doc, "1.3. Đối tượng và phạm vi", 2)
    add_heading(doc, "1.3.1. Đối tượng nghiên cứu", 3)
    add_body(doc, "Đối tượng nghiên cứu là quy trình vận hành của một sàn truyện tranh chuyên biệt, bao gồm quản lý tài khoản, catalog, đặt mua, bán hàng, đấu giá, trao đổi, ví, chat và quản trị. Về kỹ thuật, đồ án nghiên cứu cách tổ chức ứng dụng Flutter kết nối Firebase, xử lý dữ liệu realtime, transaction và Security Rules.")
    add_heading(doc, "1.3.2. Phạm vi thực hiện", 3)
    add_bullets(doc, [
        "Ứng dụng phía người dùng được xây dựng bằng Flutter và có cấu hình Web, Android, iOS, macOS.",
        "Dữ liệu nghiệp vụ được lưu trong Cloud Firestore; Firebase Realtime Database có trong dependency nhưng luồng chat hiện tại sử dụng subcollection Firestore.",
        "Cloud Functions xử lý đặt lại mật khẩu do Admin và toàn bộ nghiệp vụ đấu giá nhạy cảm.",
        "Thanh toán ví hiện được mô hình hóa bằng số dư, yêu cầu nạp/rút và transaction; chưa tích hợp cổng thanh toán thương mại thực tế.",
        "Dữ liệu ComZone công khai được chuyển đổi thành seed nội bộ; dữ liệu xác thực và thông tin riêng tư không được đóng gói.",
    ])

    add_heading(doc, "1.4. Phương pháp thực hiện", 2)
    add_numbers(doc, [
        "Khảo sát mã nguồn ComZone gốc và xác định các tác nhân, module, quy tắc nghiệp vụ cần chuyển đổi.",
        "Phân tích use case, trạng thái dữ liệu và ranh giới quyền của từng vai trò.",
        "Thiết kế mô hình collection Firestore và ánh xạ từ mô hình MySQL/NestJS.",
        "Phát triển giao diện Flutter theo module; tạo lớp dịch vụ dùng chung cho Auth, Firestore và Functions.",
        "Thiết lập Security Rules, transaction và Cloud Functions cho các thao tác yêu cầu độ tin cậy cao.",
        "Nhập dữ liệu seed, kiểm thử logic/widget, rà soát lỗi và hoàn thiện báo cáo.",
    ])

    add_heading(doc, "1.5. Kết quả đạt được", 2)
    add_body(doc, "Sản phẩm hiện có 65 tệp Dart thuộc thư mục mã nguồn, kiểm thử và công cụ với khoảng 15.957 dòng; nhóm Cloud Functions và kiểm thử Node.js có khoảng 743 dòng; tệp Firestore Rules có 417 dòng. Seed hiện tại chứa 192 tài liệu công khai thuộc 13 collection, trong đó có 116 truyện và 20 phiên đấu giá. Các con số này phản ánh trạng thái mã nguồn tại thời điểm lập báo cáo và có thể thay đổi khi dự án tiếp tục phát triển.")


def chapter_2(doc):
    add_heading(doc, "CHƯƠNG 2. CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ", 1)
    add_heading(doc, "2.1. Flutter và ngôn ngữ Dart", 2)
    add_body(doc, "Flutter là bộ công cụ xây dựng giao diện đa nền tảng dựa trên mô hình widget. Giao diện được mô tả bằng cây widget, trạng thái thay đổi làm framework dựng lại phần cần thiết. Trong ComZone, MaterialApp quản lý theme và điều hướng; các màn hình được chia theo features như catalog, auctions, exchange, orders, wallet, chat và notifications.")
    add_body(doc, "Dart cung cấp kiểu dữ liệu, async/await, Future và Stream. Future được dùng cho thao tác một lần như đăng nhập, tạo đơn hoặc gọi Cloud Function; Stream được dùng để lắng nghe snapshot của Firestore nhằm cập nhật danh sách truyện, đơn hàng, đấu giá, tin nhắn và thông báo theo thời gian thực.")

    add_heading(doc, "2.2. Firebase Authentication", 2)
    add_body(doc, "Firebase Authentication quản lý thông tin xác thực. ComZone hỗ trợ email/mật khẩu, Google Sign-In và khôi phục tài khoản bằng email hoặc OTP điện thoại. Mật khẩu không được ghi vào collection users. Hồ sơ Firestore chỉ lưu thông tin nghiệp vụ như họ tên, email, số điện thoại, vai trò và thời điểm cập nhật.")
    add_note(doc, "Quy tắc mật khẩu", "Tối thiểu 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt. Quy tắc được kiểm tra ở ứng dụng và ở Cloud Function đặt lại mật khẩu.")

    add_heading(doc, "2.3. Cloud Firestore", 2)
    add_body(doc, "Cloud Firestore là cơ sở dữ liệu NoSQL dạng tài liệu. Dữ liệu được tổ chức theo collection/document, phù hợp với mô hình truy vấn theo tài khoản và theo trạng thái của ComZone. Firestore hỗ trợ realtime listener, batch và transaction. Transaction đặc biệt quan trọng đối với tạo đơn, duyệt yêu cầu bán, đặt giá và cập nhật ví vì giúp đọc–kiểm tra–ghi trong một thao tác nguyên tử.")

    add_heading(doc, "2.4. Cloud Functions và Scheduler", 2)
    add_body(doc, "Cloud Functions cung cấp môi trường tin cậy dùng Firebase Admin SDK. Ứng dụng hiện triển khai callable function setUserPassword và nhóm hàm đấu giá: createAuctionRequest, reviewAuctionRequest, placeAuctionDeposit, placeAuctionBid, buyNowAuction, payAuction, cancelAuction, syncAuction. Hàm processAuctions chạy theo lịch để chuyển trạng thái phiên, xác định kết quả và xử lý quá hạn.")

    add_heading(doc, "2.5. Firebase Security Rules và RBAC", 2)
    add_body(doc, "Security Rules là lớp bảo vệ dữ liệu độc lập với giao diện. Hệ thống chuẩn hóa bốn vai trò customer, seller, moderator và admin. Các hàm isAdmin, isModerator, isStaff, isSeller và hasApprovedSellerProfile được tái sử dụng trong rules. Dữ liệu tài chính và kết quả đấu giá không cho client ghi trực tiếp; Admin SDK trong Cloud Functions thực hiện các cập nhật đó.")

    add_heading(doc, "2.6. Công nghệ sử dụng", 2)
    add_table(doc, ["Thành phần", "Công nghệ", "Vai trò trong đồ án"], [
        ("Client", "Flutter / Dart", "Xây dựng giao diện responsive và luồng nghiệp vụ đa nền tảng"),
        ("Xác thực", "Firebase Authentication", "Email/Password, Google Sign-In, Phone OTP"),
        ("Cơ sở dữ liệu", "Cloud Firestore", "Lưu dữ liệu nghiệp vụ, transaction và realtime snapshot"),
        ("Backend tin cậy", "Firebase Cloud Functions v2 / Node.js", "Đấu giá, scheduler, thao tác mật khẩu đặc quyền"),
        ("Phân quyền", "Firestore Security Rules", "RBAC, kiểm tra chủ sở hữu, hạn chế trường cập nhật"),
        ("Kiểm thử", "flutter_test / node:test", "Unit test và widget test"),
        ("Công cụ triển khai", "Firebase CLI / Flutter CLI", "Triển khai rules, indexes, functions và build ứng dụng"),
    ], [3.0, 4.5, 8.5], caption="Bảng 2. Công nghệ chính của hệ thống")


def chapter_3(doc):
    add_heading(doc, "CHƯƠNG 3. PHÂN TÍCH YÊU CẦU HỆ THỐNG", 1)
    add_heading(doc, "3.1. Các tác nhân", 2)
    add_figure(doc, ASSET_DIR / "actor_map.png", "Hình 1. Bản đồ tác nhân của hệ thống ComZone")
    add_table(doc, ["Tác nhân", "Vai trò và nhu cầu chính"], [
        ("Khách hàng", "Tạo tài khoản, duyệt truyện, mua hàng, tham gia đấu giá, trao đổi, chat, quản lý ví và hồ sơ."),
        ("Người bán", "Quản lý danh sách truyện, tồn kho, giá, đơn hàng, doanh thu và tạo yêu cầu đấu giá."),
        ("Moderator", "Kiểm duyệt nội dung và nghiệp vụ được phân công, đặc biệt yêu cầu đấu giá và phản hồi người bán."),
        ("Admin", "Quản trị người dùng, vai trò, danh mục, đơn hàng, yêu cầu bán, ví, đấu giá, cấu hình và seed dữ liệu."),
    ], [3.2, 12.8], caption="Bảng 3. Mô tả tác nhân")

    add_heading(doc, "3.2. Yêu cầu chức năng", 2)
    requirements = [
        ("FR-01", "Tài khoản", "Đăng ký bằng họ tên, email, số điện thoại và mật khẩu mạnh."),
        ("FR-02", "Tài khoản", "Đăng nhập bằng email/mật khẩu hoặc Google; theo dõi trạng thái đăng nhập."),
        ("FR-03", "Tài khoản", "Khôi phục mật khẩu bằng email hoặc OTP số điện thoại, có đếm ngược 120 giây."),
        ("FR-04", "Catalog", "Hiển thị danh mục, chi tiết, ảnh bìa, thể loại, tình trạng, giá và tồn kho."),
        ("FR-05", "Catalog", "Lọc, sắp xếp, tìm kiếm và lưu truyện yêu thích."),
        ("FR-06", "Mua hàng", "Thêm nhiều sản phẩm vào giỏ và tạo đơn theo luồng checkout."),
        ("FR-07", "Đơn hàng", "Theo dõi trạng thái và lịch sử; seller/admin cập nhật trạng thái hợp lệ."),
        ("FR-08", "Seller", "Đăng ký Seller; Admin duyệt hoặc từ chối kèm lý do."),
        ("FR-09", "Seller", "Tạo yêu cầu bán, quản lý kho, giá, trạng thái, đơn và doanh thu."),
        ("FR-10", "Đấu giá", "Tạo và duyệt yêu cầu đấu giá; quản lý lịch bắt đầu/kết thúc."),
        ("FR-11", "Đấu giá", "Đặt cọc, ra giá, mua ngay, xác định người thắng và thanh toán bằng ví."),
        ("FR-12", "Trao đổi", "Tạo bài trao đổi, gửi yêu cầu, chấp nhận hoặc từ chối."),
        ("FR-13", "Tương tác", "Chat realtime, thông báo, theo dõi seller và gửi phản hồi."),
        ("FR-14", "Ví", "Xem số dư, lịch sử, tạo yêu cầu nạp/rút; staff kiểm duyệt."),
        ("FR-15", "Quản trị", "Dashboard và quản lý người dùng, danh mục, đơn, đấu giá, feedback và dữ liệu seed."),
    ]
    add_table(doc, ["Mã", "Nhóm", "Yêu cầu"], requirements, [2.0, 3.0, 11.0], caption="Bảng 4. Danh sách yêu cầu chức năng")

    add_heading(doc, "3.3. Yêu cầu phi chức năng", 2)
    add_table(doc, ["Mã", "Thuộc tính", "Yêu cầu"], [
        ("NFR-01", "Bảo mật", "Không lưu mật khẩu ở Firestore; xác thực Firebase; kiểm soát trường ghi và vai trò bằng Security Rules."),
        ("NFR-02", "Toàn vẹn", "Các thao tác tồn kho, ví, đấu giá và duyệt yêu cầu sử dụng transaction hoặc backend tin cậy."),
        ("NFR-03", "Hiệu năng", "Danh sách dùng stream và truy vấn theo collection; hạn chế dữ liệu không cần thiết trên từng màn hình."),
        ("NFR-04", "Khả dụng", "Giao diện responsive, có trạng thái tải, rỗng và thông báo lỗi thân thiện."),
        ("NFR-05", "Bảo trì", "Mã nguồn tách theo feature và service; quy tắc nghiệp vụ quan trọng có kiểm thử."),
        ("NFR-06", "Khả chuyển", "Một mã nguồn Flutter hướng đến Web, Android, iOS và macOS."),
        ("NFR-07", "Riêng tư", "Seed công khai loại mật khẩu, token, OTP, email, điện thoại, địa chỉ, tài khoản ngân hàng và lịch sử tài chính."),
    ], [2.2, 3.2, 10.6], caption="Bảng 5. Yêu cầu phi chức năng")

    add_heading(doc, "3.4. Quy tắc nghiệp vụ chính", 2)
    add_bullets(doc, [
        "Mật khẩu phải có tối thiểu 8 ký tự và đủ bốn nhóm ký tự; mật khẩu xác nhận phải trùng khớp.",
        "Tài khoản mới có vai trò customer; chỉ Admin được thay đổi vai trò. Seller chỉ hợp lệ sau khi hồ sơ được duyệt.",
        "Đơn mới có trạng thái Chờ xác nhận; chuỗi trạng thái hợp lệ gồm Chờ xác nhận, Đang xử lý, Đang giao, Đã giao, Đã hủy.",
        "Người mua chỉ đặt được truyện đang active và còn hàng; transaction tạo đơn và trừ tồn kho cùng lúc.",
        "Seller chỉ cập nhật giá, tồn kho và trạng thái của truyện thuộc mình; doanh thu giao diện chỉ tính đơn Đã giao và áp dụng phí sàn 15%.",
        "Seller không được tham gia đấu giá truyện của mình; người mua phải có khoản cọc holding trước khi ra giá.",
        "Giá mới ít nhất bằng giá hiện tại cộng bước giá và phải nhỏ hơn giá mua ngay; mua ngay kết thúc quá trình ra giá.",
        "Dữ liệu ví, tiền cọc, người thắng và kết quả đấu giá chỉ được cập nhật từ Cloud Functions/Admin SDK.",
    ])

    add_heading(doc, "3.5. Các luồng nghiệp vụ tiêu biểu", 2)
    add_heading(doc, "3.5.1. Luồng đặt mua truyện", 3)
    add_figure(doc, ASSET_DIR / "order_flow.png", "Hình 2. Luồng xử lý đơn mua truyện", 16.0)
    add_body(doc, "Khi người dùng xác nhận checkout, ứng dụng đọc truyện, kiểm tra giá và tồn kho, sau đó chạy transaction. Transaction tạo document orders và giảm stock của comics, đồng thời lưu lastOrderId để Security Rules đối chiếu. Seller hoặc staff chỉ được đổi trường status và updatedAt theo danh sách trạng thái hợp lệ.")
    add_heading(doc, "3.5.2. Luồng đấu giá", 3)
    add_figure(doc, ASSET_DIR / "auction_flow.png", "Hình 3. Luồng nghiệp vụ đấu giá có đặt cọc", 16.0)
    add_body(doc, "Đấu giá được tách thành yêu cầu và phiên để bảo đảm bước kiểm duyệt. Cloud Functions đọc cấu hình Admin để tính bước giá, tiền cọc và giới hạn mua ngay. Scheduler chạy định kỳ để kích hoạt/kết thúc phiên và xử lý hạn thanh toán. Các cập nhật tài chính đều nằm trong transaction backend.")


def chapter_4(doc):
    add_heading(doc, "CHƯƠNG 4. THIẾT KẾ HỆ THỐNG", 1)
    add_heading(doc, "4.1. Kiến trúc tổng thể", 2)
    add_figure(doc, ASSET_DIR / "architecture.png", "Hình 4. Kiến trúc tổng thể của ComZone", 16.0)
    add_body(doc, "Kiến trúc gồm ba ranh giới chính. Lớp trình bày Flutter chứa widget, điều hướng và trạng thái giao diện. Lớp dịch vụ tại lib/service bao bọc Firebase Authentication, Firestore và Cloud Functions. Lớp backend gồm các dịch vụ Firebase, nơi dữ liệu được bảo vệ bằng Security Rules và các nghiệp vụ đặc quyền được thực hiện bằng Admin SDK.")

    add_heading(doc, "4.2. Tổ chức mã nguồn", 2)
    add_table(doc, ["Đường dẫn", "Trách nhiệm"], [
        ("lib/app.dart", "Khởi tạo MaterialApp, AuthScreen, MainScreen, header và giỏ hàng."),
        ("lib/core/models.dart", "Mô hình ComicItem và AuctionItem dùng tại client."),
        ("lib/service/", "AuthService, DatabaseService, AuctionService và AdminAuthService."),
        ("lib/features/catalog/", "Danh mục, bộ lọc, chi tiết và truyện đã lưu."),
        ("lib/features/auctions/", "Danh sách, chi tiết, lịch sử và quy tắc trạng thái đấu giá."),
        ("lib/features/exchange/", "Bài trao đổi, chi tiết và yêu cầu trao đổi."),
        ("lib/features/orders/", "Danh sách và chi tiết đơn hàng của người mua."),
        ("lib/features/wallet/", "Ví, yêu cầu nạp/rút và lịch sử giao dịch."),
        ("lib/features/chat/", "Danh sách phòng và tin nhắn realtime."),
        ("lib/seller/", "Seller Hub: dashboard, kho, đơn, doanh thu và đấu giá."),
        ("lib/admin/", "Admin Hub, quy tắc phân loại đơn và hộp thoại đặt mật khẩu."),
        ("functions/", "Cloud Functions cho mật khẩu Admin và nghiệp vụ đấu giá."),
        ("firestore.rules", "Chính sách truy cập cho toàn bộ collection."),
    ], [5.0, 11.0], caption="Bảng 6. Tổ chức các module mã nguồn")

    add_heading(doc, "4.3. Thiết kế dữ liệu Firestore", 2)
    add_body(doc, "Mô hình dữ liệu được chuyển từ hệ thống NestJS/MySQL sang các collection Firestore. Quan hệ được thể hiện bằng UID hoặc document ID lưu trực tiếp trong document. Với dữ liệu cần giữ nguyên tại thời điểm giao dịch, đơn hàng lưu snapshot tên, ảnh và giá truyện thay vì chỉ phụ thuộc document comics có thể thay đổi sau đó.")
    collections = [
        ("users", "Hồ sơ, email, điện thoại, role", "UID Firebase Auth"),
        ("seller_registration_requests", "Hồ sơ đăng ký Seller và trạng thái duyệt", "userId"),
        ("seller_profiles", "Thông tin công khai và trạng thái Seller", "UID Seller"),
        ("comics", "Thông tin truyện, sellerUid, giá, stock, status", "sellerUid, sourceRequestId"),
        ("orders", "Snapshot đơn mua, buyer, seller, trạng thái", "userId, sellerUid, comicId"),
        ("sell_requests", "Yêu cầu đăng bán và kết quả duyệt", "userId"),
        ("auction_requests", "Yêu cầu đấu giá pending/approved/rejected", "sellerUid, comicId"),
        ("auctions", "Phiên, giá, thời gian, người thắng, thanh toán", "requestId, comicId, sellerUid"),
        ("auction_bids", "Lịch sử ra giá", "auctionId, userId"),
        ("auction_deposits", "Tiền cọc holding/refunded/used/seized", "auctionId, userId"),
        ("exchange_posts", "Bài trao đổi công khai", "userId"),
        ("exchange_requests", "Yêu cầu giữa hai participant", "postId, participants"),
        ("wallets", "balance và heldBalance", "UID người dùng"),
        ("wallet_requests", "Yêu cầu nạp/rút", "userId"),
        ("wallet_transactions", "Lịch sử biến động ví", "userId, refId"),
        ("chats/{chatId}/messages", "Phòng chat và tin nhắn", "participants, senderId"),
        ("notifications", "Thông báo và trạng thái đã đọc", "userId"),
        ("comic_*", "Danh mục thể loại/tình trạng/phiên bản/merchandise", "ID danh mục"),
    ]
    add_table(doc, ["Collection", "Nội dung", "Liên kết chính"], collections, [4.3, 7.8, 3.9], caption="Bảng 7. Các collection chính")

    add_heading(doc, "4.4. Thiết kế phân quyền", 2)
    add_table(doc, ["Tài nguyên", "Customer", "Seller", "Moderator", "Admin"], [
        ("Hồ sơ users", "Đọc/sửa hồ sơ mình", "Đọc/sửa hồ sơ mình", "Đọc người dùng", "Quản lý vai trò/người dùng"),
        ("Comics", "Đọc; giảm stock khi tạo đơn hợp lệ", "Sửa giá/stock/status truyện mình", "Tạo/sửa khi kiểm duyệt", "Toàn quyền"),
        ("Orders", "Tạo và đọc đơn mình", "Đọc/sửa trạng thái đơn thuộc mình", "Đọc/sửa", "Toàn quyền"),
        ("Auctions/bids/deposits", "Đọc; ghi qua Function", "Đọc; tạo/dừng qua Function", "Duyệt qua Function", "Cấu hình và quản trị"),
        ("Wallets", "Đọc ví mình; yêu cầu nạp/rút", "Tương tự Customer", "Kiểm duyệt", "Toàn quyền"),
        ("Danh mục cấu hình", "Đọc", "Đọc", "Đọc", "Tạo/sửa/xóa mềm"),
        ("Audit log", "Không", "Không", "Không", "Chỉ đọc; Function ghi"),
    ], [3.4, 3.2, 3.2, 3.2, 3.0], caption="Bảng 8. Ma trận quyền rút gọn")

    add_heading(doc, "4.5. Thiết kế giao diện và trải nghiệm", 2)
    add_body(doc, "Giao diện sử dụng Material Design kết hợp bộ màu MangaColors gồm màu mực, kem, xanh, đỏ, vàng và các màu phụ. MainScreen theo dõi role người dùng để mở các khu vực phù hợp. LayoutBuilder và các widget responsive giúp header, danh sách và thẻ nội dung thích nghi với màn hình Web hoặc thiết bị di động.")
    add_bullets(doc, [
        "Màn hình xác thực tách rõ đăng nhập/đăng ký, hiển thị quy tắc mật khẩu và thông báo lỗi thân thiện.",
        "Catalog cung cấp bộ lọc theo dữ liệu thực tế, tránh trùng thể loại và xử lý truyện đa thể loại.",
        "Các màn dữ liệu realtime đều có trạng thái đang tải, không có dữ liệu và lỗi.",
        "Seller Hub và Admin Hub dùng sidebar/dashboard, KPI và bảng quản lý phù hợp nghiệp vụ.",
        "Các hành động nhạy cảm có hộp thoại xác nhận hoặc nhập lý do; nút bị vô hiệu khi đang xử lý.",
    ])


def chapter_5(doc):
    add_heading(doc, "CHƯƠNG 5. CÀI ĐẶT VÀ TRIỂN KHAI", 1)
    add_heading(doc, "5.1. Khởi tạo ứng dụng", 2)
    add_body(doc, "Hàm main gọi WidgetsFlutterBinding.ensureInitialized, khởi tạo Firebase bằng DefaultFirebaseOptions.currentPlatform và chạy ComicBookApp. MaterialApp cấu hình theme Manga, loại bỏ banner debug và dùng trạng thái Firebase Auth để chuyển giữa màn hình xác thực, loading và MainScreen.")
    p = doc.add_paragraph(style="Source Code")
    set_run_font(p.add_run("flutter pub get\nflutter run\nflutter run -d chrome\nflutter build web"), 10)

    add_heading(doc, "5.2. Xác thực và khôi phục mật khẩu", 2)
    add_body(doc, "AuthService đóng gói createUserWithEmailAndPassword, signInWithEmailAndPassword, sendPasswordResetEmail, verifyPhoneNumber và signOut. Sau đăng ký, DatabaseService tạo users/{uid} với role customer. ForgotPasswordScreen quản lý các bước identifier, emailSent, phoneOtp, newPassword và success; bộ đếm OTP có thời hạn 120 giây và chỉ cho gửi lại sau khi hết thời gian.")
    add_body(doc, "Admin đặt mật khẩu mới cho người dùng bằng callable setUserPassword. Function kiểm tra request đã xác thực, đọc role Admin từ Firestore, kiểm tra mật khẩu mạnh, cập nhật Firebase Authentication bằng Admin SDK và ghi admin_audit_logs mà không lưu giá trị mật khẩu.")

    add_heading(doc, "5.3. Catalog, giỏ hàng và đơn hàng", 2)
    add_body(doc, "DatabaseService cung cấp comicsStream để giao diện lắng nghe danh mục. ComicItem lưu id, title, author, price, coverImage, description, genre, stock và sellerUid. CatalogFilters lấy tập thể loại thực tế và đối chiếu từng thể loại của truyện. MainScreen giữ giỏ hàng cục bộ, mở CartSheet và chuyển sang CheckoutPage.")
    add_body(doc, "createOrder chạy Firestore transaction. Với truyện tồn tại, transaction kiểm tra status active, stock > 0, dùng giá/sellerUid từ document, tạo order và cập nhật stock = stock - 1. Khi không có document nguồn, hệ thống vẫn hỗ trợ dữ liệu demo theo nhánh có sellerUid rỗng. Đơn lưu buyerEmail, thông tin nhận hàng, snapshot truyện và trạng thái Chờ xác nhận.")
    add_figure(doc, ASSET_DIR / "order_flow.png", "Hình 5. Transaction tạo đơn và cập nhật tồn kho", 16.0)

    add_heading(doc, "5.4. Seller Hub", 2)
    add_body(doc, "Seller cần gửi seller_registration_requests. Khi Admin duyệt, transaction cập nhật request, tạo seller_profiles và đổi role users sang seller. Sau khi được duyệt, Seller Hub tổng hợp dữ liệu Firestore thật cho dashboard, kho, đơn hàng và doanh thu.")
    add_bullets(doc, [
        "Danh sách truyện của seller truy vấn theo sellerUid; cho phép sửa price, stock và status.",
        "Đơn của seller truy vấn theo sellerUid; seller chỉ cập nhật trạng thái trong danh sách hợp lệ.",
        "Doanh thu tính từ đơn Đã giao; giao diện đối soát áp dụng phí sàn 15%.",
        "Seller có thể tạo yêu cầu đăng truyện và yêu cầu đấu giá từ truyện đủ điều kiện.",
    ])

    add_heading(doc, "5.5. Đấu giá", 2)
    add_body(doc, "AuctionService phía Flutter chỉ là lớp gọi callable function. Logic quyết định được đặt tại functions/auction.js. createAuctionRequest xác minh quyền Seller, thời lượng 1–7 ngày, truyện thuộc Seller, còn hàng và chưa có phiên trùng; sau đó tính startingBid, bidIncrement, depositAmount và giới hạn buyNowPrice từ cấu hình.")
    add_body(doc, "placeAuctionDeposit chuyển tiền từ balance sang heldBalance. placeAuctionBid kiểm tra phiên active, người dùng không phải Seller, có cọc holding và giá đạt mức tối thiểu. Khi bị vượt giá, người dẫn đầu cũ nhận thông báo. buyNowAuction xác định người thắng ngay. payAuction khấu trừ cọc, trừ phần còn thiếu, chuyển doanh thu cho Seller, tạo order và cập nhật trạng thái cọc/phiên trong transaction.")
    add_body(doc, "processAuctions chạy mỗi phút để bắt đầu phiên upcoming, kết thúc phiên active, hoàn cọc người thua và xử lý người thắng quá hạn. Người thắng quá hạn bị thu cọc chuyển cho Seller; phiên không có giá bị hủy và hoàn toàn bộ cọc.")

    add_heading(doc, "5.6. Trao đổi, chat, thông báo và ví", 2)
    add_body(doc, "exchange_posts lưu bài đang hoạt động; exchange_requests lưu người gửi, người nhận, participants và trạng thái. Người nhận được phép chấp nhận hoặc từ chối. Chat dùng chats/{chatId} và subcollection messages; chỉ participant được đọc/gửi tin, tin nhắn không cho sửa hoặc xóa từ client.")
    add_body(doc, "notifications lưu userId, loại, tiêu đề, nội dung, liên kết và isRead; người dùng chỉ được đánh dấu thông báo của mình đã đọc. wallets tách balance và heldBalance; wallet_requests mô hình hóa nạp/rút ở trạng thái pending; staff thực hiện bước kiểm duyệt và tạo wallet_transactions.")

    add_heading(doc, "5.7. Nhập dữ liệu ComZone", 2)
    add_body(doc, "Công cụ trong thư mục tool chuyển dữ liệu nguồn sang assets/data/comzone_public_seed.json, tải ảnh nội bộ và tạo manifest. Chức năng import dùng ID gốc và SetOptions(merge: true) nên có thể chạy lại mà không tạo bản ghi trùng. Bản seed được kiểm tra tại thời điểm báo cáo có 192 document: 116 comics, 20 genres, 9 conditions, 3 editions, 12 merchandises, 7 seller_profiles, 20 auctions, 1 auction_config, 1 auction_criteria và 3 seller_subscription_plans.")
    add_note(doc, "Bảo vệ dữ liệu", "Seed không chứa mật khẩu, refresh token, device ID, OTP, email, số điện thoại, địa chỉ, tài khoản ngân hàng và lịch sử tài chính.")

    add_heading(doc, "5.8. Cấu hình triển khai", 2)
    add_numbers(doc, [
        "Bật Email/Password trong Firebase Authentication; bật Phone nếu dùng OTP và cấu hình SHA/APNs/reCAPTCHA theo nền tảng.",
        "Tạo Cloud Firestore và triển khai firestore.rules cùng firestore.indexes.json.",
        "Triển khai Cloud Functions, đặc biệt setUserPassword và nhóm hàm đấu giá; bật Scheduler cho processAuctions.",
        "Tạo user Admin trong Authentication, sau đó đặt role admin tại users/{uid} bằng quy trình quản trị ban đầu đáng tin cậy.",
        "Đối với môi trường phát hành, chạy flutterfire configure để thay cấu hình Firebase dùng chung bằng ứng dụng chính thức.",
    ])


def chapter_6(doc):
    add_heading(doc, "CHƯƠNG 6. KIỂM THỬ VÀ ĐÁNH GIÁ", 1)
    add_heading(doc, "6.1. Chiến lược kiểm thử", 2)
    add_body(doc, "Đồ án sử dụng unit test cho quy tắc nghiệp vụ, widget test cho giao diện và node:test cho Cloud Functions. Kiểm thử ưu tiên các khu vực có rủi ro cao: xác thực, lọc catalog, trạng thái đấu giá, quy tắc đơn hàng, dữ liệu seed, ảnh nội bộ và thao tác Admin.")

    add_heading(doc, "6.2. Kết quả kiểm thử tự động", 2)
    add_table(doc, ["Nhóm", "Số kiểm thử", "Kết quả", "Nội dung tiêu biểu"], [
        ("Flutter", "35", "Đạt", "Auth validators, catalog filters, auction rules, widget, Seller dashboard, seed, ảnh, thông báo, dialog Admin."),
        ("Cloud Functions", "2", "Đạt", "Chấp nhận mật khẩu mạnh và từ chối mật khẩu yếu/không phải chuỗi."),
        ("Tổng", "37", "Đạt", "Không có kiểm thử thất bại tại thời điểm chạy báo cáo."),
    ], [3.0, 2.4, 2.4, 8.2], caption="Bảng 9. Kết quả chạy kiểm thử ngày 22/08/2026")

    add_heading(doc, "6.3. Các ca kiểm thử tiêu biểu", 2)
    add_table(doc, ["Mã", "Ca kiểm thử", "Kết quả mong đợi", "Kết quả"], [
        ("TC-01", "Email hợp lệ/sai định dạng", "Chấp nhận email đúng; báo lỗi email sai", "Đạt"),
        ("TC-02", "Mật khẩu thiếu từng nhóm ký tự", "Thông báo đúng điều kiện còn thiếu", "Đạt"),
        ("TC-03", "Chuẩn hóa số điện thoại Việt Nam", "Chuyển sang định dạng E.164", "Đạt"),
        ("TC-04", "Truyện có nhiều thể loại", "Khớp khi lọc theo từng thể loại", "Đạt"),
        ("TC-05", "Tính bước giá và tiền cọc", "Kết quả đúng theo AuctionConfig", "Đạt"),
        ("TC-06", "Phiên upcoming đến giờ", "Trạng thái hiệu lực thành active", "Đạt"),
        ("TC-07", "Phiên hết giờ có/không có bid", "successful hoặc cancelled tương ứng", "Đạt"),
        ("TC-08", "Thêm truyện còn hàng", "Comic detail gọi callback thêm giỏ", "Đạt"),
        ("TC-09", "Dữ liệu seed riêng tư", "Không có trường xác thực/riêng tư", "Đạt"),
        ("TC-10", "Thẻ thông báo mobile", "Không tràn layout", "Đạt"),
        ("TC-11", "Dialog Admin xác nhận/hủy", "Trả mật khẩu hợp lệ hoặc null an toàn", "Đạt"),
        ("TC-12", "Password policy phía Node", "Cùng quy tắc với client", "Đạt"),
    ], [1.8, 5.0, 6.8, 2.4], caption="Bảng 10. Một số ca kiểm thử tiêu biểu")

    add_heading(doc, "6.4. Đánh giá kết quả", 2)
    add_heading(doc, "6.4.1. Ưu điểm", 3)
    add_bullets(doc, [
        "Phạm vi nghiệp vụ rộng nhưng được tách module rõ ràng theo feature và vai trò.",
        "Dữ liệu realtime tạo trải nghiệm cập nhật nhanh cho catalog, đơn, đấu giá, chat và thông báo.",
        "Các thao tác rủi ro cao được đưa vào transaction hoặc Cloud Functions; client không tự quyết định kết quả tài chính.",
        "Security Rules kiểm tra vai trò, chủ sở hữu, trường được phép thay đổi và liên kết getAfter/existsAfter.",
        "Dữ liệu seed có cơ chế nhập lặp an toàn và loại thông tin riêng tư.",
        "Bộ kiểm thử hiện có bao phủ nhiều quy tắc lõi và giao diện dễ lỗi trên mobile.",
    ])
    add_heading(doc, "6.4.2. Hạn chế", 3)
    add_bullets(doc, [
        "Chưa tích hợp cổng thanh toán thực và quy trình đối soát ngân hàng; ví hiện là mô hình nghiệp vụ nội bộ.",
        "Chưa có kiểm thử tích hợp chạy với Firebase Emulator cho toàn bộ transaction và Security Rules.",
        "Một số luồng quản trị và Seller Hub có quy mô tệp lớn, cần tiếp tục tách widget/controller để dễ bảo trì.",
        "Chưa có hệ thống lưu trữ ảnh người dùng lên Cloud Storage; nhiều ảnh hiện là asset nội bộ.",
        "Chưa có giám sát sản xuất, phân tích hiệu năng truy vấn và cơ chế cảnh báo chi phí Firebase.",
        "Chưa có kiểm thử tải đồng thời cho phiên đấu giá đông người.",
    ])

    add_heading(doc, "6.5. Rủi ro và biện pháp", 2)
    add_table(doc, ["Rủi ro", "Tác động", "Biện pháp hiện tại / đề xuất"], [
        ("Hai người cùng mua sản phẩm cuối", "Âm tồn kho hoặc hai đơn cho một sản phẩm", "Transaction đọc stock và cập nhật atomically; bổ sung emulator test đồng thời."),
        ("Ra giá đồng thời", "Sai giá hiện tại hoặc người dẫn đầu", "Cloud Function transaction; kiểm thử tải và idempotency."),
        ("Client sửa dữ liệu ví", "Gian lận số dư", "Rules chặn ghi trực tiếp; Function/Admin SDK thực hiện."),
        ("Lộ thông tin xác thực", "Mất tài khoản", "Firebase Auth quản lý mật khẩu; seed/rules chặn password fields."),
        ("Truy vấn thiếu index", "Lỗi hoặc chậm", "Khai báo firestore.indexes.json; sắp xếp một số lịch sử tại client."),
        ("Chi phí listener tăng", "Tăng chi phí Firestore", "Giới hạn truy vấn, phân trang và hủy stream khi rời màn hình."),
    ], [4.1, 4.5, 7.4], caption="Bảng 11. Rủi ro chính và biện pháp")


def conclusion(doc):
    add_heading(doc, "KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN", 1)
    add_heading(doc, "1. Kết luận", 2)
    add_body(doc, "Đồ án đã xây dựng được một ứng dụng ComZone có phạm vi tương đối hoàn chỉnh cho lĩnh vực truyện tranh: từ xác thực, catalog, giỏ hàng, đơn hàng đến đăng ký Seller, quản lý kho, đấu giá có đặt cọc, trao đổi, chat, thông báo, ví và quản trị. Kiến trúc Flutter kết hợp Firebase giúp rút ngắn thời gian phát triển nhưng vẫn cung cấp được realtime, transaction và phân quyền.")
    add_body(doc, "Điểm quan trọng nhất của giải pháp là đặt ranh giới tin cậy đúng vị trí. Mật khẩu do Firebase Authentication quản lý; dữ liệu tài chính và kết quả đấu giá do Cloud Functions xử lý; Security Rules bảo vệ collection độc lập với giao diện. Kết quả 37 kiểm thử tự động đều đạt cho thấy các quy tắc chính đang hoạt động theo thiết kế, dù dự án vẫn cần thêm kiểm thử tích hợp và tải trước khi vận hành thực tế.")

    add_heading(doc, "2. Hướng phát triển", 2)
    add_bullets(doc, [
        "Tích hợp Firebase Emulator Suite và viết kiểm thử tích hợp cho Authentication, Firestore Rules, Functions và transaction.",
        "Tích hợp cổng thanh toán, webhook xác nhận, đối soát và quy trình hoàn tiền đáng tin cậy.",
        "Bổ sung Cloud Storage cho ảnh đăng bán, kiểm duyệt nội dung và tối ưu ảnh theo kích thước thiết bị.",
        "Thêm phân trang, cache, tìm kiếm toàn văn và theo dõi chỉ số hiệu năng/cost.",
        "Bổ sung đánh giá người bán sau giao dịch, khiếu nại, hoàn trả và trung tâm hỗ trợ.",
        "Tăng cường kiểm thử tải đấu giá, chống gọi lặp, giới hạn tần suất và audit log cho hành động đặc quyền.",
        "Hoàn thiện CI/CD cho flutter analyze, flutter test, node test, rules test và triển khai theo môi trường.",
    ])


def references(doc):
    add_heading(doc, "TÀI LIỆU THAM KHẢO", 1)
    refs = [
        "[1] Flutter Documentation, https://docs.flutter.dev/.",
        "[2] Dart Documentation, https://dart.dev/guides.",
        "[3] Firebase Authentication Documentation, https://firebase.google.com/docs/auth.",
        "[4] Cloud Firestore Documentation, https://firebase.google.com/docs/firestore.",
        "[5] Cloud Functions for Firebase Documentation, https://firebase.google.com/docs/functions.",
        "[6] Firebase Security Rules Documentation, https://firebase.google.com/docs/rules.",
        "[7] OWASP Foundation, OWASP Application Security Verification Standard.",
        "[8] Mã nguồn và tài liệu nội bộ dự án ComZone: README.md, docs/comzone_firebase_schema.md, docs/comzone_data_migration.md, docs/auction_usecase_mapping.md.",
    ]
    for ref in refs:
        p = doc.add_paragraph(style="Normal")
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.left_indent = Cm(0.8)
        p.paragraph_format.first_line_indent = Cm(-0.8)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.3
        set_run_font(p.add_run(ref))


def appendices(doc):
    add_heading(doc, "PHỤ LỤC A. HƯỚNG DẪN CÀI ĐẶT VÀ CHẠY", 1)
    add_heading(doc, "A.1. Yêu cầu môi trường", 2)
    add_bullets(doc, [
        "Flutter SDK tương thích Dart SDK ^3.12.2.",
        "Firebase project đã bật Authentication và Cloud Firestore.",
        "Node.js và Firebase CLI để triển khai Functions, Rules và Indexes.",
        "Thiết bị hoặc trình duyệt hỗ trợ nền tảng muốn chạy.",
    ])
    add_heading(doc, "A.2. Các lệnh chính", 2)
    code = """flutter pub get
flutter run
flutter run -d chrome
flutter test

cd functions
npm test
cd ..

firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions"""
    p = doc.add_paragraph(style="Source Code")
    set_run_font(p.add_run(code), 10)
    add_heading(doc, "A.3. Tài khoản Admin ban đầu", 2)
    add_numbers(doc, [
        "Tạo tài khoản bằng Firebase Authentication hoặc ứng dụng.",
        "Tạo document users/{uid} tương ứng nếu chưa có.",
        "Dùng Firebase Console trong môi trường quản trị để đặt role thành admin.",
        "Đăng nhập lại để token và MainScreen nhận đúng vai trò.",
    ])

    add_heading(doc, "PHỤ LỤC B. ÁNH XẠ USE CASE VÀ MÃ NGUỒN", 1)
    add_table(doc, ["Use case", "Màn hình / dịch vụ chính", "Dữ liệu"], [
        ("Đăng ký/đăng nhập", "lib/app.dart, lib/service/auth.dart", "Firebase Auth, users"),
        ("Quên mật khẩu", "lib/forgot_password.dart", "Firebase Auth email/phone"),
        ("Duyệt và mua truyện", "features/catalog, features/checkout", "comics, orders"),
        ("Quản lý đơn", "features/orders, seller/seller_orders, admin_hub", "orders"),
        ("Đăng ký Seller", "features/profile/seller_registration_page", "seller_registration_requests, seller_profiles"),
        ("Đấu giá", "features/auctions, seller/seller_auctions, AuctionService", "auction_*; Cloud Functions"),
        ("Trao đổi", "features/exchange", "exchange_posts, exchange_requests"),
        ("Chat", "features/chat", "chats/{chatId}/messages"),
        ("Ví", "features/wallet", "wallets, wallet_requests, wallet_transactions"),
        ("Quản trị", "lib/admin/admin_hub_page.dart", "users, catalog, orders, requests"),
    ], [4.0, 6.2, 5.8], caption="Bảng 12. Ánh xạ use case sang mã nguồn")

    add_heading(doc, "PHỤ LỤC C. CHECKLIST HOÀN THIỆN TRƯỚC KHI NỘP", 1)
    add_bullets(doc, [
        "Thay toàn bộ thông tin trong dấu [ ] ở trang bìa.",
        "Cập nhật mục lục tự động bằng Ctrl+A/Command+A và F9.",
        "Bổ sung ảnh chụp màn hình thực tế nếu khoa yêu cầu minh họa giao diện.",
        "Điều chỉnh tên đề tài, tên sản phẩm hoặc thuật ngữ theo phiếu giao đề tài chính thức.",
        "Kiểm tra lại quy định riêng của trường về lề, đánh số trang, bìa phụ và nhận xét giảng viên.",
        "Chạy lại flutter test và npm test; cập nhật bảng kết quả nếu mã nguồn thay đổi.",
        "Xóa hoặc thay các ghi chú nội bộ không cần thiết trước khi in/nộp.",
    ])


def finalize_document(doc):
    configure_sections(doc)
    settings = doc.settings._element
    update = settings.find(qn("w:updateFields"))
    if update is None:
        update = OxmlElement("w:updateFields")
        settings.append(update)
    update.set(qn("w:val"), "true")

    core = doc.core_properties
    core.title = "Báo cáo đồ án cơ sở - ComZone"
    core.subject = "Ứng dụng mua bán, trao đổi và đấu giá truyện tranh bằng Flutter và Firebase"
    core.author = "[HỌ VÀ TÊN SINH VIÊN]"
    core.keywords = "Flutter, Firebase, ComZone, đồ án cơ sở, truyện tranh"

    for section in doc.sections:
        footer = section.footer
        p = footer.paragraphs[0]
        p.text = ""
        add_page_number(p)
        header = section.header
        hp = header.paragraphs[0]
        hp.text = ""
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        hp.paragraph_format.space_after = Pt(0)
        set_run_font(hp.add_run("BÁO CÁO ĐỒ ÁN CƠ SỞ – COMZONE"), 10, italic=True, color=MID_GRAY)

    first_section = doc.sections[0]
    first_section.different_first_page_header_footer = True
    first_section.first_page_header.paragraphs[0].text = ""
    first_section.first_page_footer.paragraphs[0].text = ""


def build():
    OUT_DIR.mkdir(exist_ok=True)
    ASSET_DIR.mkdir(exist_ok=True)
    make_architecture(ASSET_DIR / "architecture.png")
    make_actor_map(ASSET_DIR / "actor_map.png")
    make_order_flow(ASSET_DIR / "order_flow.png")
    make_auction_flow(ASSET_DIR / "auction_flow.png")

    doc = Document()
    configure_styles(doc)
    configure_sections(doc)
    add_cover(doc)
    add_front_matter(doc)
    chapter_1(doc)
    chapter_2(doc)
    chapter_3(doc)
    chapter_4(doc)
    chapter_5(doc)
    chapter_6(doc)
    conclusion(doc)
    references(doc)
    appendices(doc)
    finalize_document(doc)
    doc.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    build()
