import fs from 'node:fs';
import path from 'node:path';
import { PlanReviewError } from '../util.js';

export async function requestJson<T>(url: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(url, options);
  const text = await response.text();
  let json: any;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    throw new PlanReviewError('invalid_json', `Expected JSON from ${url}`, response.status);
  }
  if (!response.ok || json.ok === false) {
    const error = json.error ?? {};
    throw new PlanReviewError(error.code ?? 'api_error', error.message ?? `Request failed: ${response.status}`, response.status, error.details, error.nextAction);
  }
  return (json.data ?? json) as T;
}

export function appendNdjson(filePath: string, value: unknown): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.appendFileSync(filePath, `${JSON.stringify(value)}\n`);
}
