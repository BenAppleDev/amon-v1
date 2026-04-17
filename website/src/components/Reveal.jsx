import { useEffect, useRef } from "react";

export function Reveal({ as: Tag = "div", className = "", delay = 0, children, ...props }) {
  const ref = useRef(null);

  useEffect(() => {
    const node = ref.current;
    if (!node) {
      return undefined;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            node.classList.add("is-visible");
            observer.disconnect();
          }
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <Tag ref={ref} className={`reveal ${className}`.trim()} style={{ "--delay": `${delay}ms` }} {...props}>
      {children}
    </Tag>
  );
}
