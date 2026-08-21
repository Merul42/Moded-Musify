class ElementConfig {
  const ElementConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.colorHex,
    this.customImagePath,
    this.actionId,
    this.borderRadius = 0,
    this.opacity = 1,
    this.textAlignment = 'center',
    this.textSize = 16,
  });

  factory ElementConfig.fromJson(Map<String, dynamic> json) {
    return ElementConfig(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      colorHex: json['colorHex'] as String?,
      customImagePath: json['customImagePath'] as String?,
      actionId: json['actionId'] as String?,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      textAlignment: json['textAlignment'] as String? ?? 'center',
      textSize: (json['textSize'] as num?)?.toDouble() ?? 16,
    );
  }

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? colorHex;
  final String? customImagePath;
  final String? actionId;
  final double borderRadius;
  final double opacity;
  final String textAlignment;
  final double textSize;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'colorHex': colorHex,
      'customImagePath': customImagePath,
      'actionId': actionId,
      'borderRadius': borderRadius,
      'opacity': opacity,
      'textAlignment': textAlignment,
      'textSize': textSize,
    };
  }

  ElementConfig copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    String? colorHex,
    String? customImagePath,
    String? actionId,
    double? borderRadius,
    double? opacity,
    String? textAlignment,
    double? textSize,
  }) {
    return ElementConfig(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      colorHex: colorHex ?? this.colorHex,
      customImagePath: customImagePath ?? this.customImagePath,
      actionId: actionId ?? this.actionId,
      borderRadius: borderRadius ?? this.borderRadius,
      opacity: opacity ?? this.opacity,
      textAlignment: textAlignment ?? this.textAlignment,
      textSize: textSize ?? this.textSize,
    );
  }
}