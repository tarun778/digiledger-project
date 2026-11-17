from django.http import HttpResponse
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from .models import Invoice


def generate_invoice_pdf(invoice_id):
    try:
        invoice = Invoice.objects.select_related("shop").get(id=invoice_id)
    except Invoice.DoesNotExist:
        return None

    response = HttpResponse(content_type="application/pdf")
    response["Content-Disposition"] = f'attachment; filename="invoice_{invoice.invoice_number}.pdf"'

    doc = SimpleDocTemplate(response, pagesize=A4, topMargin=0.5 * inch, bottomMargin=0.5 * inch)
    styles = getSampleStyleSheet()
    elements = []

    # Header
    elements.append(Paragraph("DigiLedger", styles["Title"]))
    elements.append(Paragraph("Invoice", styles["Heading2"]))
    elements.append(Spacer(1, 12))

    # Invoice details
    data = [
        ["Invoice Number:", invoice.invoice_number],
        ["Date:", invoice.created_at.strftime("%d %b %Y")],
        ["Status:", invoice.status.upper()],
    ]
    table = Table(data, colWidths=[150, 350])
    table.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    elements.append(table)
    elements.append(Spacer(1, 20))

    # Shop details
    elements.append(Paragraph("Bill To:", styles["Heading3"]))
    shop_data = [
        ["Shop:", invoice.shop.name],
        ["Owner:", invoice.shop.owner_name],
        ["Phone:", invoice.shop.phone],
        ["Email:", invoice.shop.email or "N/A"],
        ["Address:", f"{invoice.shop.address or ''}, {invoice.shop.city or ''}, {invoice.shop.state or ''} {invoice.shop.pincode or ''}"],
    ]
    shop_table = Table(shop_data, colWidths=[150, 350])
    shop_table.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    elements.append(shop_table)
    elements.append(Spacer(1, 20))

    # Billing table
    billing_data = [
        ["Description", "Plan", "Amount"],
        [f"{invoice.plan.title()} Plan", invoice.plan.title(), f"Rs. {invoice.amount}"],
        ["Tax (18%)", "", f"Rs. {invoice.tax}"],
        ["Total", "", f"Rs. {invoice.total_amount}"],
    ]
    billing_table = Table(billing_data, colWidths=[200, 150, 150])
    billing_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2196F3")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("ALIGN", (2, 0), (2, -1), "RIGHT"),
        ("GRID", (0, 0), (-1, -1), 1, colors.grey),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#E3F2FD")),
        ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
    ]))
    elements.append(billing_table)
    elements.append(Spacer(1, 20))

    # Period
    period_data = [
        ["Billing Period:", f"{invoice.billing_period_start.strftime('%d %b %Y')} to {invoice.billing_period_end.strftime('%d %b %Y')}"],
    ]
    period_table = Table(period_data, colWidths=[150, 350])
    period_table.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
    ]))
    elements.append(period_table)

    if invoice.notes:
        elements.append(Spacer(1, 12))
        elements.append(Paragraph(f"Notes: {invoice.notes}", styles["Normal"]))

    elements.append(Spacer(1, 30))
    elements.append(Paragraph("Thank you for your business!", styles["Normal"]))
    elements.append(Paragraph("DigiLedger - Digital Ledger for Shop Management", styles["Normal"]))

    doc.build(elements)
    return response
