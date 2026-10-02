import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shopzo_pos/model/product_model.dart';
import 'package:shopzo_pos/viewmodel/product_viewmodel.dart';
import 'package:shopzo_pos/widget/app_button.dart';
import 'package:shopzo_pos/widget/app_colors.dart';
import 'package:shopzo_pos/widget/app_dimens.dart';
// ⚠️ File ka naam apne project ke hisaab se check kar lena.
import 'package:shopzo_pos/widget/app_error_view.dart';
import 'package:shopzo_pos/widget/app_textstyle.dart';
import '../../utils/responsive.dart';
import '../../widget/app_textfield.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

/// 285 -> ₹285 , 145.5 -> ₹145.50 , 124500 -> ₹1,24,500
String _inr(double value) {
  final bool whole = value % 1 == 0;
  final List<String> parts = value.toStringAsFixed(whole ? 0 : 2).split('.');
  String digits = parts[0];
  if (digits.length > 3) {
    final String last3 = digits.substring(digits.length - 3);
    final String rest = digits
        .substring(0, digits.length - 3)
        .replaceAllMapped(RegExp(r'(\d+?)(?=(\d{2})+$)'), (Match m) => '${m[1]},');
    digits = '$rest,$last3';
  }
  return '₹$digits${parts.length > 1 ? '.${parts[1]}' : ''}';
}

const Color _amberText = Color(0xFFE08A00);

const List<List<Color>> _avatarColors = <List<Color>>[
  <Color>[AppColors.primarySoft, AppColors.primary],
  <Color>[AppColors.skySoft, Color(0xFF0E9FC4)],
  <Color>[AppColors.mintSoft, AppColors.mintDark],
  <Color>[AppColors.amberSoft, _amberText],
  <Color>[AppColors.coralSoft, AppColors.coral],
];

/// Mobile pe chhota, tablet pe thoda bada text. Color automatic (light/dark).
class _Txt extends StatelessWidget {
  const _Txt(
      this.text,
      this.base, {
        required this.m,
        this.t,
        this.color,
        this.secondary = false,
        this.weight,
        this.maxLines,
        this.align,
        this.tabular = false,
      });

  final String text;
  final TextStyle base;
  final double m;
  final double? t;
  final Color? color;
  final bool secondary;
  final FontWeight? weight;
  final int? maxLines;
  final TextAlign? align;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Text(
      text,
      maxLines: maxLines,
      textAlign: align,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: base.copyWith(
        fontSize: context.isTablet ? (t ?? m + 2) : m,
        color: color ?? (secondary ? p.textSecondary : p.textPrimary),
        fontWeight: weight,
        fontFeatures: tabular
            ? const <FontFeature>[FontFeature.tabularFigures()]
            : null,
      ),
    );
  }
}

SliverGridDelegateWithMaxCrossAxisExtent _gridDelegate(BuildContext context) {
  final bool m = context.isMobile;
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 480,
    mainAxisExtent: m ? 104 : 120,
    mainAxisSpacing: m ? 10 : 12,
    crossAxisSpacing: 14,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// End ke paas pahunchte hi agla page.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final ScrollPosition p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 300) {
      ref.read(productViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProductState state = ref.watch(productViewModelProvider);
    final ProductViewModel vm = ref.read(productViewModelProvider.notifier);
    final bool m = context.isMobile;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double pad = box.maxWidth >= 760 ? 32 : 16;

          return ResponsiveCenter(
            maxWidth: Breakpoints.contentMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, m ? 10 : 12, pad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Txt('Products', AppTextStyles.h1, m: 20, t: 26),
                      const SizedBox(height: 2),
                      _Txt(
                        state.isLoading
                            ? 'Loading your products…'
                            : '${state.total} products in your shop',
                        AppTextStyles.body,
                        m: 12,
                        t: 14,
                        secondary: true,
                      ),
                      SizedBox(height: m ? 12 : 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _SummaryTile(
                              label: 'Total',
                              value: state.isLoading ? '–' : '${state.total}',
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: m ? 10 : 12),
                          Expanded(
                            child: _SummaryTile(
                              label: 'Low stock',
                              value: state.isLoading
                                  ? '–'
                                  : '${state.count(ProductFilter.lowStock)}',
                              color: _amberText,
                            ),
                          ),
                          SizedBox(width: m ? 10 : 12),
                          Expanded(
                            child: _SummaryTile(
                              label: 'Out of stock',
                              value: state.isLoading
                                  ? '–'
                                  : '${state.count(ProductFilter.outOfStock)}',
                              color: AppColors.coral,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: m ? 12 : 16),
                      AppTextField.search(
                        controller: _search,
                        hint: 'Search products by name or SKU',
                        onChanged: (String v) => vm.setSearch(v),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: m ? 12 : 14),
                _FilterChips(
                  padding: pad,
                  selected: state.filter,
                  countOf: state.isLoading ? null : state.count,
                  onChanged: vm.setFilter,
                ),
                SizedBox(height: m ? 12 : 14),
                Expanded(child: _buildBody(state, vm, pad)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ProductState state, ProductViewModel vm, double pad) {
    if (state.isLoading) {
      return _SkeletonGrid(padding: pad);
    }
    if (state.failure != null && state.items.isEmpty) {
      return AppErrorView(failure: state.failure!, onRetry: () => vm.load());
    }

    final List<ProductModel> visible = state.visible;

    return RefreshIndicator(
      onRefresh: () => vm.load(refresh: true),
      child: visible.isEmpty
          ? _EmptyView(
        showLoadMore: state.hasMore,
        isLoadingMore: state.isLoadingMore,
        onLoadMore: vm.loadMore,
      )
          : CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate(context),
              delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int i) => _ProductCard(
                  product: visible[i],
                  index: i,
                  onTap: visible[i].hasVariants && visible[i].variants.isNotEmpty
                      ? () => _showVariants(context, visible[i])
                      : null,
                ),
                childCount: visible.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ListFooter(
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              onLoadMore: vm.loadMore,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: m ? 12 : 14, vertical: m ? 10 : 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Txt(
            value,
            AppTextStyles.h2,
            m: 17,
            t: 22,
            color: color,
            weight: FontWeight.w800,
          ),
          const SizedBox(height: 2),
          _Txt(label, AppTextStyles.caption, m: 11, t: 12, secondary: true, maxLines: 1),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.padding,
    required this.selected,
    required this.countOf,
    required this.onChanged,
  });

  final double padding;
  final ProductFilter selected;

  /// null = loading (count nahi dikhana).
  final int Function(ProductFilter)? countOf;
  final ValueChanged<ProductFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: <Widget>[
          for (final ProductFilter f in ProductFilter.values) ...<Widget>[
            if (f != ProductFilter.values.first) SizedBox(width: m ? 8 : 10),
            GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: m ? 14 : 16,
                  vertical: m ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: f == selected ? AppColors.primary : palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: f == selected
                      ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  countOf == null ? f.label : '${f.label} (${countOf!(f)})',
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: m ? 12 : 13,
                    color: f == selected ? Colors.white : palette.textSecondary,
                    fontWeight: f == selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Product card
// ═══════════════════════════════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.index,
    required this.onTap,
  });

  final ProductModel product;
  final int index;

  /// Variants wale product par tap se variants sheet khulti hai.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final List<Color> tint = _avatarColors[index % _avatarColors.length];
    final StockLevel level = product.stockLevel;

    final Color stockColor = level == StockLevel.out
        ? AppColors.coral
        : level == StockLevel.low
        ? _amberText
        : palette.textPrimary;

    final String priceText = product.hasPriceRange
        ? 'From ${_inr(product.minPrice)}'
        : _inr(product.minPrice);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: palette.border.withValues(alpha: 0.6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.shadow,
              blurRadius: m ? 14 : 20,
              offset: Offset(0, m ? 4 : 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(m ? 12 : 14),
            child: Row(
              children: <Widget>[
                _ProductImage(
                  url: product.image,
                  name: product.name,
                  tint: tint,
                  size: m ? 54 : 64,
                ),
                SizedBox(width: m ? 12 : 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _Txt(
                              product.name,
                              AppTextStyles.bodyBold,
                              m: 13,
                              t: 15,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Txt(
                            priceText,
                            AppTextStyles.bodyBold,
                            m: 13,
                            t: 15,
                            color: palette.isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                            weight: FontWeight.w800,
                            tabular: true,
                          ),
                        ],
                      ),
                      SizedBox(height: m ? 3 : 4),
                      Row(
                        children: <Widget>[
                          Icon(Icons.layers_outlined,
                              size: m ? 13 : 14, color: palette.textSecondary),
                          const SizedBox(width: 4),
                          _Txt(
                            product.variantCount == 0
                                ? 'No variants'
                                : '${product.variantCount} variants',
                            AppTextStyles.caption,
                            m: 11,
                            t: 12,
                            secondary: true,
                          ),
                          const Spacer(),
                          _Txt('Stock ', AppTextStyles.caption, m: 11, t: 12, secondary: true),
                          _Txt(
                            '${product.effectiveStock}',
                            AppTextStyles.bodyBold,
                            m: 12,
                            t: 13,
                            color: stockColor,
                          ),
                        ],
                      ),
                      SizedBox(height: m ? 7 : 10),
                      Row(
                        children: <Widget>[
                          _stockPill(level, palette.isDark),
                          if (product.sku.isNotEmpty) ...<Widget>[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Txt(
                                product.sku,
                                AppTextStyles.caption,
                                m: 10,
                                t: 11,
                                secondary: true,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

Widget _stockPill(StockLevel level, bool dark) {
  switch (level) {
    case StockLevel.inStock:
      return _Pill(
        label: 'In stock',
        color: dark ? AppColors.mint : AppColors.mintDark,
        background: dark ? AppColors.mint.withAlpha(30) : AppColors.mintSoft,
      );
    case StockLevel.low:
      return _Pill(
        label: 'Low stock',
        color: _amberText,
        background: dark ? AppColors.amber.withAlpha(30) : AppColors.amberSoft,
      );
    case StockLevel.out:
      return _Pill(
        label: 'Out of stock',
        color: AppColors.coral,
        background: dark ? AppColors.coral.withAlpha(30) : AppColors.coralSoft,
      );
  }
}

/// Network image; image na ho ya load fail ho to naam ka pehla akshar.
class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.url,
    required this.name,
    required this.tint,
    required this.size,
  });

  final String? url;
  final String name;
  final List<Color> tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.palette.isDark;
    final double radius = size * 0.28;

    final Widget letter = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? tint[1].withAlpha(36) : tint[0],
        borderRadius: BorderRadius.circular(radius),
      ),
      child: _Txt(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        AppTextStyles.h2,
        m: 18,
        t: 22,
        color: tint[1],
        weight: FontWeight.w800,
      ),
    );

    final String? u = url;
    if (u == null || u.isEmpty) return letter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Cache ki memory bachane ke liye chhota decode.
        memCacheWidth: (size * 3).round(),
        placeholder: (BuildContext context, String _) => letter,
        errorWidget: (BuildContext context, String _, Object __) => letter,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final bool m = context.isMobile;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: m ? 7 : 8, vertical: m ? 2 : 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: color,
          fontSize: m ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Footer / empty
// ═══════════════════════════════════════════════════════════════════════════

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 28),
      child: Center(
        child: isLoadingMore
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            strokeCap: StrokeCap.round,
            color: context.palette.isDark
                ? AppColors.primaryLight
                : AppColors.primary,
          ),
        )
            : hasMore
            ? AppButton(
          label: 'Load more',
          variant: AppButtonVariant.tonal,
          size: AppButtonSize.small,
          fullWidth: false,
          onPressed: onLoadMore,
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.showLoadMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final bool showLoadMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    // ListView: taaki khali list pe bhi pull-to-refresh chale.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 56),
        Icon(Icons.inventory_2_outlined,
            size: 46, color: context.palette.textHint),
        const SizedBox(height: 12),
        _Txt('No products found', AppTextStyles.title, m: 15, t: 17, align: TextAlign.center),
        const SizedBox(height: 4),
        _Txt(
          'Try a different search or filter.',
          AppTextStyles.body,
          m: 12,
          t: 14,
          align: TextAlign.center,
          secondary: true,
        ),
        if (showLoadMore)
          _ListFooter(
            hasMore: true,
            isLoadingMore: isLoadingMore,
            onLoadMore: onLoadMore,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Variants bottom sheet
// ═══════════════════════════════════════════════════════════════════════════

void _showVariants(BuildContext context, ProductModel product) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) => _VariantsSheet(product: product),
  );
}

class _VariantsSheet extends StatelessWidget {
  const _VariantsSheet({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final double maxH = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(m ? 16 : 20, 14, m ? 16 : 20, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Txt(product.name, AppTextStyles.title, m: 16, t: 18, maxLines: 1),
                      _Txt(
                        '${product.variantCount} variants · Stock ${product.effectiveStock}',
                        AppTextStyles.caption,
                        m: 11,
                        t: 12,
                        secondary: true,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(m ? 16 : 20, 4, m ? 16 : 20, 20),
              shrinkWrap: true,
              itemCount: product.variants.length,
              separatorBuilder: (BuildContext context, int i) =>
                  Divider(height: 1, color: palette.border.withValues(alpha: 0.6)),
              itemBuilder: (BuildContext context, int i) {
                final ProductVariant v = product.variants[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _Txt(v.displayName, AppTextStyles.bodyBold, m: 13, t: 15, maxLines: 1),
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                _stockPill(v.stockLevel, palette.isDark),
                                const SizedBox(width: 8),
                                _Txt('Stock ${v.stock}', AppTextStyles.caption,
                                    m: 11, t: 12, secondary: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Txt(
                        _inr(v.price),
                        AppTextStyles.bodyBold,
                        m: 13,
                        t: 15,
                        color: palette.isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        weight: FontWeight.w800,
                        tabular: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Loading skeleton (shimmer)
// ═══════════════════════════════════════════════════════════════════════════

class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool m = context.isMobile;
    final bool dark = palette.isDark;
    final double img = m ? 54 : 64;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
      gridDelegate: _gridDelegate(context),
      itemCount: 10,
      itemBuilder: (BuildContext context, int i) {
        return Container(
          padding: EdgeInsets.all(m ? 12 : 14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: palette.border.withValues(alpha: 0.6)),
          ),
          child: Shimmer.fromColors(
            baseColor: dark ? const Color(0xFF262A4A) : const Color(0xFFE7E5F1),
            highlightColor:
            dark ? const Color(0xFF353A63) : const Color(0xFFF7F6FC),
            child: Row(
              children: <Widget>[
                _Bone(width: img, height: img, radius: img * 0.28),
                SizedBox(width: m ? 12 : 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          _Bone(width: 110, height: 13),
                          Spacer(),
                          _Bone(width: 44, height: 13),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const _Bone(width: 90, height: 10),
                      SizedBox(height: m ? 10 : 12),
                      const Row(
                        children: <Widget>[
                          _Bone(width: 56, height: 18, radius: 9),
                          SizedBox(width: 8),
                          _Bone(width: 64, height: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}