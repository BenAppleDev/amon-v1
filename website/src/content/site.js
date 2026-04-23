export const navLinks = [
  { to: "/", label: "Home" },
  { to: "/product", label: "Product" },
  { to: "/privacy", label: "Privacy" },
  { to: "/security", label: "Security" },
  { to: "/faq", label: "FAQ" },
  { to: "/about", label: "About" },
  { to: "/contact", label: "Contact" }
];

export const homeBelief =
  "Inquiry should come before identification.";

export const spaceLines = [
  "Ask before you're defined.",
  "Go deeper before you're tagged.",
  "Step forward when you choose."
];

export const homeBoundaryCards = [
  {
    title: "Inquiry before identity",
    text:
      "Amon is built for the part before a question becomes a profile. It keeps the inquiry detached from your identity until the task truly requires more."
  },
  {
    title: "Least exposing path first",
    text:
      "Amon starts with the path that reveals the least about you for the task: live through the privacy route, cleanly as extracted text, or through a protected remote session."
  },
  {
    title: "Boundary made explicit",
    text:
      "If a page can stay detached, it stays detached. If the site needs interaction or identity, Amon makes that boundary clear before you cross it."
  }
];

export const productBoundaryCards = [
  {
    title: "What Amon preserves",
    text:
      "Amon keeps the inquiry detached before the task requires identity. Search, reading, comparison, and research do not have to become one readable signal about you right away."
  },
  {
    title: "What Amon changes",
    text:
      "When a page needs more than clean reading, Amon can keep the interaction mediated through its privacy route or through a protected remote session."
  },
  {
    title: "When the boundary moves",
    text:
      "Some tasks eventually require you to identify yourself. Amon does not hide that moment. It makes the tradeoff explicit so you choose when to step forward."
  }
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
        title: "What this preserves",
        text: "Local keeps the request mediated before you identify yourself or move into a more exposing workflow."
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
        title: "What this preserves",
        text: "Clean View keeps the read detached when you only need the information, not a live relationship with the site."
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
        title: "What this preserves",
        text: "Protected Session keeps your own browser and device out of the direct interaction when the live site matters."
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
        title: "What this preserves",
        text: "Workspace lets a question become a project without turning your saved work into centralized service-side memory."
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
    title: "Inquiry before identity",
    text:
      "Amon is designed to maximize anonymity where possible, preserve it as long as possible, and make the tradeoff explicit when a task requires more exposure."
  },
  {
    title: "Least exposing path first",
    text:
      "Amon is designed to preserve anonymity where possible, then recommend a more capable path only when the task needs it."
  },
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
      "Amon is a search and browsing app built to keep your questions from becoming a profile. It separates inquiry from identity, starts with the least exposing path, and makes the boundary clear when a task requires more exposure."
  },
  {
    question: "Why not just use private mode?",
    answer:
      "Private mode mostly clears the trail on your device. Amon is built for the part before your question becomes a profile: search, reading, comparison, and deeper research through paths that reduce exposure and linkage."
  },
  {
    question: "How long does Amon keep me anonymous?",
    answer:
      "Amon is designed to maximize anonymity where possible, preserve it as long as possible, and make the tradeoff explicit when a task requires more exposure. If a page can be handled cleanly, it can stay detached. If the site needs interaction or identity, Amon makes that boundary clear."
  },
  {
    question: "When does that protection change?",
    answer:
      "The boundary changes when the task itself needs more exposure: for example, logging into a third-party account, submitting a form with personal details, or using a service that already knows who you are."
  },
  {
    question: "Will Amon tell me when I am about to expose myself?",
    answer:
      "That is the goal. Amon is designed to recommend the least exposing path first, then make it clear when a task needs live interaction, remote handling, or identity."
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

export const securityLaunchFeatures = [
  {
    title: "Secure account access",
    text: "Access to Amon is authenticated with Sign in with Apple. Billing authorizes access, but it is separated from the internal browsing and request identity used inside the product."
  },
  {
    title: "Encrypted transport",
    text: "Traffic between the app and Amon is encrypted in transit using modern HTTPS and TLS 1.3. On iOS, App Transport Security is enforced so insecure network connections are not the default."
  },
  {
    title: "Local encrypted workspace",
    text: "Saved work stays locally encrypted on your device. Amon cannot decrypt your local workspace files. Workspace access can be protected with Face ID, Touch ID, or device passcode."
  },
  {
    title: "Minimal server retention",
    text: "Amon is designed not to keep durable server-side history of what you searched, opened, extracted, or saved. Operational systems are limited to metadata needed for health, quotas, abuse prevention, and policy enforcement."
  },
  {
    title: "Isolated handling paths",
    text: "Different product paths have different protections. Search is brokered, Clean View is retrieved and extracted through Amon, Protected Session runs through a controlled remote environment, and Workspace remains local."
  }
];

export const securityLayers = [
  {
    number: "01",
    title: "Access",
    text: "Amon uses Sign in with Apple for account access at launch. After authentication, the product uses separate internal session handling so billing identity does not become browsing identity."
  },
  {
    number: "02",
    title: "Transport",
    text: "App traffic moves through encrypted transport channels protected by TLS 1.3 and platform-level transport controls on iOS."
  },
  {
    number: "03",
    title: "Request handling",
    text: "Search, Clean View, and Protected Session are handled through scoped product paths rather than one universal trust path. Protected Session is isolated and ephemeral, not a broad permanent browsing context."
  },
  {
    number: "04",
    title: "Workspace",
    text: "Workspace is where saved results, notes, and comparisons live. That data remains locally encrypted on device, with optional biometric or passcode gating on top of workspace encryption."
  },
  {
    number: "05",
    title: "Operations",
    text: "Operational systems are designed around metadata rather than readable content. Least privilege and limited observability are part of the architecture, not just the policy language."
  }
];

export const securityRetentionList = [
  "No durable server-side records of query text.",
  "No durable server-side search result sets.",
  "No durable server-side records of destination URLs tied to inquiry history.",
  "No durable server-side Clean View page bodies.",
  "No durable server-side Protected Session content.",
  "No workspace contents stored on Amon servers."
];

export const securityFoundations = [
  {
    label: "Transport",
    title: "TLS 1.3",
    text: "Used to encrypt traffic in transit between the app and Amon services.",
    emphasis: true
  },
  {
    label: "iOS",
    title: "App Transport Security",
    text: "Used on iOS to require secure network connections by default."
  },
  {
    label: "Local secrets",
    title: "iOS Keychain",
    text: "Used to protect sensitive local key material."
  },
  {
    label: "Local unlock",
    title: "Face ID / Touch ID / Passcode",
    text: "Used to gate access to local encrypted workspace data on device."
  },
  {
    label: "Mobile",
    title: "OWASP MASVS",
    text: "Used as a guide for mobile application security controls."
  },
  {
    label: "Backend",
    title: "OWASP ASVS",
    text: "Used as a guide for backend and service-side security controls."
  },
  {
    label: "Access",
    title: "Least privilege",
    text: "Internal systems and operator tooling should only have the minimum access necessary to perform operational tasks."
  },
  {
    label: "Operations",
    title: "Metadata-only observability",
    text: "Operational visibility is designed around metadata rather than readable user content.",
    emphasis: true
  },
  {
    label: "Architecture",
    title: "NIST SP 800-207 alignment",
    text: "Used as a reference point for zero-trust architecture principles and terminology."
  }
];

export const securityRoadmapSoon = [
  "Encrypted export and import for workspace data.",
  "Independent penetration testing.",
  "Public vulnerability reporting channel.",
  "Expanded technical security documentation.",
  "Access audit logging for internal tools and stronger operator controls."
];

export const securityRoadmapLater = [
  "SOC 2 Type I.",
  "SOC 2 Type II.",
  "Additional formal trust and compliance work as the product matures.",
  "More explicit external mapping of the architecture to zero-trust guidance over time."
];