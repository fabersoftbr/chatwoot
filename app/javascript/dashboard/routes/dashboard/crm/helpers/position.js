export const formatDealValue = (
  valueCents,
  currency = 'BRL',
  locale = 'pt-BR'
) => {
  if (!valueCents) return '';

  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(valueCents / 100);
};

export const isOverdue = deal => {
  if (!deal?.next_action_at || deal.closed_at) return false;

  return new Date(deal.next_action_at).getTime() < Date.now();
};
