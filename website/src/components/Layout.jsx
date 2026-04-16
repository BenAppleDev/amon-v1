import { useEffect, useState } from "react";
import { Link, NavLink, Outlet, useLocation } from "react-router-dom";
import { navLinks } from "../content/site";
import { BrandMark } from "./BrandMark";

function ScrollToTop() {
  const location = useLocation();

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  }, [location.pathname]);

  return null;
}

export function SiteLayout() {
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    setMenuOpen(false);
  }, [location.pathname]);

  return (
    <>
      <ScrollToTop />
      <div className="site-wrap">
        <header className="site-header">
          <div className="frame site-header-inner">
            <Link className="brand" to="/">
              <BrandMark />
              <span className="brand-word">Amon</span>
            </Link>

            <button
              className="nav-toggle"
              type="button"
              aria-expanded={menuOpen}
              aria-label="Toggle navigation"
              onClick={() => setMenuOpen((open) => !open)}
            >
              Menu
            </button>

            <nav className={`site-nav${menuOpen ? " is-open" : ""}`} aria-label="Primary">
              {navLinks.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.to === "/"}
                  className={({ isActive }) => (isActive ? "is-active" : undefined)}
                >
                  {item.label}
                </NavLink>
              ))}
            </nav>

            <div className="site-actions">
              <Link className="button button-secondary" to="/product">
                Read product
              </Link>
              <Link className="button" to="/contact">
                Request access
              </Link>
            </div>
          </div>
        </header>

        <main>
          <Outlet />
        </main>

        <footer className="site-footer">
          <div className="frame site-footer-inner">
            <div>
              <Link className="brand brand-footer" to="/">
                <BrandMark />
                <span className="brand-word">Amon</span>
              </Link>
              <p className="footer-copy">
                A place to think through things online.
              </p>
            </div>

            <div className="footer-links">
              {navLinks.map((item) => (
                <Link key={item.to} to={item.to}>
                  {item.label}
                </Link>
              ))}
              <a href="mailto:hello@getamon.com?subject=Request%20access%20to%20Amon">
                hello@getamon.com
              </a>
            </div>
          </div>
        </footer>
      </div>
    </>
  );
}
