import csv
import io
from django.http import HttpResponse
from django.db.models import Sum, Count
from django.utils import timezone
from datetime import timedelta
from rest_framework.views import APIView
from rest_framework.response import Response

from transactions.models import Transaction, CCBillPayment


def _csv_response(headers, rows, summary_row, filename):
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(headers)
    writer.writerows(rows)
    if summary_row:
        writer.writerow([])
        writer.writerow(summary_row)
    response = HttpResponse(buffer.getvalue().encode("utf-8-sig"), content_type="text/csv")
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response


def _pdf_response(title, headers, rows, summary_row, filename, shop_name):
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4, landscape
    from reportlab.lib.units import inch
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import LongTable, Paragraph, SimpleDocTemplate, Spacer, TableStyle

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer, pagesize=landscape(A4),
        topMargin=0.4 * inch, bottomMargin=0.4 * inch,
        leftMargin=0.4 * inch, rightMargin=0.4 * inch,
    )
    styles = getSampleStyleSheet()
    elements = [
        Paragraph(f"<b>DigiLedger - {shop_name}</b>", styles["Title"]),
        Paragraph(title, styles["Heading2"]),
        Spacer(1, 10),
    ]

    def _cell(value):
        if value is None:
            return ""
        return str(value)

    data = [[_cell(h) for h in headers]]
    data.extend([[_cell(v) for v in row] for row in rows])
    if summary_row:
        data.append([_cell(v) for v in summary_row])

    table = LongTable(data, repeatRows=1)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1E3A5F")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 7),
        ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8F9FA")]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    elements.append(table)
    doc.build(elements)
    buffer.seek(0)

    response = HttpResponse(buffer.getvalue(), content_type="application/pdf")
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response


class ExportTransactionsExcelView(APIView):
    def get(self, request):
        shop = request.user.shop
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")
        category = request.query_params.get("category")
        payment_method = request.query_params.get("payment_method")
        fmt = (request.query_params.get("format") or "excel").lower()

        qs = Transaction.objects.filter(shop=shop)
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        if category:
            qs = qs.filter(category_id=category)
        if payment_method:
            qs = qs.filter(payment_method=payment_method)
        qs = qs.order_by("-date")

        headers = ["Date", "Description", "Category", "Payment Method", "Reference", "Amount", "Charges", "Profit", "Customer", "Phone", "Remarks"]
        rows = [
            [
                str(txn.date),
                txn.description,
                txn.category.name if txn.category else "",
                txn.get_payment_method_display(),
                txn.transaction_ref,
                float(txn.debit_amount),
                float(txn.charges),
                float(txn.profit),
                txn.customer_name,
                txn.customer_phone,
                txn.remarks,
            ]
            for txn in qs
        ]

        summary = qs.aggregate(
            total_amount=Sum("debit_amount"),
            total_charges=Sum("charges"),
            total_profit=Sum("profit"),
            total_count=Count("id"),
        )
        summary_row = ["TOTAL", f"{summary['total_count']} transactions", "", "", "", summary["total_amount"], summary["total_charges"], summary["total_profit"]]
        stamp = timezone.now().strftime("%Y%m%d_%H%M%S")

        if fmt == "csv":
            return _csv_response(headers, rows, summary_row, f"transactions_{shop.name}_{stamp}.csv")
        if fmt == "pdf":
            return _pdf_response("Transactions Export", headers, rows, summary_row, f"transactions_{shop.name}_{stamp}.pdf", shop.name)

        import openpyxl
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Transactions"

        ws.append(headers)
        for row in rows:
            ws.append(row)

        ws.append([])
        ws.append(summary_row)

        buffer = io.BytesIO()
        wb.save(buffer)
        buffer.seek(0)

        response = HttpResponse(buffer.getvalue(), content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        filename = f"transactions_{shop.name}_{stamp}.xlsx"
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


class ExportCCBillsExcelView(APIView):
    def get(self, request):
        shop = request.user.shop
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")
        bank_name = request.query_params.get("bank_name")

        qs = CCBillPayment.objects.filter(shop=shop)
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        if bank_name:
            qs = qs.filter(bank_name=bank_name)
        qs = qs.order_by("-date")

        import openpyxl
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "CC Bill Payments"

        headers = ["Date", "Customer", "Phone", "Bank", "Card Last 4", "Bill Amount", "Amount Paid", "Charges", "Profit", "Payment Method", "Reference", "Due Date", "Remarks"]
        ws.append(headers)

        for bill in qs:
            ws.append([
                str(bill.date),
                bill.customer_name,
                bill.customer_phone,
                bill.get_bank_name_display(),
                bill.card_last_4,
                float(bill.bill_amount),
                float(bill.amount_paid),
                float(bill.service_charges),
                float(bill.profit),
                bill.get_payment_method_display(),
                bill.transaction_ref,
                str(bill.due_date) if bill.due_date else "",
                bill.remarks,
            ])

        ws.append([])
        summary = qs.aggregate(
            total_bill=Sum("bill_amount"),
            total_paid=Sum("amount_paid"),
            total_charges=Sum("service_charges"),
            total_profit=Sum("profit"),
            total_count=Count("id"),
        )
        ws.append(["TOTAL", f"{summary['total_count']} payments", "", "", "", summary["total_bill"], summary["total_paid"], summary["total_charges"], summary["total_profit"]])

        buffer = io.BytesIO()
        wb.save(buffer)
        buffer.seek(0)

        response = HttpResponse(buffer.getvalue(), content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        filename = f"cc_bills_{shop.name}_{timezone.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


class ExportReportExcelView(APIView):
    def get(self, request):
        shop = request.user.shop
        report_type = request.query_params.get("type", "monthly")
        year = request.query_params.get("year", str(timezone.now().year))
        fmt = (request.query_params.get("format") or "excel").lower()

        from django.db.models.functions import TruncDate, TruncMonth

        if report_type == "daily":
            date_from = request.query_params.get("date_from", str(timezone.now().date() - timedelta(days=30)))
            date_to = request.query_params.get("date_to", str(timezone.now().date()))
            data = (
                Transaction.objects.filter(shop=shop, date__gte=date_from, date__lte=date_to)
                .annotate(day=TruncDate("date")).values("day")
                .annotate(transactions=Count("id"), revenue=Sum("debit_amount"), profit=Sum("profit"))
                .order_by("day")
            )
            headers = ["Date", "Transactions", "Revenue", "Profit"]
        elif report_type == "quarterly":
            start = timezone.now().date() - timedelta(days=89)
            data = (
                Transaction.objects.filter(shop=shop, date__gte=start)
                .annotate(month=TruncMonth("date")).values("month")
                .annotate(transactions=Count("id"), revenue=Sum("debit_amount"), profit=Sum("profit"))
                .order_by("month")
            )
            headers = ["Quarter", "Transactions", "Revenue", "Profit"]
        elif report_type == "yearly":
            data = (
                Transaction.objects.filter(shop=shop, date__year=year)
                .annotate(month=TruncMonth("date")).values("month")
                .annotate(transactions=Count("id"), revenue=Sum("debit_amount"), profit=Sum("profit"))
                .order_by("month")
            )
            headers = ["Month", "Transactions", "Revenue", "Profit"]
        else:  # monthly
            data = (
                Transaction.objects.filter(shop=shop, date__year=year)
                .annotate(month=TruncMonth("date")).values("month")
                .annotate(transactions=Count("id"), revenue=Sum("debit_amount"), profit=Sum("profit"))
                .order_by("month")
            )
            headers = ["Month", "Transactions", "Revenue", "Profit"]

        rows = [
            [
                str(item.get("day") or item.get("month") or ""),
                item["transactions"],
                float(item["revenue"] or 0),
                float(item["profit"] or 0),
            ]
            for item in data
        ]
        total_count = sum(item["transactions"] for item in data)
        total_rev = sum(float(item["revenue"] or 0) for item in data)
        total_profit = sum(float(item["profit"] or 0) for item in data)
        summary_row = ["TOTAL", total_count, total_rev, total_profit]
        stamp = timezone.now().strftime("%Y%m%d_%H%M%S")
        base = f"{report_type}_report_{shop.name}_{stamp}"

        if fmt == "csv":
            return _csv_response(headers, rows, summary_row, f"{base}.csv")
        if fmt == "pdf":
            return _pdf_response(f"{report_type.title()} Report", headers, rows, summary_row, f"{base}.pdf", shop.name)

        import openpyxl
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = f"{report_type.title()} Report"
        ws.append(headers)

        for row in rows:
            ws.append(row)

        ws.append([])
        ws.append(summary_row)

        buffer = io.BytesIO()
        wb.save(buffer)
        buffer.seek(0)

        response = HttpResponse(buffer.getvalue(), content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        filename = f"{base}.xlsx"
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response


class ExportDashboardPDFView(APIView):
    def get(self, request):
        shop = request.user.shop
        today = timezone.now().date()
        month_start = today.replace(day=1)
        fmt = request.query_params.get('format', 'pdf')

        today_txn = Transaction.objects.filter(shop=shop, date=today)
        month_txn = Transaction.objects.filter(shop=shop, date__gte=month_start, date__lte=today)

        from reportlab.lib.pagesizes import A4
        from reportlab.lib import colors
        from reportlab.lib.units import inch
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=0.5 * inch, bottomMargin=0.5 * inch)
        styles = getSampleStyleSheet()
        elements = []

        # Title
        elements.append(Paragraph(f"<b>DigiLedger - {shop.name}</b>", styles["Title"]))
        elements.append(Spacer(1, 12))
        elements.append(Paragraph(f"Dashboard Report - {today.strftime('%B %d, %Y')}", styles["Heading2"]))
        elements.append(Spacer(1, 20))

        # Today summary
        today_rev = today_txn.aggregate(total=Sum("debit_amount"))["total"] or 0
        today_profit = today_txn.aggregate(total=Sum("profit"))["total"] or 0
        today_count = today_txn.count()

        month_rev = month_txn.aggregate(total=Sum("debit_amount"))["total"] or 0
        month_profit = month_txn.aggregate(total=Sum("profit"))["total"] or 0
        month_count = month_txn.count()

        summary_data = [
            ["Metric", "Today", "This Month"],
            ["Transactions", str(today_count), str(month_count)],
            ["Revenue", f"Rs.{today_rev}", f"Rs.{month_rev}"],
            ["Profit", f"Rs.{today_profit}", f"Rs.{month_profit}"],
        ]

        table = Table(summary_data, colWidths=[2.5 * inch, 2 * inch, 2 * inch])
        table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1E3A5F")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("ALIGN", (0, 0), (-1, -1), "CENTER"),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 11),
            ("BOTTOMPADDING", (0, 0), (-1, 0), 12),
            ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F8F9FA")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ]))
        elements.append(table)
        elements.append(Spacer(1, 30))

        # Recent transactions
        elements.append(Paragraph("<b>Recent Transactions</b>", styles["Heading2"]))
        elements.append(Spacer(1, 10))

        txn_data = [["Date", "Description", "Category", "Amount", "Profit"]]
        for txn in Transaction.objects.filter(shop=shop)[:20]:
            txn_data.append([
                str(txn.date),
                txn.description[:30],
                txn.category.name if txn.category else "",
                f"Rs.{txn.debit_amount}",
                f"Rs.{txn.profit}",
            ])

        if len(txn_data) > 1:
            txn_table = Table(txn_data, colWidths=[1.2 * inch, 2.2 * inch, 1.3 * inch, 1 * inch, 1 * inch])
            txn_table.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1E3A5F")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 10),
                ("BACKGROUND", (0, 1), (-1, -1), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8F9FA")]),
            ]))
            elements.append(txn_table)
        else:
            elements.append(Paragraph("No transactions yet.", styles["Normal"]))

        doc.build(elements)
        buffer.seek(0)

        if fmt == 'excel':
            return self._export_excel(shop, today, today_txn, month_txn, today_rev, today_profit, today_count, month_rev, month_profit, month_count)

        response = HttpResponse(buffer.getvalue(), content_type="application/pdf")
        filename = f"dashboard_{shop.name}_{today.strftime('%Y%m%d')}.pdf"
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response

    def _export_excel(self, shop, today, today_txn, month_txn, today_rev, today_profit, today_count, month_rev, month_profit, month_count):
        import openpyxl
        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Dashboard Summary"

        header_font = Font(bold=True, color="FFFFFF", size=12)
        header_fill = PatternFill(start_color="1E3A5F", end_color="1E3A5F", fill_type="solid")
        thin_border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin'),
        )

        ws.merge_cells('A1:C1')
        ws['A1'] = f'DigiLedger - {shop.name}'
        ws['A1'].font = Font(bold=True, size=14)
        ws.merge_cells('A2:C2')
        ws['A2'] = f'Dashboard Report - {today.strftime("%B %d, %Y")}'
        ws['A2'].font = Font(size=11, italic=True)

        for col, header in enumerate(['Metric', 'Today', 'This Month'], 1):
            cell = ws.cell(row=4, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal='center')
            cell.border = thin_border

        data_rows = [
            ('Transactions', today_count, month_count),
            ('Revenue', f'Rs.{today_rev}', f'Rs.{month_rev}'),
            ('Profit', f'Rs.{today_profit}', f'Rs.{month_profit}'),
        ]
        for r, (metric, today_val, month_val) in enumerate(data_rows, 5):
            ws.cell(row=r, column=1, value=metric).border = thin_border
            ws.cell(row=r, column=2, value=str(today_val)).border = thin_border
            ws.cell(row=r, column=2).alignment = Alignment(horizontal='center')
            ws.cell(row=r, column=3, value=str(month_val)).border = thin_border
            ws.cell(row=r, column=3).alignment = Alignment(horizontal='center')

        ws.column_dimensions['A'].width = 18
        ws.column_dimensions['B'].width = 15
        ws.column_dimensions['C'].width = 15

        ws2 = wb.create_sheet("Recent Transactions")
        txn_headers = ['Date', 'Description', 'Category', 'Amount', 'Profit']
        for col, header in enumerate(txn_headers, 1):
            cell = ws2.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal='center')
            cell.border = thin_border

        for r, txn in enumerate(Transaction.objects.filter(shop=shop)[:20], 2):
            ws2.cell(row=r, column=1, value=str(txn.date)).border = thin_border
            ws2.cell(row=r, column=2, value=txn.description[:50]).border = thin_border
            ws2.cell(row=r, column=3, value=txn.category.name if txn.category else '').border = thin_border
            ws2.cell(row=r, column=4, value=f'Rs.{txn.debit_amount}').border = thin_border
            ws2.cell(row=r, column=5, value=f'Rs.{txn.profit}').border = thin_border

        ws2.column_dimensions['A'].width = 14
        ws2.column_dimensions['B'].width = 30
        ws2.column_dimensions['C'].width = 15
        ws2.column_dimensions['D'].width = 12
        ws2.column_dimensions['E'].width = 12

        buffer = io.BytesIO()
        wb.save(buffer)
        buffer.seek(0)

        response = HttpResponse(buffer.getvalue(), content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        filename = f"dashboard_{shop.name}_{today.strftime('%Y%m%d')}.xlsx"
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response
