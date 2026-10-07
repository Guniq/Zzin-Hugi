import { titleFor } from '../../src/title';

test.each([[0, '찐린이'], [9, '찐린이'], [10, '찐후기러'], [49, '찐후기러'], [50, '찐고수'], [999, '찐고수']])('%i따봉 → %s', (n, t) => {
  expect(titleFor(n)).toBe(t);
});
