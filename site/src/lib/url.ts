/**
 * The site is served from a path prefix (`/kutto_kodalo/`) on GitHub Pages.
 * Every internal href and asset path must go through here — a hardcoded
 * `/functions/` works locally and 404s in production.
 */
const BASE = import.meta.env.BASE_URL.endsWith('/')
    ? import.meta.env.BASE_URL
    : `${import.meta.env.BASE_URL}/`;

export function withBase(pathname: string): string {
    return `${BASE}${String(pathname).replace(/^\/+/, '')}`;
}

/**
 * Link to a line of shell source on GitHub. `repo` and `branch` come from
 * src/data/modules.json, which scripts/sync-docs.mjs writes, so the site and
 * the generated markdown always agree on where the source lives.
 */
export function sourceUrl(repo: string, branch: string, file: string, line?: number): string {
    return `https://github.com/${repo}/blob/${branch}/${file}${line ? `#L${line}` : ''}`;
}
