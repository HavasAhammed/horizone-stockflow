import { describe, it, expect } from 'vitest';

describe('Website Business Validation & Serial Parser Rules', () => {
  it('parses bulk serial numbers separated by comma, space, and newline', () => {
    const rawInput = 'HZ-540-01, HZ-540-02\nHZ-540-03   HZ-540-04\n\nHZ-540-05';
    const parsed = rawInput
      .split(/[\n,\s]+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    expect(parsed).toEqual([
      'HZ-540-01',
      'HZ-540-02',
      'HZ-540-03',
      'HZ-540-04',
      'HZ-540-05',
    ]);
    expect(parsed.length).toBe(5);
  });

  it('detects duplicate serial numbers in user input', () => {
    const rawInput = 'HZ-540-01\nHZ-540-02\nHZ-540-01';
    const parsed = rawInput
      .split(/[\n,\s]+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    const duplicates = parsed.filter(
      (item, index) => parsed.indexOf(item) !== index
    );

    expect(duplicates).toContain('HZ-540-01');
    expect(duplicates.length).toBe(1);
  });

  it('formats monetary currency strictly in INR (₹) without mixing with wattage', () => {
    const totalAmount = 14200 * 4;
    const formatted = new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(totalAmount);

    expect(formatted).toContain('56,800');
    expect(formatted).not.toContain('W');
  });

  it('validates mandatory KSEB consumer number and phone requirements', () => {
    const validateCustomer = (consumerNumber: string, phone: string) => {
      const c = consumerNumber.trim();
      const p = phone.trim();
      if (!c) return { valid: false, error: 'Consumer number is mandatory' };
      if (!p) return { valid: false, error: 'Phone number is mandatory' };
      return { valid: true };
    };

    expect(validateCustomer('', '+91 98470 12345').valid).toBe(false);
    expect(validateCustomer('1155443322110', '').valid).toBe(false);
    expect(validateCustomer('  1155443322110  ', '  9847012345  ').valid).toBe(true);
  });
});
