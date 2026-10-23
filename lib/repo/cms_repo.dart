import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../api/api_urls.dart';
import '../core/errors/failure.dart';
import '../model/cms_model.dart';

class CmsRepo {
  const CmsRepo(this._api);

  final ApiService _api;

  Future<ApiResult<CmsPageModel>> getPage(
      CmsPageType type, {
        CancelToken? cancelToken,
      }) {
    return _api.get<CmsPageModel>(
      ApiUrls.posPageByType(type.api),
      cancelToken: cancelToken,
      parser: (dynamic data) => data is Map
          ? CmsPageModel.fromJson(Map<String, dynamic>.from(data))
          : CmsPageModel(
        id: '',
        type: type.api,
        title: type.title,
        content: '',
      ),
    );
  }
}

final Provider<CmsRepo> cmsRepoProvider = Provider<CmsRepo>(
      (Ref ref) => CmsRepo(ref.watch(apiServiceProvider)),
);