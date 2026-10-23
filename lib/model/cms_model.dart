enum CmsPageType {
  termsAndConditions('TERMS_AND_CONDITIONS', 'Terms & Conditions'),
  privacyPolicy('PRIVACY_POLICY', 'Privacy Policy'),
  aboutUs('ABOUT_US', 'About Us');

  const CmsPageType(this.api, this.title);

  /// API me jo type jaata hai.
  final String api;

  /// Content aane se pehle app bar me dikhne wala naam.
  final String title;
}

class CmsPageModel {
  const CmsPageModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String title;

  /// HTML string.
  final String content;
  final DateTime? updatedAt;

  bool get hasContent => content.trim().isNotEmpty;

  factory CmsPageModel.fromJson(Map<String, dynamic> json) {
    return CmsPageModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim(),
      content: json['content']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}