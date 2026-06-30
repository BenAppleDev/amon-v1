export const navLinks = [
  { to: "/", label: "Home" },
  { to: "/product", label: "Product" },
  { to: "/privacy", label: "Privacy" },
  { to: "/security", label: "Security" },
  { to: "/faq", label: "FAQ" },
  { to: "/about", label: "About" },
  { to: "/contact", label: "Contact" }
];

export const homeHowItWorks = [
  {
    title: "Ask",
    text: "Search the web from Amon."
  },
  {
    title: "Open",
    text: "Open results through Amon."
  },
  {
    title: "Choose",
    text: "Use Clean View or Protected Session when a page needs a different privacy path."
  },
  {
    title: "Save",
    text: "Keep notes, sources, and comparisons in a local encrypted workspace."
  }
];

export const privacyModeCards = [
  {
    id: "open-site",
    name: "Open Site",
    summary: "Use the real page through Amon when normal browsing is enough.",
    detail: "For normal browsing when a direct page view is enough."
  },
  {
    id: "clean-view",
    name: "Clean View",
    summary: "Read the page as extracted content when you only need the information.",
    detail: "For reading and extracting information without loading the full live site experience."
  },
  {
    id: "protected-session",
    name: "Protected Session",
    summary: "Use a protected Amon-controlled session when a site needs interaction.",
    detail: "For interactive sites that need a stronger separation layer."
  },
  {
    id: "workspace",
    name: "Workspace",
    summary: "Save sources, notes, comparisons, and research privately on your device.",
    detail: "For saving sources, notes, comparisons, and research privately on your device."
  }
];

export const trustPrinciples = [
  {
    title: "Account access",
    text: "Your account authorizes access to Amon."
  },
  {
    title: "Session handling",
    text: "Your browsing session handles the task separately from saved work."
  },
  {
    title: "Selected path",
    text: "Destination sites see the selected Amon path, not your entire research context."
  },
  {
    title: "Local workspace",
    text: "Saved research stays encrypted on your device."
  }
];

export const ordinaryUseCases = [
  "Comparing neighborhoods or apartments",
  "Researching health, legal, or financial questions",
  "Planning travel",
  "Comparing products or services",
  "Reading sensitive topics",
  "Saving research for later without creating a server-side memory trail"
];

export const productSections = [
  {
    id: "open-site",
    name: "Open Site",
    description: "Use the real page through Amon when normal browsing is enough.",
    detail:
      "When the full page is useful, Amon keeps the request in its own path while you browse the real site."
  },
  {
    id: "clean-view",
    name: "Clean View",
    description:
      "Amon retrieves the page, extracts readable content, and presents the information without requiring a full live site visit from your device.",
    detail:
      "It is built for reading, research, and comparison when you want the information without loading the full site experience."
  },
  {
    id: "protected-session",
    name: "Protected Session",
    description:
      "For sites that need interaction, Amon can run the session in a protected environment so the destination site interacts with an Amon-controlled session rather than directly with your device.",
    detail:
      "This is the path for sites that need forms, interaction, or a stronger separation layer."
  },
  {
    id: "workspace",
    name: "Workspace",
    description:
      "Save sources, notes, comparisons, and research locally on your device. Durable research should belong to the user, not become a readable server-side profile.",
    detail:
      "What you choose to keep lives in your encrypted local workspace rather than as a server-side memory trail."
  }
];

export const privacyHighlights = [
  {
    title: "No durable query-to-account record",
    text:
      "Amon does not store query text, result sets, destination URLs, page bodies, protected-session content, or workspace data as server-side history."
  },
  {
    title: "Company-unreadable saved work",
    text: "What you save stays locally encrypted on your device. Amon cannot decrypt your local workspace files."
  },
  {
    title: "Metadata-only operations",
    text:
      "Operations are designed around health, quota, policy, and abuse-prevention metadata, not readable user content."
  }
];

export const privacyMechanismsPublic = [
  {
    title: "Separate layers",
    text: "Your account authorizes access, your browsing uses separate session handling, and saved work stays on your device."
  },
  {
    title: "Minimal retention",
    text: "Amon is designed to avoid turning search terms, opened pages, and research artifacts into durable identity-linked history."
  },
  {
    title: "Clear limits",
    text: "If a task eventually requires you to identify yourself to a destination site, Amon can protect the path but it does not claim to erase that relationship."
  }
];

export const privacyMatrixColumns = [
  { id: "account", label: "Account / billing identity" },
  { id: "session", label: "Amon browsing/session layer" },
  { id: "site", label: "Destination site" },
  { id: "workspace", label: "Local device workspace" },
  { id: "ops", label: "Operations / diagnostics" }
];

export const privacyMatrixRows = [
  {
    label: "Account identity",
    values: {
      account: { state: "visible", detail: "Used for access and billing." },
      session: { state: "limited", detail: "Separated from request handling." },
      site: { state: "not-stored", detail: "Not sent by default." },
      workspace: { state: "local-only", detail: "Only if you save account notes locally." },
      ops: { state: "metadata-only", detail: "Access and quota metadata only." }
    }
  },
  {
    label: "Query text",
    values: {
      account: { state: "not-stored", detail: "No durable query-to-account history." },
      session: { state: "limited", detail: "Handled to fulfill the request." },
      site: { state: "limited", detail: "Depends on the selected path." },
      workspace: { state: "local-only", detail: "Only if you choose to save it." },
      ops: { state: "metadata-only", detail: "Operational metadata, not readable query logs." }
    }
  },
  {
    label: "Opened URLs",
    values: {
      account: { state: "not-stored", detail: "Not kept as durable account history." },
      session: { state: "limited", detail: "Used to route the request." },
      site: { state: "visible", detail: "Sees the page request it receives." },
      workspace: { state: "local-only", detail: "Saved only when you keep a source." },
      ops: { state: "metadata-only", detail: "Operational metadata only." }
    }
  },
  {
    label: "Page content",
    values: {
      account: { state: "not-stored", detail: "Not retained as account history." },
      session: { state: "limited", detail: "Handled only as needed for the selected mode." },
      site: { state: "visible", detail: "The destination serves the page it controls." },
      workspace: { state: "local-only", detail: "Stored locally if you save notes or excerpts." },
      ops: { state: "metadata-only", detail: "Diagnostics are not designed around readable content." }
    }
  },
  {
    label: "Saved notes / research",
    values: {
      account: { state: "not-stored", detail: "Not stored as server-side account history." },
      session: { state: "not-stored", detail: "Not kept as durable request memory." },
      site: { state: "not-stored", detail: "Destination sites do not receive your saved workspace." },
      workspace: { state: "local-only", detail: "Encrypted and stored on your device." },
      ops: { state: "metadata-only", detail: "Health and quota metadata only." }
    }
  },
  {
    label: "Operational metadata",
    values: {
      account: { state: "limited", detail: "Linked only for access and billing operations." },
      session: { state: "visible", detail: "Needed to run and protect the service." },
      site: { state: "limited", detail: "Receives the metadata normal web requests create." },
      workspace: { state: "not-stored", detail: "Does not live in the local workspace by default." },
      ops: { state: "visible", detail: "Used for health, quota, policy, and abuse prevention." }
    }
  }
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
      "Amon is a private entry point to the web for search, browsing, and research. It is built to keep your questions from becoming a profile."
  },
  {
    question: "Why not just use private mode?",
    answer:
      "Private mode mostly clears the trail on your device. Amon is built for the part before your question becomes a profile: search, reading, comparison, and deeper research through paths that reduce exposure and linkage."
  },
  {
    question: "How long does Amon keep me anonymous?",
    answer:
      "Amon is designed to keep inquiry private for as long as the task allows. If a page can stay simple, Amon uses the most private path that fits. If the site needs interaction or identity, Amon makes that change clear."
  },
  {
    question: "When does that protection change?",
    answer:
      "The boundary changes when the task itself needs more exposure: for example, logging into a third-party account, submitting a form with personal details, or using a service that already knows who you are."
  },
  {
    question: "Will Amon tell me when I am about to expose myself?",
    answer:
      "That is the goal. Amon is designed to start with the private option that fits the task, then make it clear when a page needs live interaction, a protected session, or identity."
  },
  {
    question: "Is it a browser?",
    answer:
      "Amon includes browsing, but it is not just a browser. It changes how each request is handled: as a normal page through Amon, as readable extracted text, or through a protected session."
  },
  {
    question: "Is it a VPN?",
    answer:
      "Amon protects more than the network path. A VPN changes where traffic appears to come from. Amon also changes how search, readable extraction, protected sessions, and saved work are handled."
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
      "Protected Session lets Amon run the site in a controlled environment so the destination interacts with an Amon-managed session rather than directly with your device."
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
