export const navLinks = [
  { to: "/", label: "Home" },
  { to: "/product", label: "Product" },
  { to: "/privacy", label: "Privacy" },
  { to: "/faq", label: "FAQ" },
  { to: "/about", label: "About" },
  { to: "/contact", label: "Contact" }
];

export const shiftThenLines = [
  "You searched.",
  "You clicked.",
  "You read.",
  "You moved on."
];

export const shiftNowLines = [
  "Now every question gets recorded.",
  "Interpreted.",
  "Connected.",
  "Folded into a profile."
];

export const everydayDecisions = [
  "Where to live",
  "What to buy",
  "Whether to change jobs",
  "What decision to make next"
];

export const homeBelief =
  "No single system should get to see everything someone searches, opens, and keeps.";

export const homeMechanics = [
  {
    number: "01",
    title: "Search starts with Amon",
    detail: "Your inquiry does not begin in the default search stack tied directly to your device identity."
  },
  {
    number: "02",
    title: "Some pages can be handled cleanly",
    detail: "Amon can broker retrieval and present the information without turning it into a conventional site visit from you."
  },
  {
    number: "03",
    title: "Some live browsing can be mediated",
    detail: "When the task needs the real site, Amon can route that interaction through a more controlled remote environment."
  },
  {
    number: "04",
    title: "What you keep stays with you",
    detail: "Saved work lives locally in an encrypted workspace instead of becoming centralized service-side history."
  }
];

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
    line: "Search starts with Amon.",
    caption: "Start from a familiar search and browsing layer, but not from the default stack tied directly to your device.",
    detail: "Search begins through Amon instead of the default search stack that would normally see the entire inquiry tied directly to your device identity."
  },
  {
    id: "clean",
    number: "02",
    name: "Clean View",
    line: "Some pages can be fetched cleanly.",
    caption: "Amon can retrieve and present the information without handing the destination site a conventional visit.",
    detail: "When you only need the information, Amon can broker the retrieval and present it cleanly instead of sending your device through a normal page load."
  },
  {
    id: "protected",
    number: "03",
    name: "Protected Session",
    line: "Some live browsing can be mediated.",
    caption: "When you need the actual site, Amon can broker that interaction through a controlled remote environment.",
    detail:
      "When the task needs the real website, Amon can mediate that browsing through a controlled remote environment rather than exposing your own device and browser directly."
  },
  {
    id: "workspace",
    number: "04",
    name: "Workspace",
    line: "What you keep stays local.",
    caption: "Save sources and notes in a workspace that lives with you, not in service-side history.",
    detail: "What you choose to keep stays locally encrypted on your device so saved work does not become part of a centralized server-side profile."
  }
];

export const privacyPillars = [
  {
    label: "Service posture",
    title: "No single system sees the whole inquiry.",
    tone: "default"
  },
  {
    label: "Deep remote",
    title: "Use mediated remote access only when the task needs it.",
    tone: "accent"
  },
  {
    label: "Workspace",
    title: "Keep saved work local on your device.",
    tone: "strong"
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
      "Amon is a search and browsing product for meaningful inquiry. It helps you search, compare options, open pages, and think through real decisions in a way that keeps any one system from seeing everything you do."
  },
  {
    question: "Is it a browser?",
    answer:
      "Amon includes browsing, but it is not trying to replace every browser use case. It is a system that decides how each search, page open, and saved result should be handled."
  },
  {
    question: "Is it a VPN?",
    answer:
      "Amon uses VPN-like routing and remote infrastructure as part of its privacy model, but it is not just a consumer VPN. It changes how search, retrieval, mediated browsing, and saved work are handled end to end."
  },
  {
    question: "Does Amon store my history?",
    answer:
      "We do not store your browsing history. What you choose to keep belongs in your local workspace, not a server-side history log."
  },
  {
    question: "What is Protected Session?",
    answer:
      "Protected Session is the mode Amon uses when you need the real site, not just extracted information. A remote host does the browsing on your behalf so the destination site does not see your own device and browser directly."
  },
  {
    question: "What is in scope today?",
    answer:
      "Amon is focused on the public web. It is not trying to replace every browser task or every account-based workflow on day one, so some tasks are in scope now and others are not."
  }
];
