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
  "There should be a place online where people can think through things without being turned into a profile.";

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
    line: "Start the way you normally would.",
    caption: "The familiar layer: search, open, and read as you normally would.",
    detail: "Search, open pages, and read the public web the same basic way you would in Google or Safari."
  },
  {
    id: "clean",
    number: "02",
    name: "Clean View",
    line: "Get the information without the site visit.",
    caption: "Extract what you need without handing the destination site your visit.",
    detail: "Pull the information you need into a calmer reading surface without directly handing the destination site your visit."
  },
  {
    id: "protected",
    number: "03",
    name: "Protected Session",
    line: "Use the real site through Amon.",
    caption: "When you need the actual site, Amon routes that browsing through a controlled remote host.",
    detail:
      "When you need the real website, Amon can route that browsing through a controlled remote host instead of exposing your own device and identity directly."
  },
  {
    id: "workspace",
    number: "04",
    name: "Workspace",
    line: "Return to work that stays with you.",
    caption: "Save what matters locally, encrypted on your device.",
    detail: "Return to your work later. What you save stays locally encrypted on your device, not in a server-side history profile."
  }
];

export const privacyPillars = [
  {
    label: "Service posture",
    title: "Minimize durable query and page content.",
    tone: "default"
  },
  {
    label: "Deep remote",
    title: "Use remote access only when the task needs it.",
    tone: "accent"
  },
  {
    label: "Workspace",
    title: "Keep saved work local by default.",
    tone: "strong"
  }
];

export const nonClaims = [
  "Not total anonymity.",
  "Not every website or workflow.",
  "Not a browser replacement.",
  "Not universal live-site support."
];

export const faqItems = [
  {
    question: "What is Amon?",
    answer:
      "Amon is a place to search, browse, compare options, and think through meaningful decisions online without turning that inquiry into a profile. It is built for normal people making real choices, not just privacy specialists."
  },
  {
    question: "Is it a browser?",
    answer:
      "Not in the replace-everything sense. Browsing is part of it, but Amon is a workflow for inquiry."
  },
  {
    question: "Is it a VPN?",
    answer:
      "Amon uses VPN-like routing and remote infrastructure as part of how it protects your browsing, but it is not just a consumer VPN. It adds more privacy architecture on top so your searches and browsing stay yours end to end."
  },
  {
    question: "Does Amon store my history?",
    answer:
      "We do not store your browsing history. What you choose to save belongs in your local workspace, not in a server-side history profile."
  },
  {
    question: "What is Protected Session?",
    answer:
      "Protected Session lets you control a remote host through Amon when you need the actual website. That host does the browsing for you, which helps avoid leaving your own device and browser footprint directly on the destination site."
  },
  {
    question: "What is in scope today?",
    answer:
      "Amon is focused on the public web right now. Some tasks are in scope today and some are not, because the product is being built deliberately rather than as a universal replacement for every browser and every account-based workflow."
  }
];
