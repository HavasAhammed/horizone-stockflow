import React, { useEffect, useRef, useState } from 'react';
import { Camera, X, CheckCircle2, AlertTriangle, Flashlight, Plus } from 'lucide-react';
import { Modal } from './Modal';

interface WebBarcodeScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  targetQuantity: number;
  initialSerials: string[];
  existingInventorySerials: Set<string>;
  onSaveSerials: (serials: string[]) => void;
}

export const WebBarcodeScannerModal: React.FC<WebBarcodeScannerModalProps> = ({
  isOpen,
  onClose,
  targetQuantity,
  initialSerials,
  existingInventorySerials,
  onSaveSerials,
}) => {
  const [serials, setSerials] = useState<string[]>([]);
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
      setSerials([...initialSerials]);
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
        osc.frequency.setValueAtTime(880, ctx.currentTime); // High pitch success beep
        gain.gain.setValueAtTime(0.15, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.15);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + 0.15);
      } else {
        osc.frequency.setValueAtTime(300, ctx.currentTime); // Low pitch error tone
        gain.gain.setValueAtTime(0.2, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.25);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + 0.25);
      }
    } catch {
      // AudioContext may be blocked before user interaction
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

      // Check torch support
      const track = stream.getVideoTracks()[0];
      const capabilities = (track.getCapabilities ? track.getCapabilities() : {}) as any;
      if (capabilities.torch) {
        setHasTorch(true);
      }

      // Start Barcode Detection loop if BarcodeDetector is supported
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
                  // 1.5 second debounce for exact same code
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
            // detection frame error ignore
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

    // 1. Check duplicate inside current batch
    if (serials.some((s) => s.toUpperCase() === serial)) {
      playBeep(false);
      setStatusMessage({
        text: `Duplicate: "${serial}" is already in this batch!`,
        type: 'error',
      });
      return;
    }

    // 2. Check duplicate in existing database inventory
    if (existingInventorySerials.has(serial)) {
      playBeep(false);
      setStatusMessage({
        text: `Conflict: "${serial}" already exists in inventory!`,
        type: 'error',
      });
      return;
    }

    // Success: add to list
    playBeep(true);
    setSerials((prev) => {
      const next = [...prev, serial];
      setStatusMessage({
        text: `Scanned: "${serial}" (#${next.length} of ${targetQuantity})`,
        type: next.length >= targetQuantity ? 'success' : 'success',
      });
      return next;
    });
  };

  const handleManualAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualInput.trim()) return;
    handleBarcodeDetected(manualInput.trim());
    setManualInput('');
  };

  const handleRemoveSerial = (index: number) => {
    setSerials((prev) => prev.filter((_, i) => i !== index));
  };

  const handleSaveAndClose = () => {
    onSaveSerials(serials);
    onClose();
  };

  const isComplete = serials.length >= targetQuantity && targetQuantity > 0;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Barcode Scanner - Panel Serial Numbers"
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
              Scan Progress
            </div>
            <div style={{ fontSize: '1.1rem', fontWeight: 700 }}>
              {serials.length} of {targetQuantity} panels scanned
            </div>
          </div>
          <span
            className={`badge ${isComplete ? 'badge-green' : 'badge-orange'}`}
            style={{ fontSize: '0.85rem', padding: '4px 10px' }}
          >
            {isComplete ? 'Target Reached ✓' : `${Math.max(0, targetQuantity - serials.length)} Remaining`}
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
                You can still type serial numbers or use a USB / Bluetooth handheld barcode scanner!
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
                  border: `2px dashed ${isComplete ? '#10b981' : '#ea8410'}`,
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
                Align Barcode Here
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
            placeholder="Type or scan with handheld USB barcode scanner (Press Enter)..."
            value={manualInput}
            onChange={(e) => setManualInput(e.target.value.toUpperCase())}
            style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
          />
          <button type="submit" className="btn btn-secondary" style={{ whiteSpace: 'nowrap' }}>
            <Plus size={16} /> Add
          </button>
        </form>

        {/* Scanned Serials List Preview */}
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
              Scanned Serials ({serials.length})
            </span>
            {serials.length > 0 && (
              <button
                type="button"
                onClick={() => setSerials([])}
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
            {serials.length === 0 ? (
              <div
                style={{
                  width: '100%',
                  textAlign: 'center',
                  padding: '16px',
                  color: 'var(--color-text-muted)',
                  fontSize: '0.85rem',
                }}
              >
                No panels scanned yet. Point camera at panel barcode or type above.
              </div>
            ) : (
              serials.map((sn, idx) => (
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
                    onClick={() => handleRemoveSerial(idx)}
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
          <button type="button" className="btn btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button type="button" className="btn btn-primary" onClick={handleSaveAndClose}>
            Done ({serials.length} Scanned)
          </button>
        </div>
      </div>
    </Modal>
  );
};
