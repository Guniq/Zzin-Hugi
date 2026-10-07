export function titleFor(likes: number): string {
  if (likes >= 50) return '찐고수';
  if (likes >= 10) return '찐후기러';
  return '찐린이';
}
