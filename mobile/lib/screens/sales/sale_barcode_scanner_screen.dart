import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_colors.dart';
import '../../models/panel_item.dart';

class SaleBarcodeScannerScreen extends StatefulWidget {
  final int wattage;
  final List<PanelItem> availablePanels;
  final Set<String> initiallySelectedSerials;
  final List<PanelItem> allInventoryPanels;

  const SaleBarcodeScannerScreen({
    super.key,
    required this.wattage,
    required this.availablePanels,
    required this.initiallySelectedSerials,
    required this.allInventoryPanels,
  });

  @override
  State<SaleBarcodeScannerScreen> createState() =>
      _SaleBarcodeScannerScreenState();
}

class _SaleBarcodeScannerScreenState extends State<SaleBarcodeScannerScreen> {
  late final MobileScannerController _controller;
  late final Set<String> _selectedSerials;

  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  String? _statusMessage;
  Color _statusColor = AppColors.solarGreenDark;
  IconData _statusIcon = Icons.check_circle;

  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _selectedSerials = Set<String>.from(widget.initiallySelectedSerials);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final serial = raw.trim().toUpperCase();

      // Debounce: ignore exact same barcode within 1.5 seconds
      final now = DateTime.now();
      if (_lastScannedCode == serial &&
          _lastScannedTime != null &&
          now.difference(_lastScannedTime!).inMilliseconds < 1500) {
        continue;
      }

      _lastScannedCode = serial;
      _lastScannedTime = now;

      _handleBarcodeScanned(serial);
      break; // Process one barcode per frame
    }
  }

  void _handleBarcodeScanned(String serial) {
    // 1. Check if already selected
    if (_selectedSerials.contains(serial)) {
      HapticFeedback.selectionClick();
      setState(() {
        _statusMessage = 'Already selected: "$serial"';
        _statusColor = AppColors.warning;
        _statusIcon = Icons.info_outline;
      });
      return;
    }

    // 2. Check if available in this wattage
    final match = widget.availablePanels.cast<PanelItem?>().firstWhere(
          (p) => p?.serialNumber.toUpperCase() == serial,
          orElse: () => null,
        );

    if (match != null) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      setState(() {
        _selectedSerials.add(match.serialNumber);
        _statusMessage =
            '✓ Selected "${match.serialNumber}" (Batch: ${match.batchNumber}) • Total: ${_selectedSerials.length}';
        _statusColor = AppColors.solarGreenDark;
        _statusIcon = Icons.check_circle_outline;
      });
      return;
    }

    // 3. Not in available panels for this wattage: diagnose reason from all inventory
    final inAll = widget.allInventoryPanels.cast<PanelItem?>().firstWhere(
          (p) => p?.serialNumber.toUpperCase() == serial,
          orElse: () => null,
        );

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    if (inAll != null) {
      if (inAll.wattage != widget.wattage) {
        setState(() {
          _statusMessage =
              'Wattage Mismatch: "$serial" is ${inAll.wattage}W (current sale is ${widget.wattage}W)';
          _statusColor = AppColors.danger;
          _statusIcon = Icons.error_outline;
        });
      } else if (!inAll.isAvailable) {
        setState(() {
          _statusMessage =
              'Panel "$serial" is already SOLD and cannot be dispatched again.';
          _statusColor = AppColors.danger;
          _statusIcon = Icons.cancel_outlined;
        });
      } else {
        setState(() {
          _statusMessage = 'Panel "$serial" is not available for selection.';
          _statusColor = AppColors.danger;
          _statusIcon = Icons.warning_amber_rounded;
        });
      }
    } else {
      setState(() {
        _statusMessage =
            'Serial "$serial" not found in inventory for ${widget.wattage}W stock.';
        _statusColor = AppColors.danger;
        _statusIcon = Icons.search_off;
      });
    }
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select ${widget.wattage}W Panel'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Serial Number',
            hintText: 'e.g. HZ-540-001',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              Navigator.of(ctx).pop();
              _handleBarcodeScanned(val.trim().toUpperCase());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                _handleBarcodeScanned(textController.text.trim().toUpperCase());
              }
            },
            child: const Text('Select Panel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _selectedSerials.length;
    final total = widget.availablePanels.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan to Select ${widget.wattage}W Panels',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '$count selected of $total available in stock',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isTorchOn ? 'Turn Off Flashlight' : 'Turn On Flashlight',
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.white,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            tooltip: 'Type Serial Manually',
            icon: const Icon(Icons.keyboard, color: Colors.white),
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera scanner view
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scanning Reticle Overlay
          Center(
            child: Container(
              width: 280,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryBlue,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.primaryBlue, width: 4),
                          left: BorderSide(color: AppColors.primaryBlue, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.primaryBlue, width: 4),
                          right: BorderSide(color: AppColors.primaryBlue, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.primaryBlue, width: 4),
                          left: BorderSide(color: AppColors.primaryBlue, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.primaryBlue, width: 4),
                          right: BorderSide(color: AppColors.primaryBlue, width: 4),
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Point at Solar Panel Barcode',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Tracker Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Panels Selected for Sale',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        '$count Panels',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.wattage}W Stock',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live Status Message Banner
          if (_statusMessage != null)
            Positioned(
              bottom: 180,
              left: 20,
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Bar: Selected list chips & Done Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: const Border(
                  top: BorderSide(color: Colors.white24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedSerials.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Panels (${_selectedSerials.length})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSerials.clear();
                              _statusMessage = 'Cleared all selections';
                              _statusColor = AppColors.textSecondary;
                            });
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              color: AppColors.dangerLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        itemCount: _selectedSerials.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final reversedIndex =
                              _selectedSerials.length - 1 - index;
                          final sn = _selectedSerials.elementAt(reversedIndex);
                          return Chip(
                            backgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            label: Text(
                              sn,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white60,
                            ),
                            onDeleted: () {
                              setState(() {
                                _selectedSerials.remove(sn);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _showManualEntryDialog,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Type Serial'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.solarGreenDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(_selectedSerials);
                          },
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: Text(
                            'Confirm (${_selectedSerials.length} Panels)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
