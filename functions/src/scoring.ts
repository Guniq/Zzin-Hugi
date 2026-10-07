export type Tier = 'best' | 'ok' | 'bad';
export const TIERS: Tier[] = ['best', 'ok', 'bad'];
export type Ranking = Record<Tier, string[]>;
export const MIN_REVIEWS = 3;

const TIER_RANGE: Record<Tier, [number, number]> = { best: [7, 10], ok: [4, 7], bad: [0, 4] };

export const round1 = (x: number): number => Math.round(x * 10) / 10;

export function personalScore(tier: Tier, index: number, n: number): number {
  const [lo, hi] = TIER_RANGE[tier];
  return round1(hi - ((hi - lo) * (index + 0.5)) / n);
}

export function emptyRanking(): Ranking {
  return { best: [], ok: [], bad: [] };
}

export function scoresOf(r: Ranking): Map<string, number> {
  const m = new Map<string, number>();
  for (const t of TIERS) r[t].forEach((id, i) => m.set(id, personalScore(t, i, r[t].length)));
  return m;
}

export function insertPlace(r: Ranking, placeId: string, tier: Tier, rankIndex: number): Ranking {
  const next = emptyRanking();
  for (const t of TIERS) next[t] = r[t].filter((id) => id !== placeId);
  const i = Math.max(0, Math.min(Math.trunc(rankIndex), next[tier].length));
  next[tier].splice(i, 0, placeId);
  return next;
}

export interface ScoreChange { old: number | null; new: number }

export function scoreChanges(before: Ranking, after: Ranking): Map<string, ScoreChange> {
  const a = scoresOf(before);
  const out = new Map<string, ScoreChange>();
  for (const [id, s] of scoresOf(after)) {
    const old = a.get(id) ?? null;
    if (old !== s) out.set(id, { old, new: s });
  }
  return out;
}

export interface RestaurantSums { scoreSum: number; reviewCount: number; eventStarSum: number; eventReviewCount: number }
export interface DerivedScores { realScore: number | null; eventScore: number | null; bubble: number | null }

export function deriveScores(s: RestaurantSums): DerivedScores {
  const realScore = s.reviewCount >= MIN_REVIEWS ? round1(s.scoreSum / s.reviewCount) : null;
  const eventScore = s.eventReviewCount >= MIN_REVIEWS ? round1((s.eventStarSum / s.eventReviewCount) * 2) : null;
  const bubble = realScore !== null && eventScore !== null ? round1(eventScore - realScore) : null;
  return { realScore, eventScore, bubble };
}
