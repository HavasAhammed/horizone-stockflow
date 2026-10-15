import 'package:hive_flutter/hive_flutter.dart';
import '../models/panel_item.dart';

abstract class PanelRepository {
  Future<List<PanelItem>> getAllPanels();
  Future<PanelItem?> getPanelBySerialNumber(String serialNumber);
  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage);
  Future<void> savePanel(PanelItem panel);
  Future<void> savePanels(List<PanelItem> panels);
  Future<void> deletePanel(String serialNumber);
  Future<void> deletePanels(List<String> serialNumbers);
}

class HivePanelRepository implements PanelRepository {
  static const String boxName = 'panels_box';

  Box get _box => Hive.box(boxName);

  @override
  Future<List<PanelItem>> getAllPanels() async {
    return _box.values.map((v) => PanelItem.fromMap(v as Map)).toList();
  }

  @override
  Future<PanelItem?> getPanelBySerialNumber(String serialNumber) async {
    final raw = _box.get(serialNumber);
    if (raw == null) return null;
    return PanelItem.fromMap(raw as Map);
  }

  @override
  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage) async {
    final list = _box.values
        .map((v) => PanelItem.fromMap(v as Map))
        .where((p) => p.wattage == wattage && p.isAvailable)
        .toList();
    list.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    return list;
  }

  @override
  Future<void> savePanel(PanelItem panel) async {
    await _box.put(panel.serialNumber, panel.toMap());
  }

  @override
  Future<void> savePanels(List<PanelItem> panels) async {
    final Map<String, dynamic> entries = {};
    for (final p in panels) {
      entries[p.serialNumber] = p.toMap();
    }
    await _box.putAll(entries);
  }

  @override
  Future<void> deletePanel(String serialNumber) async {
    await _box.delete(serialNumber);
  }

  @override
  Future<void> deletePanels(List<String> serialNumbers) async {
    await _box.deleteAll(serialNumbers);
  }
}
