import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export interface ServiceConfig {
  url: string;
}

function readJson(filePath: string): Partial<ServiceConfig> {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8')) as Partial<ServiceConfig>;
  } catch {
    return {};
  }
}

export function resolveServiceUrl(explicitUrl?: string, cwd = process.cwd()): string {
  if (explicitUrl) return explicitUrl.replace(/\/$/, '');
  if (process.env.PLAN_REVIEW_URL) return process.env.PLAN_REVIEW_URL.replace(/\/$/, '');

  const project = readJson(path.join(cwd, '.plan-reviewer.json'));
  if (project.url) return project.url.replace(/\/$/, '');

  const user = readJson(path.join(os.homedir(), '.config', 'plan-reviewer', 'config.json'));
  if (user.url) return user.url.replace(/\/$/, '');

  return 'http://127.0.0.1:4317';
}
