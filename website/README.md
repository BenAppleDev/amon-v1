# Amon Public Website

This folder contains the public-facing React site for `getamon.com`.

## Why it lives here

- It stays in the main repo so product messaging can evolve alongside the actual product direction.
- It remains fully isolated from `backend/`, `ios/`, `shared/`, and any internal or ops surfaces.
- It builds to static files, so deployment stays simple and public-safe.

## Stack

- React
- Vite
- React Router
- static output for Vercel, Netlify, or Cloudflare Pages

## Local development

```bash
cd website
npm install
npm run dev
```

## Build

```bash
cd website
npm run build
```

The output is generated in `website/dist/`.

## Deployment

For Vercel:

1. Create a project from this repo.
2. Set **Root Directory** to `website`.
3. Set the build command to `npm run build`.
4. Set the output directory to `dist`.
5. Attach `getamon.com`.

`vercel.json` includes an SPA rewrite so public routes such as `/privacy` and `/product` resolve correctly.
