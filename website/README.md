# Amon Public Website

This folder contains the public-facing website for `getamon.com`.

## Why it lives here

- It stays in the main repo so product and brand messaging can evolve alongside the real architecture.
- It remains clearly separated from `backend/`, `ios/`, `shared/`, and `tools/`.
- It is static by design, so it does not expose internal APIs or depend on internal product surfaces.

## Structure

- `index.html` — homepage
- `product/` — product and "how it works"
- `privacy/` — trust and privacy posture
- `contact/` — waitlist / contact CTA
- `faq/` — short clarifications
- `about/` — vision and company framing
- `assets/` — shared stylesheet and lightweight client-side behavior
- `vercel.json` — static hosting configuration for Vercel

## Local preview

Because this is a static site, any simple file server works. Examples:

```bash
cd website
python3 -m http.server 4321
```

Then open `http://127.0.0.1:4321`.

## Deployment

The simplest deployment path is to point a static hosting project at this folder as the site root.

For Vercel:

1. Create a new project from this repo.
2. Set the Root Directory to `website`.
3. Leave the framework preset as `Other`.
4. Leave the build command empty.
5. Leave the output directory empty so Vercel serves the folder directly.
6. Attach the custom domain `getamon.com`.

For Netlify or Cloudflare Pages, use `website/` as the publish directory and do not add a build step.
