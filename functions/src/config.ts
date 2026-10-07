import { defineSecret, defineString } from 'firebase-functions/params';

export const REGION = 'asia-northeast3';
export const KAKAO_REST_KEY = defineSecret('KAKAO_REST_KEY');
// 카카오 앱에서 Client Secret 을 켰을 때만 실제 값. 쓰지 않으면 'none'.
export const KAKAO_CLIENT_SECRET = defineSecret('KAKAO_CLIENT_SECRET');
export const CLOVA_OCR_SECRET = defineSecret('CLOVA_OCR_SECRET');
export const CLOVA_OCR_URL = defineString('CLOVA_OCR_URL');
