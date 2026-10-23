import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:shopzo_pos/utils/format_utils.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/viewmodel/cms_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_shimmer.dart';
import 'package:shopzo_pos/widget/app_text.dart';

import '../model/cms_model.dart';

class CmsPage extends ConsumerWidget {
  const CmsPage({super.key, required this.type});

  final CmsPageType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final CmsState s = ref.watch(cmsViewModelProvider(type));
    final String title = (s.page?.title.isNotEmpty ?? false)
        ? s.page!.title
        : type.title;

    Widget body;
    if (s.isLoading) {
      body = const _CmsSkeleton();
    } else if (s.page == null) {
      body = AppErrorView(
        failure: s.failure!,
        onRetry: () => ref.read(cmsViewModelProvider(type).notifier).load(),
      );
    } else if (!s.page!.hasContent) {
      body = const Center(
        child: AppText.body('Nothing to show yet.', secondary: true),
      );
    } else {
      final CmsPageModel page = s.page!;
      body = RefreshIndicator(
        onRefresh: () => ref.read(cmsViewModelProvider(type).notifier).load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HtmlWidget(
                page.content,
                textStyle: TextStyle(
                  fontSize: m ? 14 : 15,
                  height: 1.55,
                  color: palette.textPrimary,
                ),
              ),
              if (page.updatedAt != null) ...<Widget>[
                const SizedBox(height: 20),
                AppText.caption(
                  'Last updated ${FormatUtils.dateTime(page.updatedAt)}',
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m ? 16 : 32, vertical: 10),
          child: ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: AppText.h2(title, maxLines: 1)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(m ? 16 : 24),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.border),
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CmsSkeleton extends StatelessWidget {
  const _CmsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShimmerBone(width: 180, height: 20),
          SizedBox(height: 16),
          ShimmerBone(height: 12),
          SizedBox(height: 8),
          ShimmerBone(height: 12),
          SizedBox(height: 8),
          ShimmerBone(width: 240, height: 12),
          SizedBox(height: 22),
          ShimmerBone(width: 140, height: 16),
          SizedBox(height: 12),
          ShimmerBone(height: 12),
          SizedBox(height: 8),
          ShimmerBone(height: 12),
        ],
      ),
    );
  }
}