import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopzo_pos/viewmodel/billing_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/dashboard_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/held_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/product_viewmodel.dart';
import 'package:shopzo_pos/viewmodel/shift_viewmodel.dart';
import '../../viewmodel/access_viewmodel.dart';
import '../../viewmodel/customer_viewmodel.dart';
import '../../viewmodel/pos_history_viewmodel.dart';

void resetSessionProviders(ProviderContainer c) {
  Future<void>.delayed(const Duration(milliseconds: 700), () {
    c.invalidate(dashboardViewModelProvider);
    c.invalidate(productViewModelProvider);
    c.invalidate(posProductsProvider);
    c.invalidate(customerSearchProvider);
    c.invalidate(billingViewModelProvider);
    c.invalidate(heldViewModelProvider);
    c.invalidate(orderHistoryViewModelProvider);
    c.invalidate(shiftViewModelProvider);
    c.invalidate(accessViewModelProvider);
  });
}