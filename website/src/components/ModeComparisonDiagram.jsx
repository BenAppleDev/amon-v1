const modeCards = [
  {
    id: "local",
    eyebrow: "Live",
    name: "Local",
    title: "Open the real site through Amon.",
    body: "Amon keeps the privacy route in the path while the site opens live in-app.",
    handling: "Live site carried through Amon’s privacy route.",
    bestFor: "Normal browsing"
  },
  {
    id: "clean",
    eyebrow: "Text",
    name: "Clean View",
    title: "Extract the information.",
    body: "Amon fetches the page and returns readable text when you mainly need the content.",
    handling: "Readable text extracted from the page.",
    bestFor: "Reading and research"
  },
  {
    id: "protected",
    eyebrow: "Remote",
    name: "Protected Session",
    title: "Remote into the real site.",
    body: "Amon opens the site from an Amon-controlled machine and you interact through that session.",
    handling: "Remote session hosted by Amon.",
    bestFor: "Dynamic or sensitive tasks"
  }
];

function PhoneMini() {
  return (
    <div className="mini-phone">
      <div />
      <span />
      <span className="short" />
    </div>
  );
}

function AmonMini() {
  return (
    <div className="mini-amon">
      <strong>A</strong>
      <span />
      <span />
    </div>
  );
}

function SiteMini() {
  return (
    <div className="mini-site">
      <div className="mini-chrome">
        <i />
        <i />
        <i />
      </div>
      <span />
      <span className="short" />
    </div>
  );
}

function TextMini() {
  return (
    <div className="mini-text-extract">
      <div className="mini-source-shadow" />
      <div className="mini-document">
        <span className="document-title-line" />
        <span />
        <span />
        <span className="short" />
      </div>
    </div>
  );
}

function RemoteMini() {
  return (
    <div className="mini-remote">
      <div className="mini-server">
        <span />
        <span />
      </div>
      <div className="mini-remote-screen">
        <div className="mini-remote-dot" />
        <span className="mini-remote-line strong" />
        <span className="mini-remote-line" />
      </div>
    </div>
  );
}

function ModeScene({ id }) {
  return (
    <div className={`mode-scene-object mode-scene-object-${id}`} aria-hidden="true">
      <PhoneMini />
      <div className="scene-arrow" />
      <AmonMini />
      <div className="scene-arrow" />
      {id === "clean" ? <TextMini /> : id === "protected" ? <RemoteMini /> : <SiteMini />}
    </div>
  );
}

export function ModeComparisonDiagram() {
  return (
    <div className="mode-comparison-diagram">
      {modeCards.map((mode) => (
        <article className={`mode-card mode-card-${mode.id}`} key={mode.id}>
          <div className="mode-card-top">
            <span>{mode.eyebrow}</span>
            <strong>{mode.name}</strong>
          </div>

          <ModeScene id={mode.id} />

          <div className="mode-card-copy">
            <h3>{mode.title}</h3>
            <p>{mode.body}</p>
          </div>

          <div className="mode-card-handling">
            <span>Handling</span>
            <strong>{mode.handling}</strong>
          </div>

          <div className="mode-card-best">
            <span>Best for</span>
            <strong>{mode.bestFor}</strong>
          </div>
        </article>
      ))}
    </div>
  );
}