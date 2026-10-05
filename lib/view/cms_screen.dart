import 'package:flutter/material.dart';
import 'package:shopzo_pos/utils/responsive.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_text.dart';

class CmsPage extends StatelessWidget {
  const CmsPage({super.key, required this.title, required this.slug});

  final String title;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

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
                    padding: EdgeInsets.all(m ? 16 : 24),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.border),
                    ),
                    // TODO: yahan API se slug ($slug) ka content fetch karke
                    // render karo (HTML ho to flutter_html / flutter_widget_from_html).
                    child: SingleChildScrollView(
                      child: AppText.body(
                        '$title content yahan aayega.',
                        secondary: true,
                      ),
                    ),
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