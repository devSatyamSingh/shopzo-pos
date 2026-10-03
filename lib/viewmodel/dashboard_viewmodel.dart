import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopzo_pos/core/errors/failure.dart';
import 'package:shopzo_pos/model/dashboard_model.dart';
import 'package:shopzo_pos/utils/app_utils.dart';

import '../repo/dashbaord_repo.dart';

class DateRange {
  const DateRange(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

enum DashboardPeriod {
  today('Today', 'vs yesterday'),
  last7('7 Days', 'vs previous 7 days'),
  last30('30 Days', 'vs previous 30 days'),
  thisMonth('This Month', 'vs last month');

  const DashboardPeriod(this.label, this.compareLabel);

  final String label;
  final String compareLabel;

  /// Sparkline mein maximum kitne points.
  static const int maxTrendPoints = 8;

  static DateTime _day(DateTime base, int offset) =>
      DateTime(base.year, base.month, base.day + offset);

  DateRange current([DateTime? now]) {
    final DateTime t = _day(now ?? DateTime.now(), 0);
    switch (this) {
      case DashboardPeriod.today:
        return DateRange(t, t);
      case DashboardPeriod.last7:
        return DateRange(_day(t, -6), t);
      case DashboardPeriod.last30:
        return DateRange(_day(t, -29), t);
      case DashboardPeriod.thisMonth:
        return DateRange(DateTime(t.year, t.month, 1), t);
    }
  }

  DateRange previous([DateTime? now]) {
    final DateTime t = _day(now ?? DateTime.now(), 0);
    switch (this) {
      case DashboardPeriod.today:
        return DateRange(_day(t, -1), _day(t, -1));
      case DashboardPeriod.last7:
        return DateRange(_day(t, -13), _day(t, -7));
      case DashboardPeriod.last30:
        return DateRange(_day(t, -59), _day(t, -30));
      case DashboardPeriod.thisMonth:
        return DateRange(
          DateTime(t.year, t.month - 1, 1),
          DateTime(t.year, t.month, 0),
        );
    }
  }

  List<DateRange> trendBuckets([DateTime? now]) {
    final DateRange r = this == DashboardPeriod.today
        ? DashboardPeriod.last7.current(now)
        : current(now);
    final int days = DateTime.utc(r.to.year, r.to.month, r.to.day)
        .difference(DateTime.utc(r.from.year, r.from.month, r.from.day))
        .inDays +
        1;
    final int count = days < maxTrendPoints ? days : maxTrendPoints;

    return <DateRange>[
      for (int i = 0; i < count; i++)
        DateRange(
          _day(r.from, (i * days / count).floor()),
          _day(r.from, ((i + 1) * days / count).floor() - 1),
        ),
    ];
  }
}

class DashboardState {
  const DashboardState({
    this.period = DashboardPeriod.last30,
    this.report,
    this.previous,
    this.trend,
    this.isLoading = true,
    this.failure,
  });

  final DashboardPeriod period;
  final DailySalesReport? report;

  /// Pichhli period ka report (sirf growth % ke liye). Fail ho to null.
  final DailySalesReport? previous;

  /// Sparkline ke net sales points. Report ke baad alag se aata hai,
  /// tab tak null (chart nahi dikhta).
  final List<double>? trend;

  final bool isLoading;
  final Failure? failure;

  /// Net sales growth in %. Compare na ho paye to null (badge nahi dikhega).
  double? get growth {
    final DailySalesReport? cur = report;
    final DailySalesReport? prev = previous;
    if (cur == null || prev == null || prev.netSales <= 0) return null;
    return (cur.netSales - prev.netSales) / prev.netSales * 100;
  }

  DashboardState copyWith({
    DashboardPeriod? period,
    DailySalesReport? report,
    bool clearReport = false,
    DailySalesReport? previous,
    bool clearPrevious = false,
    List<double>? trend,
    bool clearTrend = false,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return DashboardState(
      period: period ?? this.period,
      report: clearReport ? null : (report ?? this.report),
      previous: clearPrevious ? null : (previous ?? this.previous),
      trend: clearTrend ? null : (trend ?? this.trend),
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class DashboardViewModel extends Notifier<DashboardState> {
  int _requestId = 0;

  @override
  DashboardState build() {
    Future<void>.microtask(() => load());
    return const DashboardState();
  }

  Future<void> setPeriod(DashboardPeriod period) async {
    if (period == state.period) return;
    state = state.copyWith(period: period);
    await load();
  }

  Future<void> load({bool refresh = false}) async {
    final int id = ++_requestId;
    final DashboardPeriod period = state.period;

    if (!refresh) {
      state = state.copyWith(
        isLoading: true,
        clearFailure: true,
        clearReport: true,
        clearPrevious: true,
        clearTrend: true,
      );
    }

    final DashboardRepository repo = ref.read(dashboardRepositoryProvider);
    final DateRange cur = period.current();
    final DateRange prev = period.previous();
    final List<ApiResult<DailySalesReport>> results =
    await Future.wait<ApiResult<DailySalesReport>>(
      <Future<ApiResult<DailySalesReport>>>[
        repo.getDailySales(from: cur.from, to: cur.to),
        repo.getDailySales(from: prev.from, to: prev.to),
      ],
    );
    if (!ref.mounted || id != _requestId) return;
    final DailySalesReport? report = results[0].dataOrNull;
    final DailySalesReport? previous = results[1].dataOrNull;
    if (report != null) {
      state = state.copyWith(
        isLoading: false,
        report: report,
        previous: previous,
        clearPrevious: previous == null,
        clearFailure: true,
      );
      // Chart baad mein bharta hai, dashboard ko rokta nahi.
      unawaited(_loadTrend(id, period));
      return;
    }

    final Failure failure = results[0].failureOrNull!;
    if (state.report != null) {
      // Refresh fail hua par purana data hai: bubble dikhao, screen mat todo.
      AppUtils.showFailure(failure);
      state = state.copyWith(isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<void> _loadTrend(int id, DashboardPeriod period) async {
    final List<DateRange> buckets = period.trendBuckets();
    if (buckets.length < 2) return;

    final DashboardRepository repo = ref.read(dashboardRepositoryProvider);
    final List<ApiResult<DailySalesReport>> results =
    await Future.wait<ApiResult<DailySalesReport>>(
      <Future<ApiResult<DailySalesReport>>>[
        for (final DateRange b in buckets)
          repo.getDailySales(from: b.from, to: b.to),
      ],
    );

    if (!ref.mounted || id != _requestId) return;
    if (!results.any((ApiResult<DailySalesReport> r) => r.isSuccess)) return;
    state = state.copyWith(
      trend: <double>[
        for (final ApiResult<DailySalesReport> r in results)
          r.dataOrNull?.netSales ?? 0,
      ],
    );
  }
}

final NotifierProvider<DashboardViewModel, DashboardState>
dashboardViewModelProvider =
NotifierProvider<DashboardViewModel, DashboardState>(
  DashboardViewModel.new,
);