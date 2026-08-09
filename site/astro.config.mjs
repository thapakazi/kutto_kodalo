// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

/**
 * Deployed as a GitHub *project* page, so the site lives under a path prefix.
 * `base` must match the repository name exactly, and every internal link has to
 * go through `withBase()` (src/lib/url.ts) or Starlight's own helpers.
 *
 * Override with SITE_URL / SITE_BASE when serving from somewhere else; keep the
 * same values in scripts/sync-docs.mjs (SITE_BASE), which bakes the prefix into
 * the generated markdown links.
 */
const site = process.env.SITE_URL || 'https://thapakazi.github.io';
const base = process.env.SITE_BASE || '/kutto_kodalo';
const repo = process.env.SITE_GITHUB_REPO || 'thapakazi/kutto_kodalo';

export default defineConfig({
    site,
    base,
    trailingSlash: 'always',
    build: { format: 'directory' },
    integrations: [
        starlight({
            title: 'kutto_kodalo',
            description:
                'A self-documenting bash and zsh configuration: 32 modules, every function ' +
                'documented from its own source.',
            customCss: ['./src/styles/theme.css'],
            social: [
                { icon: 'github', label: 'GitHub', href: `https://github.com/${repo}` },
            ],
            // The reference pages are generated; an "edit this page" link would
            // point a reader at a file they must not touch.
            editLink: undefined,
            lastUpdated: false,
            credits: false,
            expressiveCode: {
                themes: ['vitesse-dark', 'vitesse-light'],
                styleOverrides: {
                    borderRadius: '2px',
                    borderColor: 'var(--sl-color-hairline)',
                    codeBackground: 'var(--kk-code-bg)',
                    codeFontFamily: 'var(--kk-mono)',
                    codeFontSize: '0.8125rem',
                    codeLineHeight: '1.6',
                    frames: {
                        shadowColor: 'transparent',
                        editorTabBarBackground: 'var(--kk-surface)',
                        terminalBackground: 'var(--kk-code-bg)',
                        terminalTitlebarBackground: 'var(--kk-surface)',
                    },
                },
            },
            sidebar: [
                {
                    label: 'Start here',
                    items: [
                        { label: 'Overview', link: '/' },
                        { label: 'Function browser', link: '/functions/' },
                        { label: 'Conventions', link: '/conventions/' },
                    ],
                },
                {
                    label: 'Module reference',
                    items: [{ autogenerate: { directory: 'reference' } }],
                },
            ],
            pagination: false,
        }),
    ],
});
