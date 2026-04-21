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

export const modeSteps = [
  {
    id: "local",
    number: "01",
    name: "Local",
    line: "Live browsing through Amon.",
    caption: "Open the real site in-app through Amon’s privacy route."
  },
  {
    id: "clean",
    number: "02",
    name: "Clean View",
    line: "Information without the site visit.",
    caption: "Amon fetches and presents the page when you mainly need the information."
  },
  {
    id: "protected",
    number: "03",
    name: "Protected Session",
    line: "A mediated live session.",
    caption: "Use the real site through a controlled remote environment."
  },
  {
    id: "workspace",
    number: "04",
    name: "Workspace",
    line: "What you keep stays local.",
    caption: "Save results, notes, and comparisons in an encrypted local workspace."
  }
];

export const modeDeepDives = [
  {
    id: "local",
    number: "01",
    name: "Local",
    summary:
      "Local is the fast, familiar browsing path. The live site opens in-app, but the request still runs through Amon’s privacy route instead of becoming a direct device-to-site connection.",
    facts: [
      {
        title: "What you do",
        text: "Search, open results, scan pages, and browse normally inside Amon."
      },
      {
        title: "What changes",
        text: "The page opens live, but the request moves through Amon’s privacy route."
      },
      {
        title: "Visibility boundary",
        text: "The local network and destination site do not see a plain direct browsing path from your device in the way they would with ordinary browsing."
      },
      {
        title: "Why choose it",
        text: "Use it when you want the fastest way to open the real site while keeping Amon’s baseline privacy layer in place."
      },
      {
        title: "What you control",
        text: "Nothing becomes saved work unless you choose to keep it in Workspace."
      }
    ]
  },
  {
    id: "clean",
    number: "02",
    name: "Clean View",
    summary:
      "Clean View is for pages where you mainly need the information. Amon fetches and presents the content directly, instead of turning the read into a conventional site visit from your own browser and device.",
    facts: [
      {
        title: "What you do",
        text: "Open a result to read, compare, quote, or extract what matters."
      },
      {
        title: "What changes",
        text: "Amon retrieves the page and presents the information in a cleaner view."
      },
      {
        title: "Visibility boundary",
        text: "The destination site sees Amon handling the retrieval, not your own device making a conventional page visit."
      },
      {
        title: "Why choose it",
        text: "Use it when you want the information without exposing every read as a live site interaction."
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
      "Protected Session is for tasks that need the real site. Amon opens that site through a controlled remote environment, so the destination interacts with Amon’s session instead of your own device directly.",
    facts: [
      {
        title: "What you do",
        text: "Use the live site when the task needs clicking, navigating, forms, or interaction with the real page."
      },
      {
        title: "What changes",
        text: "The browsing session runs through a controlled remote environment rather than from your own device."
      },
      {
        title: "Visibility boundary",
        text: "The destination site interacts with Amon’s remote session, not your own browser and device."
      },
      {
        title: "Why choose it",
        text: "Use it when Clean View is not enough and the actual live site matters."
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
        text: "Save results, notes, comparisons, summaries, and sources you want to revisit."
      },
      {
        title: "What changes",
        text: "Durable memory stays on your device instead of being turned into a server-side activity record."
      },
      {
        title: "Visibility boundary",
        text: "Saved work is locally encrypted and company-unreadable."
      },
      {
        title: "Why choose it",
        text: "Use it when the question is bigger than one session and you want to return with context intact."
      },
      {
        title: "What you control",
        text: "You decide what gets kept, and Amon cannot decrypt the local files you keep."
      }
    ]
  }
];

export const privacyPillars = [
  {
    label: "Privacy layer",
    title: "Every request goes through Amon.",
    tone: "default"
  },
  {
    label: "Protected path",
    title: "Requests can be handled locally, cleanly, or remotely.",
    tone: "accent"
  },
  {
    label: "Workspace",
    title: "Saved work stays local and encrypted.",
    tone: "strong"
  }
];

export const privacyModeMap = [
  {
    id: "local",
    name: "Local",
    detail: "The live site opens in-app through Amon’s privacy route, without mediated remote execution."
  },
  {
    id: "clean",
    name: "Clean View",
    detail: "Amon fetches and presents the page when you mainly need the information, so the destination site sees Amon handling the retrieval."
  },
  {
    id: "protected",
    name: "Protected Session",
    detail: "Amon runs the interaction through a controlled remote session, so the site interacts with that session instead of your own device."
  },
  {
    id: "workspace",
    name: "Workspace",
    detail: "Saved results, notes, and comparisons stay locally encrypted on your device and do not become server-side history."
  }
];

export const nonClaims = [
  "Not total anonymity.",
  "Not a way to make third-party accounts forget who you are.",
  "Not every identity-based workflow.",
  "Not support for every task on day one."
];

export const faqItems = [
  {
    question: "What is Amon?",
    answer:
      "Amon is a search and browsing app that routes every request through its own privacy layer. It helps you search, browse, compare, and think through decisions without collapsing your activity into one profile."
  },
  {
    question: "Is it a browser?",
    answer:
      "Amon includes browsing, but it is not just a browser. It changes how each request is handled: locally through Amon’s privacy route, cleanly as retrieved information, or through a protected remote session."
  },
  {
    question: "Is it a VPN?",
    answer:
      "Amon includes a privacy route, but it does more than a VPN. A VPN mainly protects the network path. Amon also changes how search, retrieval, live browsing, and saved work are handled."
  },
  {
    question: "Does Amon store my history?",
    answer:
      "No. Amon does not store your browsing history on its servers. What you choose to keep belongs in your local encrypted workspace, not a server-side history log."
  },
  {
    question: "What is Clean View?",
    answer:
      "Clean View is when Amon fetches and presents the information from a page without making it a conventional live site visit from your own browser and device."
  },
  {
    question: "What is Protected Session?",
    answer:
      "Protected Session is when Amon opens the real site through a controlled remote environment. It is for tasks that need the actual site while keeping your own browser and device out of the direct interaction."
  },
  {
    question: "What happens if I log into another service?",
    answer:
      "If you sign into a third-party account, that service can know who you are. Amon protects the path and your local saved work, but it cannot make identity-based services anonymous."
  },
  {
    question: "How does billing relate to browsing?",
    answer:
      "Billing authorizes access to Amon. It is not meant to become your browsing identity inside the product."
  },
  {
    question: "What is in scope at launch?",
    answer:
      "Amon is focused on public-web search, browsing, clean retrieval, protected sessions, comparison, research, and local saved work. It is not trying to cover every account-based workflow or every browser task on day one."
  }
];