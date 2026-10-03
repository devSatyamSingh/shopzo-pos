import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../model/recipt_model.dart';
import '../utils/format_utils.dart';

String _rs(num v) => FormatUtils.inr(v, decimals: true).replaceAll('₹', 'Rs.');

String _pretty(String raw) {
  final String t = raw.trim();
  if (t.length <= 3) return t.toUpperCase();
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

Future<Uint8List> buildReceiptPdf(Receipt r) async {
  final pw.Document doc = pw.Document();
  final pw.TextStyle base = pw.TextStyle(font: pw.Font.courier(), fontSize: 9);
  final pw.TextStyle bold =
  pw.TextStyle(font: pw.Font.courierBold(), fontSize: 9);
  final pw.TextStyle small = base.copyWith(fontSize: 8);

  pw.Widget row(String l, String v, {pw.TextStyle? style}) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Expanded(child: pw.Text(l, style: style ?? base)),
      pw.SizedBox(width: 6),
      pw.Text(v, style: style ?? base),
    ],
  );

  pw.Widget dash() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Divider(
      height: 1,
      thickness: 0.6,
      borderStyle: pw.BorderStyle.dashed,
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.fromLTRB(10, 12, 10, 16),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            pw.Center(
              child: pw.Text(
                r.businessName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: bold.copyWith(fontSize: 13),
              ),
            ),
            if (r.address.isNotEmpty)
              pw.Center(child: pw.Text(r.address, style: small, textAlign: pw.TextAlign.center)),
            if (r.phone.isNotEmpty)
              pw.Center(child: pw.Text('Ph: ${r.phone}', style: small)),
            if (r.email.isNotEmpty)
              pw.Center(child: pw.Text(r.email, style: small)),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('SALES RECEIPT', style: bold)),
            dash(),
            row('Order', r.orderNumber, style: bold),
            row('Date', FormatUtils.date(r.createdAt)),
            row('Time', FormatUtils.time(r.createdAt)),
            if (r.cashierName.isNotEmpty) row('Cashier', r.cashierName),
            if (r.hasCustomer) ...<pw.Widget>[
              if ((r.customerName ?? '').isNotEmpty) row('Customer', r.customerName!),
              if ((r.customerPhone ?? '').isNotEmpty) row('Phone', r.customerPhone!),
            ],
            dash(),
            row('ITEM', 'AMOUNT', style: bold),
            pw.SizedBox(height: 2),
            for (final ReceiptItem i in r.items) ...<pw.Widget>[
              pw.Text(i.productName, style: bold),
              row('${i.quantity} x ${_rs(i.price)}', _rs(i.lineTotal)),
              if (i.taxAmount > 0) pw.Text('  Tax ${_rs(i.taxAmount)}', style: small),
              pw.SizedBox(height: 3),
            ],
            dash(),
            row('Subtotal', _rs(r.subtotal)),
            if (r.discount > 0) row('Discount', '-${_rs(r.discount)}'),
            if (r.tax > 0) row('Tax', _rs(r.tax)),
            pw.SizedBox(height: 2),
            row('TOTAL', _rs(r.total), style: bold.copyWith(fontSize: 12)),
            dash(),
            if (r.payments.isNotEmpty) ...<pw.Widget>[
              pw.Text('PAID BY', style: bold),
              for (final ReceiptPayment p in r.payments)
                row(_pretty(p.method), _rs(p.amount)),
              dash(),
            ],
            pw.Center(child: pw.Text('Items: ${r.items.length}   Qty: ${r.totalQty}', style: small)),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: r.orderNumber.isEmpty ? r.orderId : r.orderNumber,
                width: 150,
                height: 36,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(r.orderNumber, style: small)),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('Thank you for shopping with us!', style: bold)),
            pw.Center(child: pw.Text('Please visit again.', style: small)),
          ],
        );
      },
    ),
  );

  return doc.save();
}