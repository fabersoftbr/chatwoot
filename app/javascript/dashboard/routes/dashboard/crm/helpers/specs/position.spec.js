import { formatDealValue, isOverdue } from '../position';

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
