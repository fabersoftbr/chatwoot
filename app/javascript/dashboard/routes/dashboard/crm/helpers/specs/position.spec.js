import {
  formatDealValue,
  isOverdue,
  centsToUnits,
  unitsToCents,
} from '../position';

describe('formatDealValue', () => {
  it('formats cents as currency', () => {
    expect(formatDealValue(1200000, 'BRL', 'pt-BR')).toContain('12.000');
  });

  it('returns an empty string when there is no value', () => {
    expect(formatDealValue(0, 'BRL', 'pt-BR')).toBe('');
  });
});

describe('isOverdue', () => {
  it('is true for an open deal whose next action is past', () => {
    expect(
      isOverdue({ next_action_at: '2020-01-01T00:00:00Z', closed_at: null })
    ).toBe(true);
  });

  it('is false when the deal is closed', () => {
    expect(
      isOverdue({
        next_action_at: '2020-01-01T00:00:00Z',
        closed_at: '2020-02-01T00:00:00Z',
      })
    ).toBe(false);
  });

  it('is false without a next action', () => {
    expect(isOverdue({ next_action_at: null, closed_at: null })).toBe(false);
  });
});

describe('centsToUnits', () => {
  it('converts cents to currency units', () => {
    expect(centsToUnits(1200000)).toBe(12000);
  });

  it('returns 0 for empty input', () => {
    expect(centsToUnits(null)).toBe(0);
    expect(centsToUnits(undefined)).toBe(0);
  });
});

describe('unitsToCents', () => {
  it('converts currency units to cents', () => {
    expect(unitsToCents(12000)).toBe(1200000);
  });

  it('rounds to whole cents', () => {
    expect(unitsToCents(10.005)).toBe(1001);
  });

  it('returns 0 for empty input', () => {
    expect(unitsToCents('')).toBe(0);
    expect(unitsToCents(null)).toBe(0);
  });
});
