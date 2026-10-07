import { defineSecret, defineString } from 'firebase-functions/params';

export const REGION = 'asia-northeast3';
export const KAKAO_REST_KEY = defineSecret('KAKAO_REST_KEY');
export const CLOVA_OCR_SECRET = defineSecret('CLOVA_OCR_SECRET');
export const CLOVA_OCR_URL = defineString('CLOVA_OCR_URL');
