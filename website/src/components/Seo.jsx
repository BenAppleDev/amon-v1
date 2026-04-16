import { useEffect } from "react";

const defaultTitle = "Amon | Private by default. Deeper when needed.";
const defaultDescription =
  "Amon is a private decision environment for searching, browsing, and thinking through meaningful questions online.";

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
