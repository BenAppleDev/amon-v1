import { useEffect } from "react";

const defaultTitle = "Amon | Private by default. Deeper when needed.";
const defaultDescription =
  "Amon routes search and browsing through different privacy paths so no single system sees everything you search, open, and keep.";

export function Seo({ title, description = defaultDescription }) {
  useEffect(() => {
    document.title = title ? `${title} | Amon` : defaultTitle;

    const meta = document.querySelector('meta[name="description"]');
    if (meta) {
      meta.setAttribute("content", description);
    }
  }, [description, title]);

  return null;
}