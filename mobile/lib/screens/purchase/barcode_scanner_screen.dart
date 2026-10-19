import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_colors.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final int targetQuantity;
  final List<String> initialSerials;
  final Set<String> existingInventorySerials;
  final String? batchNumber;

  const BarcodeScannerScreen({
    super.key,
    required this.targetQuantity,
    required this.initialSerials,
    required this.existingInventorySerials,
    this.batchNumber,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  late final List<String> _scannedSerials;
  late int _targetQuantity;

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
    _scannedSerials = List<String>.from(widget.initialSerials);
    _targetQuantity = widget.targetQuantity;
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
    // 1. Check duplicate inside current batch
    final alreadyInBatch = _scannedSerials
        .any((s) => s.trim().toUpperCase() == serial.toUpperCase());
    if (alreadyInBatch) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _statusMessage = 'Duplicate: "$serial" is already in this batch!';
        _statusColor = AppColors.danger;
        _statusIcon = Icons.warning_amber_rounded;
      });
      return;
    }

    // 2. Check duplicate in existing database inventory
    final alreadyInInventory = widget.existingInventorySerials
        .contains(serial.toUpperCase());
    if (alreadyInInventory) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _statusMessage = 'Conflict: "$serial" already exists in inventory!';
        _statusColor = AppColors.danger;
        _statusIcon = Icons.error_outline;
      });
      return;
    }

    // 3. Check quantity limit
    if (_scannedSerials.length >= _targetQuantity) {
      HapticFeedback.selectionClick();
      // Added beyond target quantity - still add, but alert user
      setState(() {
        _scannedSerials.add(serial);
        _targetQuantity = _scannedSerials.length;
        _statusMessage = 'Added "$serial" (#${_scannedSerials.length}). Target auto-adjusted.';
        _statusColor = AppColors.solarAmber;
        _statusIcon = Icons.add_circle_outline;
      });
      return;
    }

    // Success: add serial
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _scannedSerials.add(serial);
      _statusMessage = 'Scanned: "$serial" (#${_scannedSerials.length} of $_targetQuantity)';
      _statusColor = AppColors.solarGreenDark;
      _statusIcon = Icons.check_circle_outline;
    });

    if (_scannedSerials.length == _targetQuantity) {
      HapticFeedback.vibrate();
    }
  }

  void _removeSerial(int index) {
    if (index >= 0 && index < _scannedSerials.length) {
      setState(() {
        final removed = _scannedSerials.removeAt(index);
        _statusMessage = 'Removed: "$removed"';
        _statusColor = AppColors.textSecondary;
        _statusIcon = Icons.remove_circle_outline;
      });
    }
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type Serial Number'),
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
            child: const Text('Add Serial'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _scannedSerials.length;
    final isComplete = count >= _targetQuantity && _targetQuantity > 0;
    final progress = _targetQuantity > 0 ? (count / _targetQuantity).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Panel Barcodes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (widget.batchNumber != null && widget.batchNumber!.isNotEmpty)
              Text(
                'Batch: ${widget.batchNumber}',
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
                  color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: Stack(
                children: [
                  // Corner accent indicators
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
                          left: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
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
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
                          right: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
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
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
                          left: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
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
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
                          right: BorderSide(
                            color: isComplete ? AppColors.solarGreen : AppColors.solarAmber,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Center guidance
                  const Center(
                    child: Text(
                      'Align Barcode Inside Box',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Panels Scanned: $count / $_targetQuantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? AppColors.solarGreenLight
                              : AppColors.solarAmberLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isComplete
                              ? 'Target Reached ✓'
                              : '${_targetQuantity - count} Remaining',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isComplete
                                ? AppColors.solarGreenDark
                                : AppColors.solarAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete ? AppColors.solarGreen : AppColors.solarAmber,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

          // Bottom Bar: Recent Scanned Chips & Done Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: const Border(
                  top: BorderSide(color: Colors.white24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Horizontal list of recently scanned serials
                  if (_scannedSerials.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Scans (${_scannedSerials.length})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _scannedSerials.clear();
                              _statusMessage = 'Cleared all scanned serials';
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
                        reverse: true, // Show most recently added first
                        itemCount: _scannedSerials.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final reversedIndex = _scannedSerials.length - 1 - index;
                          final sn = _scannedSerials[reversedIndex];
                          return Chip(
                            backgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            label: Text(
                              '#${reversedIndex + 1}: $sn',
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
                            onDeleted: () => _removeSerial(reversedIndex),
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
                            backgroundColor: isComplete
                                ? AppColors.solarGreen
                                : AppColors.solarAmber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(_scannedSerials);
                          },
                          icon: const Icon(Icons.done_all, size: 20),
                          label: Text(
                            'Done ($count / $_targetQuantity)',
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
