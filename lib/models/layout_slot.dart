import 'package:musify/models/element_config.dart';

class LayoutSlot {
  LayoutSlot({
    required this.slotId,
    required this.slotName,
    List<ElementConfig>? elements,
  }) : elements = elements ?? <ElementConfig>[] {
    _validateSlotId(slotId);
  }

  factory LayoutSlot.fromJson(Map<String, dynamic> json) {
    final rawElements = json['elements'];
    return LayoutSlot(
      slotId: json['slotId'] as int,
      slotName: json['slotName'] as String,
      elements: rawElements is List
          ? rawElements
              .map(
                (element) => ElementConfig.fromJson(
                  Map<String, dynamic>.from(element as Map),
                ),
              )
              .toList()
          : <ElementConfig>[],
    );
  }

  final int slotId;
  final String slotName;
  final List<ElementConfig> elements;

  Map<String, dynamic> toJson() {
    return {
      'slotId': slotId,
      'slotName': slotName,
      'elements': elements.map((element) => element.toJson()).toList(),
    };
  }

  static void _validateSlotId(int slotId) {
    if (slotId < 1 || slotId > 5) {
      throw ArgumentError.value(slotId, 'slotId', 'must be between 1 and 5');
    }
  }
}