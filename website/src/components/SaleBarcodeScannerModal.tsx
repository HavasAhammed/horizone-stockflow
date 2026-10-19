import React, { useEffect, useRef, useState } from 'react';
import { Camera, X, CheckCircle2, AlertTriangle, Flashlight, Plus } from 'lucide-react';
import { Modal } from './Modal';
import type { PanelItem } from '../types';

interface SaleBarcodeScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  wattage: number;
  availablePanels: PanelItem[];
  selectedSerials: string[];
  onToggleSerial: (serial: string) => void;
  onClearAll: () => void;
}

export const SaleBarcodeScannerModal: React.FC<SaleBarcodeScannerModalProps> = ({
  isOpen,
  onClose,
  wattage,
  availablePanels,
  selectedSerials,
  onToggleSerial,
  onClearAll,
}) => {
  const [manualInput, setManualInput] = useState('');
  const [statusMessage, setStatusMessage] = useState<{
    text: string;
    type: 'success' | 'warning' | 'error';
  } | null>(null);
  const [cameraActive, setCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [hasTorch, setHasTorch] = useState(false);
  const [torchOn, setTorchOn] = useState(false);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const scanIntervalRef = useRef<number | null>(null);
  const lastScannedRef = useRef<{ code: string; time: number }>({ code: '', time: 0 });

  useEffect(() => {
    if (isOpen) {
      setStatusMessage(null);
      startCamera();
    } else {
      stopCamera();
    }
    return () => {
      stopCamera();
    };
  }, [isOpen]);

  const playBeep = (isSuccess = true) => {
    try {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);

      if (isSuccess) {
        osc.frequency.setValueAtTime(880, ctx.currentTime);
        gain.gain.setValueAtTime(0.15, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.15);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + 0.15);
      } else {
        osc.frequency.setValueAtTime(300, ctx.currentTime);
        gain.gain.setValueAtTime(0.2, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.25);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + 0.25);
      }
    } catch {
      // AudioContext blocked
    }
  };

  const startCamera = async () => {
    setCameraError(null);
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        setCameraError('Camera access not supported on this browser or environment.');
        return;
      }

      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });

      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }

      setCameraActive(true);

      const track = stream.getVideoTracks()[0];
      const capabilities = (track.getCapabilities ? track.getCapabilities() : {}) as any;
      if (capabilities.torch) {
        setHasTorch(true);
      }

      if ('BarcodeDetector' in window) {
        const formats = [
          'code_128',
          'code_39',
          'code_93',
          'ean_13',
          'ean_8',
          'qr_code',
          'data_matrix',
        ];
        const detector = new (window as any).BarcodeDetector({ formats });

        scanIntervalRef.current = window.setInterval(async () => {
          if (!videoRef.current || videoRef.current.readyState < 2) return;
          try {
            const detected = await detector.detect(videoRef.current);
            if (detected && detected.length > 0) {
              for (const barcode of detected) {
                const raw = barcode.rawValue?.trim()?.toUpperCase();
                if (raw) {
                  const now = Date.now();
                  if (lastScannedRef.current.code === raw && now - lastScannedRef.current.time < 1500) {
                    continue;
                  }
                  lastScannedRef.current = { code: raw, time: now };
                  handleBarcodeDetected(raw);
                  break;
                }
              }
            }
          } catch {
            // ignore frame error
          }
        }, 200);
      }
    } catch (err: any) {
      setCameraError(err.message || 'Could not start camera feed.');
      setCameraActive(false);
    }
  };

  const stopCamera = () => {
    if (scanIntervalRef.current) {
      clearInterval(scanIntervalRef.current);
      scanIntervalRef.current = null;
    }
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    setCameraActive(false);
  };

  const toggleTorch = async () => {
    if (!streamRef.current) return;
    const track = streamRef.current.getVideoTracks()[0];
    try {
      await (track as any).applyConstraints({
        advanced: [{ torch: !torchOn }],
      });
      setTorchOn(!torchOn);
    } catch {
      // torch error
    }
  };

  const handleBarcodeDetected = (code: string) => {
    const serial = code.trim().toUpperCase();
    if (!serial) return;

    // Check if already selected
    if (selectedSerials.includes(serial)) {
      playBeep(false);
      setStatusMessage({
        text: `Panel "${serial}" is already selected.`,
        type: 'warning',
      });
      return;
    }

    // Check if in available panels for this wattage
    const match = availablePanels.find((p) => p.serialNumber.toUpperCase() === serial);
    if (match) {
      playBeep(true);
      onToggleSerial(match.serialNumber);
      setStatusMessage({
        text: `✓ Selected "${match.serialNumber}" (Batch: ${match.batchNumber})`,
        type: 'success',
      });
      return;
    }

    // Not available in stock
    playBeep(false);
    setStatusMessage({
      text: `Serial "${serial}" is not in available ${wattage}W stock!`,
      type: 'error',
    });
  };

  const handleManualAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualInput.trim()) return;
    handleBarcodeDetected(manualInput.trim());
    setManualInput('');
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={`Scan & Select ${wattage}W Panels`}
      maxWidth="680px"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Progress & Target Stats */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            background: 'var(--color-bg)',
            padding: '12px 16px',
            borderRadius: '8px',
            border: '1px solid var(--color-border)',
          }}
        >
          <div>
            <div style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)' }}>
              Selected For Dispatch
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: 700 }}>
              {selectedSerials.length} of {availablePanels.length} available panels
            </div>
          </div>
          <span
            className="badge badge-green"
            style={{ fontSize: '0.85rem', padding: '4px 10px' }}
          >
            {wattage}W Stock
          </span>
        </div>

        {/* Camera Scanner View */}
        <div
          style={{
            position: 'relative',
            width: '100%',
            height: '240px',
            backgroundColor: '#000',
            borderRadius: '10px',
            overflow: 'hidden',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {cameraError ? (
            <div
              style={{
                color: '#fff',
                textAlign: 'center',
                padding: '20px',
                fontSize: '0.9rem',
              }}
            >
              <Camera size={36} color="var(--color-text-muted)" style={{ marginBottom: '8px' }} />
              <div>Camera scanner unavailable on this device or permission denied.</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)', marginTop: '4px' }}>
                You can still type serial numbers or use a USB / Bluetooth handheld barcode scanner below.
              </div>
            </div>
          ) : (
            <>
              <video
                ref={videoRef}
                playsInline
                muted
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'cover',
                }}
              />
              {/* Reticle Overlay */}
              <div
                style={{
                  position: 'absolute',
                  width: '240px',
                  height: '140px',
                  border: '2px dashed var(--color-primary)',
                  borderRadius: '12px',
                  boxShadow: '0 0 0 9999px rgba(0, 0, 0, 0.4)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#fff',
                  fontSize: '0.75rem',
                  textShadow: '0 1px 2px rgba(0,0,0,0.8)',
                  pointerEvents: 'none',
                }}
              >
                Point at Panel Barcode
              </div>

              {cameraActive && (
                <div
                  style={{
                    position: 'absolute',
                    top: '10px',
                    left: '10px',
                    background: 'rgba(16, 185, 129, 0.8)',
                    color: '#fff',
                    borderRadius: '12px',
                    padding: '3px 8px',
                    fontSize: '0.75rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                  }}
                >
                  <span
                    style={{
                      width: '6px',
                      height: '6px',
                      borderRadius: '50%',
                      background: '#fff',
                    }}
                  />
                  Live Camera
                </div>
              )}

              {/* Torch button */}
              {hasTorch && (
                <button
                  type="button"
                  onClick={toggleTorch}
                  style={{
                    position: 'absolute',
                    top: '10px',
                    right: '10px',
                    background: torchOn ? '#ea8410' : 'rgba(0,0,0,0.6)',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '20px',
                    padding: '6px 12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    cursor: 'pointer',
                    fontSize: '0.8rem',
                  }}
                >
                  <Flashlight size={14} /> {torchOn ? 'Torch On' : 'Torch'}
                </button>
              )}
            </>
          )}
        </div>

        {/* Live Status Message Alert */}
        {statusMessage && (
          <div
            className={`alert-banner ${
              statusMessage.type === 'error'
                ? 'alert-danger'
                : statusMessage.type === 'warning'
                ? 'alert-warning'
                : 'alert-info'
            }`}
            style={{ margin: 0, padding: '8px 12px', fontSize: '0.85rem' }}
          >
            {statusMessage.type === 'error' ? (
              <AlertTriangle size={16} />
            ) : (
              <CheckCircle2 size={16} color="var(--color-green-dark)" />
            )}
            <span>{statusMessage.text}</span>
          </div>
        )}

        {/* Hardware Scanner & Quick Typing Input */}
        <form onSubmit={handleManualAdd} style={{ display: 'flex', gap: '8px' }}>
          <input
            type="text"
            className="form-input"
            placeholder="Scan barcode or type serial (Press Enter to select)..."
            value={manualInput}
            onChange={(e) => setManualInput(e.target.value.toUpperCase())}
            style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
          />
          <button type="submit" className="btn btn-secondary" style={{ whiteSpace: 'nowrap' }}>
            <Plus size={16} /> Select
          </button>
        </form>

        {/* Selected Serials List Preview */}
        <div>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '6px',
            }}
          >
            <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>
              Selected Panels ({selectedSerials.length})
            </span>
            {selectedSerials.length > 0 && (
              <button
                type="button"
                onClick={onClearAll}
                style={{
                  background: 'none',
                  border: 'none',
                  color: 'var(--color-danger)',
                  fontSize: '0.8rem',
                  cursor: 'pointer',
                }}
              >
                Clear All
              </button>
            )}
          </div>
          <div
            style={{
              maxHeight: '140px',
              overflowY: 'auto',
              border: '1px solid var(--color-border)',
              borderRadius: '6px',
              background: 'var(--color-bg)',
              padding: '6px',
              display: 'flex',
              flexWrap: 'wrap',
              gap: '6px',
            }}
          >
            {selectedSerials.length === 0 ? (
              <div
                style={{
                  width: '100%',
                  textAlign: 'center',
                  padding: '16px',
                  color: 'var(--color-text-muted)',
                  fontSize: '0.85rem',
                }}
              >
                No panels selected yet. Scan barcodes with camera or enter serial above.
              </div>
            ) : (
              selectedSerials.map((sn, idx) => (
                <span
                  key={`${sn}-${idx}`}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '3px 8px',
                    background: '#fff',
                    border: '1px solid var(--color-border)',
                    borderRadius: '4px',
                    fontSize: '0.8rem',
                    fontFamily: 'monospace',
                  }}
                >
                  <strong style={{ color: 'var(--color-primary)' }}>#{idx + 1}</strong> {sn}
                  <button
                    type="button"
                    onClick={() => onToggleSerial(sn)}
                    style={{
                      border: 'none',
                      background: 'none',
                      color: 'var(--color-text-muted)',
                      cursor: 'pointer',
                      padding: '0 2px',
                    }}
                  >
                    <X size={12} />
                  </button>
                </span>
              ))
            )}
          </div>
        </div>

        {/* Modal Actions */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
          <button type="button" className="btn btn-primary" onClick={onClose}>
            Done ({selectedSerials.length} Panels Selected)
          </button>
        </div>
      </div>
    </Modal>
  );
};
