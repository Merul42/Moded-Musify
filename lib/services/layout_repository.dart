import 'package:hive/hive.dart';
import 'package:musify/models/layout_slot.dart';

class LayoutRepository {
  LayoutRepository({Box<dynamic>? box}) : _box = box;

  static const String _boxName = 'user';
  static const String _slotsKey = 'layoutSlots';
  static const String _activeSlotKey = 'activeLayoutSlotId';

  final Box<dynamic>? _box;

  Future<List<LayoutSlot>> getSlots() async {
    final rawSlots = _storageBox.get(_slotsKey, defaultValue: <dynamic>[]);
    if (rawSlots is! List) return <LayoutSlot>[];

    return rawSlots
        .map(
          (slot) => LayoutSlot.fromJson(
            Map<String, dynamic>.from(slot as Map),
          ),
        )
        .toList();
  }

  Future<LayoutSlot?> getSlot(int slotId) async {
    _validateSlotId(slotId);
    final slots = await getSlots();
    for (final slot in slots) {
      if (slot.slotId == slotId) return slot;
    }
    return null;
  }

  Future<void> saveSlot(LayoutSlot slot) async {
    final slots = await getSlots();
    final index = slots.indexWhere((current) => current.slotId == slot.slotId);
    if (index == -1) {
      slots.add(slot);
    } else {
      slots[index] = slot;
    }
    await _storageBox.put(
      _slotsKey,
      slots.map((current) => current.toJson()).toList(),
    );
  }

  Future<int> getActiveSlotId() async {
    final slotId = _storageBox.get(_activeSlotKey, defaultValue: 1);
    if (slotId is int && slotId >= 1 && slotId <= 5) return slotId;
    return 1;
  }

  Future<void> setActiveSlotId(int slotId) async {
    _validateSlotId(slotId);
    await _storageBox.put(_activeSlotKey, slotId);
  }

  Box<dynamic> get _storageBox => _box ?? Hive.box(_boxName);

  static void _validateSlotId(int slotId) {
    if (slotId < 1 || slotId > 5) {
      throw ArgumentError.value(slotId, 'slotId', 'must be between 1 and 5');
    }
  }
}