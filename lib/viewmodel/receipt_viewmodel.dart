import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/failure.dart';
import '../model/recipt_model.dart';
import '../repo/billing_repo.dart';

final receiptProvider = FutureProvider.autoDispose.family<Receipt, String>((
  Ref ref,
  String orderId,
) async {
  final ApiResult<Receipt> result = await ref
      .read(billingRepoProvider)
      .getReceipt(orderId);

  final Receipt? data = result.dataOrNull;
  if (data != null) return data;
  throw result.failureOrNull!;
});
