import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Seo } from "../components/Seo";

export function NotFoundPage() {
  return (
    <>
      <Seo title="Not Found" description="This page could not be found." />
      <PageHero
        eyebrow="404"
        title="Not found."
        lede="That page is not here."
        aside={
          <Link className="button" to="/">
            Return home
          </Link>
        }
      />
    </>
  );
}