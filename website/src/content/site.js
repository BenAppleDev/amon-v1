export const navLinks = [
  { to: "/", label: "Home" },
  { to: "/product", label: "Product" },
  { to: "/privacy", label: "Privacy" },
  { to: "/faq", label: "FAQ" },
  { to: "/about", label: "About" },
  { to: "/contact", label: "Contact" }
];

export const homeBelief =
  "No single system should see the whole path from what you search to what you open to what you keep.";

export const spaceLines = [
  "Where to live.",
  "What to buy.",
  "What comes next."
];

export const modeDeepDives = [
  {
    id: "local",
    number: "LIVE",
    name: "Local",
    summary:
      "Local is live browsing through Amon’s privacy route. The site opens in-app, but the request does not travel as a plain direct device-to-site connection.",
    facts: [
      {
        title: "What you do",
        text: "Open a real website, browse normally, and use the page inside Amon."
      },
      {
        title: "What changes",
        text: "The live page runs through Amon’s privacy route instead of exposing a plain direct browsing path from your device."
      },
      {
        title: "What the site sees",
        text: "The destination sees Amon-mediated traffic rather than a conventional visit straight from your device."
      },
      {
        title: "Best for",
        text: "Normal browsing when you want the real site and do not need text extraction or remote-in handling."
      }
    ]
  },
  {
    id: "clean",
    number: "TEXT",
    name: "Clean View",
    summary:
      "Clean View is text extraction. Amon fetches the page, extracts readable text, and presents the information without requiring a conventional live site visit from your device.",
    facts: [
      {
        title: "What you do",
        text: "Read an article, guide, review, or public page when you mainly need the information."
      },
      {
        title: "What changes",
        text: "Amon retrieves the page and extracts readable text instead of sending your device through a normal page load."
      },
      {
        title: "What the site sees",
        text: "The destination sees Amon handling the retrieval, not your own device making the visit."
      },
      {
        title: "Best for",
        text: "Reading, research, comparison, and pages where the content matters more than interaction."
      }
    ]
  },
  {
    id: "protected",
    number: "REMOTE",
    name: "Protected Session",
    summary:
      "Protected Session is remote-in browsing. Amon opens the real site from an Amon-controlled machine, and you interact with that remote session instead of exposing your own device directly.",
    facts: [
      {
        title: "What you do",
        text: "Use a site that requires live navigation, dynamic pages, forms, or interaction."
      },
      {
        title: "What changes",
        text: "The browsing session runs from Amon’s controlled remote environment rather than directly from your device."
      },
      {
        title: "What the site sees",
        text: "The destination interacts with Amon’s remote session, not your own browser and device."
      },
      {
        title: "Best for",
        text: "Dynamic public sites, cookie-gated public pages, and cases where Clean View is not enough."
      }
    ]
  },
  {
    id: "workspace",
    number: "SAVE",
    name: "Workspace",
    summary:
      "Workspace is not a browsing mode. It is the local ownership layer where saved sources, notes, comparisons, and research artifacts live encrypted on your device.",
    facts: [
      {
        title: "What you do",
        text: "Save sources, notes, summaries, comparisons, and research artifacts you want to revisit."
      },
      {
        title: "What changes",
        text: "Durable memory stays on your device instead of becoming a server-side activity record."
      },
      {
        title: "What Amon can read",
        text: "Amon cannot decrypt your local workspace files."
      },
      {
        title: "Best for",
        text: "Questions that become decisions and need continuity without becoming server-side history."
      }
    ]
  }
];

export const privacyModeMap = [
  {
    id: "local",
    name: "Local",
    detail: "The live site opens in-app through Amon’s privacy route, without remote execution."
  },
  {
    id: "clean",
    name: "Clean View",
    detail: "Amon retrieves the page and extracts readable text when you mainly need the information."
  },
  {
    id: "protected",
    name: "Protected Session",
    detail: "Amon opens the site from a controlled remote machine so the destination does not interact with your device directly."
  },
  {
    id: "workspace",
    name: "Workspace",
    detail: "Saved work stays locally encrypted and company-unreadable on your device."
  }
];

export const privacyMechanisms = [
  {
    title: "Encrypted transport",
    text: "Amon browsing runs through an app-level privacy route using encrypted transport."
  },
  {
    title: "Separate session identity",
    text: "Billing authorizes access, but browsing and request sessions use separate internal identities."
  },
  {
    title: "No durable inquiry spine",
    text: "Amon does not store query text, result sets, destination URLs, page bodies, compare outputs, research outputs, protected-session content, or workspace data as server-side history."
  },
  {
    title: "Metadata-only operations",
    text: "Operational systems see health, quota, policy, and abuse-prevention metadata—not readable user content."
  },
  {
    title: "Company-unreadable workspace",
    text: "Saved work is encrypted locally on your device. Amon cannot decrypt it."
  }
];

export const policyBoundaries = [
  {
    title: "Policy without profiling",
    text: "Moderation and access controls are based on request, destination, mode, and risk—not long-term behavioral profiles."
  },
  {
    title: "Restricted requests",
    text: "Amon will not fulfill certain categories of requests. A detailed launch policy will define what is restricted and why."
  },
  {
    title: "No content inspection path",
    text: "The product is designed without break-glass content viewing or readable operator access to user sessions and saved work."
  }
];

export const nonClaims = [
  "Not total anonymity.",
  "Not a way to make third-party accounts forget who you are."
];

export const faqItems = [
  {
    question: "What is Amon?",
    answer:
      "Amon is a search and browsing app that routes every request through its own privacy layer. From there, you can browse live, extract readable text, remote into a protected session, or save work locally."
  },
  {
    question: "Is it a browser?",
    answer:
      "Amon includes browsing, but it is not just a browser. It changes how each request is handled: live through Amon’s privacy route, as extracted text, or through a remote Amon session."
  },
  {
    question: "Is it a VPN?",
    answer:
      "Amon includes an app-level privacy route, but it does more than a VPN. A VPN protects the network path. Amon also changes how search, text extraction, remote browsing, and saved work are handled."
  },
  {
    question: "Does Amon store my history?",
    answer:
      "No. Amon does not store your browsing history on its servers. What you choose to keep belongs in your local encrypted workspace, not a server-side history log."
  },
  {
    question: "Can a query be tied back to me?",
    answer:
      "Amon is designed not to retain a durable query-to-account record. Because query text, result sets, destination URLs, and page content are not stored as server-side history, there is no durable inquiry spine to re-identify from."
  },
  {
    question: "What is Clean View?",
    answer:
      "Clean View is text extraction. Amon retrieves the page, extracts readable content, and presents the information without making it a conventional live site visit from your device."
  },
  {
    question: "What is Protected Session?",
    answer:
      "Protected Session is remote-in browsing. Amon opens the real site from a controlled Amon machine, and you interact through that remote session instead of exposing your own device directly."
  },
  {
    question: "What happens if I log into another service?",
    answer:
      "If you sign into a third-party account, that service can know who you are. Amon can protect the path and your local saved work, but it cannot make identity-based services anonymous."
  },
  {
    question: "How does billing relate to browsing?",
    answer:
      "Billing authorizes access to Amon. It is separated from browsing and request session identity so billing does not become the internal browsing identity."
  },
  {
    question: "What is in scope at launch?",
    answer:
      "Amon is focused on public-web search, browsing, text extraction, protected sessions, comparison, research, and local saved work. It is not trying to cover every identity-based workflow on day one."
  }
];