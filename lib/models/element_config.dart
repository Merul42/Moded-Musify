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
    };
  }
}