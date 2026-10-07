// 점수 계산 (순수 함수). 모든 점수는 별점(1~5) 기준이다.
//   찐점수   = 모든 인증 후기의 "실제 별점" 평균
//   이벤트점수 = 이벤트 참여자가 이벤트 때 준 별점 평균
//   거품     = 이벤트 참여자 각자의 (이벤트 별점 − 실제 별점) 평균. 같은 사람끼리 비교하므로 공정하다.
export const MIN_REVIEWS = 3;

export const round1 = (x: number): number => Math.round(x * 10) / 10;

export interface RestaurantSums {
  /** 모든 후기의 실제 별점 합 */
  scoreSum: number;
  reviewCount: number;
  /** 이벤트 참여 후기의 이벤트 별점 합 */
  eventStarSum: number;
  /** 이벤트 참여 후기의 실제 별점 합 (거품 계산용) */
  eventActualSum: number;
  eventReviewCount: number;
}

export interface DerivedScores { realScore: number | null; eventScore: number | null; bubble: number | null }

export function deriveScores(s: RestaurantSums): DerivedScores {
  const realScore = s.reviewCount >= MIN_REVIEWS ? round1(s.scoreSum / s.reviewCount) : null;
  const enough = s.eventReviewCount >= MIN_REVIEWS;
  const eventScore = enough ? round1(s.eventStarSum / s.eventReviewCount) : null;
  const bubble = enough ? round1((s.eventStarSum - s.eventActualSum) / s.eventReviewCount) : null;
  return { realScore, eventScore, bubble };
}
