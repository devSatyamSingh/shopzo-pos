import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/failure.dart';
import '../model/cms_model.dart';
import '../repo/cms_repo.dart';

@immutable
class CmsState {
  const CmsState({this.isLoading = true, this.page, this.failure});

  final bool isLoading;
  final CmsPageModel? page;
  final Failure? failure;
}

/// Ek page type ka content. Screen band hote hi state saaf (autoDispose).
class CmsViewModel extends Notifier<CmsState> {
  CmsViewModel(this.type);

  final CmsPageType type;
  CancelToken _cancel = CancelToken();

  @override
  CmsState build() {
    final CancelToken token = CancelToken();
    _cancel = token;
    ref.onDispose(() => token.cancel('disposed'));
    Future<void>.microtask(load);
    return const CmsState();
  }

  Future<void> load() async {
    final CancelToken token = _cancel;
    state = const CmsState(isLoading: true);

    final ApiResult<CmsPageModel> result =
    await ref.read(cmsRepoProvider).getPage(type, cancelToken: token);
    if (!ref.mounted || token.isCancelled) return;

    final CmsPageModel? page = result.dataOrNull;
    state = page != null
        ? CmsState(isLoading: false, page: page)
        : CmsState(isLoading: false, failure: result.failureOrNull);
  }
}

final cmsViewModelProvider = NotifierProvider.autoDispose
    .family<CmsViewModel, CmsState, CmsPageType>(CmsViewModel.new);