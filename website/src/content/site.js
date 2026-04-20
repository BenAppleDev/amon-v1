export const navLinks = [
  { to: "/", label: "Home" },
  { to: "/product", label: "Product" },
  { to: "/privacy", label: "Privacy" },
  { to: "/faq", label: "FAQ" },
  { to: "/about", label: "About" },
  { to: "/contact", label: "Contact" }
];

export const homeBelief =
  "No single system should get to see everything someone searches, opens, and keeps.";

export const spaceLines = [
  "Space to explore.",
  "Space to compare.",
  "Space to think."
];

export const modeSteps = [
  {
    id: "search",
    number: "01",
    name: "Search / Browse",
    line: "Start search through Amon.",
    caption: "Begin from a familiar search and browsing layer."
  },
  {
    id: "clean",
    number: "02",
    name: "Clean View",
    line: "Open pages as clean retrieval.",
    caption: "Read what you need without a conventional direct visit."
  },
  {
    id: "protected",
    number: "03",
    name: "Protected Session",
    line: "Use a mediated live session.",
    caption: "Use the real site through a controlled remote session."
  },
  {
    id: "workspace",
    number: "04",
    name: "Workspace",
    line: "Keep what matters locally.",
    caption: "Save results and notes in a workspace that stays with you."
  }
];

export const modeDeepDives = [
  {
    id: "search",
    number: "01",
    name: "Search / Browse",
    summary:
      "This is the familiar starting layer. You search, open results, and begin inquiry the normal way, but the request starts with Amon instead of the default stack tied directly to your device.",
    facts: [
      {
        title: "What you do",
        text: "Search, scan results, open sources, and orient around the question."
      },
      {
        title: "What changes",
        text: "Queries go through Amon instead of going straight from your device into the default search stack."
      },
      {
        title: "Visibility boundary",
        text: "The opening of the inquiry does not collapse immediately into one default stack tied directly to your device identity."
      },
      {
        title: "Why choose it",
        text: "Use it when you want the familiar start of search and browsing with a better boundary from the first query."
      },
      {
        title: "What you control",
        text: "Nothing has to be saved until you decide it belongs in Workspace."
      }
    ]
  },
  {
    id: "clean",
    number: "02",
    name: "Clean View",
    summary:
      "Clean View is for pages where you mainly want the information. Amon fetches and presents the content directly instead of turning it into a conventional page visit from your own browser and device.",
    facts: [
      {
        title: "What you do",
        text: "Open a result to read, compare, quote, or extract what matters."
      },
      {
        title: "What changes",
        text: "Amon retrieves the page and presents the information directly."
      },
      {
        title: "Visibility boundary",
        text: "The destination site sees Amon retrieving the page, not a normal visit from your browser and device."
      },
      {
        title: "Why choose it",
        text: "Use it when you want the information without exposing every read as a conventional site visit."
      },
      {
        title: "What you control",
        text: "You decide whether anything from that page gets saved into your local Workspace."
      }
    ]
  },
  {
    id: "protected",
    number: "03",
    name: "Protected Session",
    summary:
      "Protected Session is for tasks that require the real site itself. Amon opens that site through a controlled remote environment, so you interact through Amon instead of exposing your own browser and device directly.",
    facts: [
      {
        title: "What you do",
        text: "Use the live site when the task needs clicking, navigating, or interacting with the real page."
      },
      {
        title: "What changes",
        text: "The browsing session runs through a controlled remote host rather than directly from your device."
      },
      {
        title: "Visibility boundary",
        text: "The destination site interacts with that remote environment, not your own browser and device."
      },
      {
        title: "Why choose it",
        text: "Use it when Clean View is not enough and the actual site matters."
      },
      {
        title: "What it protects",
        text: "It keeps your own device footprint out of the direct interaction with the destination site."
      }
    ]
  },
  {
    id: "workspace",
    number: "04",
    name: "Workspace",
    summary:
      "Workspace is where saved results, notes, comparisons, and ongoing inquiry live. That memory stays locally encrypted on your device instead of becoming a server-side history profile.",
    facts: [
      {
        title: "What you do",
        text: "Save results, notes, comparisons, and return to the work later."
      },
      {
        title: "What changes",
        text: "Durable memory stays on your device instead of being turned into a server-side activity record."
      },
      {
        title: "Visibility boundary",
        text: "Saved work stays locally encrypted and does not become centralized service-side history."
      },
      {
        title: "Why choose it",
        text: "Use it when the question is bigger than one session and you want to return with context intact."
      },
      {
        title: "What you control",
        text: "Your saved work stays under your control, on your device."
      }
    ]
  }
];

export const privacyPillars = [
  {
    label: "Service posture",
    title: "No single system sees the whole inquiry.",
    tone: "default"
  },
  {
    label: "Protected path",
    title: "Live site access can be mediated through a remote session.",
    tone: "accent"
  },
  {
    label: "Workspace",
    title: "Saved work stays local on your device.",
    tone: "strong"
  }
];

export const privacyModeMap = [
  {
    id: "search",
    name: "Search / Browse",
    detail: "Queries start through Amon, and we do not keep a server-side browsing history."
  },
  {
    id: "clean",
    name: "Clean View",
    detail: "Pages are fetched and presented directly. The destination site sees Amon retrieving the page, not a normal visit from your device."
  },
  {
    id: "protected",
    name: "Protected Session",
    detail: "Live browsing runs through a controlled remote session. The site interacts with that remote environment instead of your browser and device."
  },
  {
    id: "workspace",
    name: "Workspace",
    detail: "Saved results, notes, and comparisons stay locally encrypted on your device and do not become server-side history."
  }
];

export const nonClaims = [
  "Not total anonymity.",
  "Not every website or account-based workflow.",
  "Not a browser replacement for everything.",
  "Not support for every task today."
];

export const faqItems = [
  {
    question: "What is Amon?",
    answer:
      "Amon is a search and browsing app for meaningful questions and real decisions. It routes requests through different privacy paths so no single system sees everything you search, open, and keep."
  },
  {
    question: "Is it a browser?",
    answer:
      "Not in the usual sense. Amon includes search and browsing, but it is not trying to replace every browser use case. It routes requests through local, clean, and protected paths, then keeps saved work local."
  },
  {
    question: "Is it a VPN?",
    answer:
      "Amon uses VPN-like routing and remote infrastructure as part of its privacy model, but it is not just a consumer VPN. It changes how search, clean retrieval, mediated browsing, and saved work are handled end to end."
  },
  {
    question: "Does Amon store my history?",
    answer:
      "We do not store your browsing history. Saved results, notes, and comparisons belong in your local workspace, not a server-side history log."
  },
  {
    question: "What is Protected Session?",
    answer:
      "Protected Session is when Amon opens the real site through a controlled remote host and lets you use it through that session. It is for tasks that need the actual site while keeping your own device and browser from being exposed directly."
  },
  {
    question: "What is in scope today?",
    answer:
      "Today Amon is focused on public-web search and browsing. It is not trying to cover every website, every account flow, or every browser task on day one."
  }
];
