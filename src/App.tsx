import { startTransition, useEffect, useRef, useState } from "react";
import { LogicalSize } from "@tauri-apps/api/dpi";
import { getCurrentWindow } from "@tauri-apps/api/window";
import "./App.css";

type Note = {
  id: string;
  body: string;
  createdAt: string;
  updatedAt: string;
};

type Shortcut = {
  ctrl: boolean;
  alt: boolean;
  shift: boolean;
  meta: boolean;
  key: string;
};

type ShortcutField = "openShortcut" | "prevShortcut" | "nextShortcut";
type WindowSizePreset = "small" | "medium" | "large";

type Preferences = {
  openShortcut: Shortcut;
  prevShortcut: Shortcut;
  nextShortcut: Shortcut;
  windowSize: WindowSizePreset;
};

type PersistedState = {
  notes: Note[];
  currentNoteId: string;
  hasSeenOnboarding: boolean;
  preferences: Preferences;
};

const STORAGE_KEY = "floatnote:mvp-state:v1";

const WINDOW_SIZE_PRESETS: Record<WindowSizePreset, LogicalSize> = {
  small: new LogicalSize(640, 460),
  medium: new LogicalSize(720, 520),
  large: new LogicalSize(820, 600),
};

const DEFAULT_PREFERENCES: Preferences = {
  openShortcut: { ctrl: true, alt: false, shift: false, meta: false, key: "A" },
  prevShortcut: {
    ctrl: true,
    alt: false,
    shift: true,
    meta: false,
    key: "ArrowLeft",
  },
  nextShortcut: {
    ctrl: true,
    alt: false,
    shift: true,
    meta: false,
    key: "ArrowRight",
  },
  windowSize: "medium",
};

function nowIso() {
  return new Date().toISOString();
}

function shiftHours(base: Date, hours: number) {
  return new Date(base.getTime() + hours * 60 * 60 * 1000).toISOString();
}

function createId() {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }

  return `note-${Math.random().toString(16).slice(2)}-${Date.now()}`;
}

function createSeedState(): PersistedState {
  const base = new Date();
  const notes: Note[] = [
    {
      id: createId(),
      createdAt: shiftHours(base, -36),
      updatedAt: shiftHours(base, -30),
      body: [
        "# FloatNote principles",
        "",
        "- 떠오른 생각을 놓치지 않기",
        "- 플로팅 레이어처럼 가볍게 열기",
        "- Created / Updated 는 하단 고정",
      ].join("\n"),
    },
    {
      id: createId(),
      createdAt: shiftHours(base, -24),
      updatedAt: shiftHours(base, -16),
      body: [
        "# Hotkey audit",
        "",
        "- open: Control + A",
        "- prev / next: prototype defaults only",
        "- macOS 기본 동작과 충돌 없는 조합으로 재조정 필요",
      ].join("\n"),
    },
    {
      id: createId(),
      createdAt: shiftHours(base, -6),
      updatedAt: shiftHours(base, -1),
      body: [
        "# Today",
        "",
        "- wireframe -> low-fi -> implementation",
        "- 마지막 본 노트에서 바로 이어쓰기",
        "- raw markdown input first, inline rendering later",
      ].join("\n"),
    },
  ];

  return {
    notes,
    currentNoteId: notes[notes.length - 1]?.id ?? "",
    hasSeenOnboarding: false,
    preferences: DEFAULT_PREFERENCES,
  };
}

function normalizeShortcutKey(key: string) {
  if (key === " ") {
    return "Space";
  }

  if (key.length === 1) {
    return key.toUpperCase();
  }

  return key;
}

function coerceShortcut(
  candidate: Partial<Shortcut> | undefined,
  fallback: Shortcut,
): Shortcut {
  if (!candidate || typeof candidate.key !== "string") {
    return fallback;
  }

  return {
    ctrl: Boolean(candidate.ctrl),
    alt: Boolean(candidate.alt),
    shift: Boolean(candidate.shift),
    meta: Boolean(candidate.meta),
    key: normalizeShortcutKey(candidate.key),
  };
}

function loadState(): PersistedState {
  const fallback = createSeedState();

  try {
    const raw = localStorage.getItem(STORAGE_KEY);

    if (!raw) {
      return fallback;
    }

    const parsed = JSON.parse(raw) as Partial<PersistedState>;
    const notes = Array.isArray(parsed.notes)
      ? parsed.notes.filter((note): note is Note => {
          return (
            note != null &&
            typeof note.id === "string" &&
            typeof note.body === "string" &&
            typeof note.createdAt === "string" &&
            typeof note.updatedAt === "string"
          );
        })
      : fallback.notes;

    const resolvedNotes = notes.length > 0 ? notes : fallback.notes;
    const currentNoteId = resolvedNotes.some((note) => note.id === parsed.currentNoteId)
      ? (parsed.currentNoteId as string)
      : resolvedNotes[resolvedNotes.length - 1]?.id ?? fallback.currentNoteId;

    return {
      notes: resolvedNotes,
      currentNoteId,
      hasSeenOnboarding: Boolean(parsed.hasSeenOnboarding),
      preferences: {
        openShortcut: coerceShortcut(parsed.preferences?.openShortcut, DEFAULT_PREFERENCES.openShortcut),
        prevShortcut: coerceShortcut(parsed.preferences?.prevShortcut, DEFAULT_PREFERENCES.prevShortcut),
        nextShortcut: coerceShortcut(parsed.preferences?.nextShortcut, DEFAULT_PREFERENCES.nextShortcut),
        windowSize:
          parsed.preferences?.windowSize === "small" ||
          parsed.preferences?.windowSize === "medium" ||
          parsed.preferences?.windowSize === "large"
            ? parsed.preferences.windowSize
            : DEFAULT_PREFERENCES.windowSize,
      },
    };
  } catch {
    return fallback;
  }
}

function isTauriRuntime() {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

function formatShortcutLabel(shortcut: Shortcut) {
  const parts: string[] = [];

  if (shortcut.ctrl) parts.push("Ctrl");
  if (shortcut.alt) parts.push("Alt");
  if (shortcut.shift) parts.push("Shift");
  if (shortcut.meta) parts.push("Meta");

  const labels: Record<string, string> = {
    ArrowLeft: "Left",
    ArrowRight: "Right",
    ArrowUp: "Up",
    ArrowDown: "Down",
    Space: "Space",
  };

  parts.push(labels[shortcut.key] ?? shortcut.key);
  return parts.join(" + ");
}

function matchesShortcut(event: KeyboardEvent, shortcut: Shortcut) {
  return (
    event.ctrlKey === shortcut.ctrl &&
    event.altKey === shortcut.alt &&
    event.shiftKey === shortcut.shift &&
    event.metaKey === shortcut.meta &&
    normalizeShortcutKey(event.key) === shortcut.key
  );
}

function formatTimestamp(timestamp: string) {
  const date = new Date(timestamp);

  if (Number.isNaN(date.getTime())) {
    return timestamp;
  }

  const pad = (value: number) => String(value).padStart(2, "0");

  return [
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`,
    `${pad(date.getHours())}:${pad(date.getMinutes())}`,
  ].join(" ");
}

function App() {
  const initialState = useRef(loadState()).current;
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const boundaryTimeoutRef = useRef<number | null>(null);
  const firstRenderRef = useRef(true);

  const [notes, setNotes] = useState(initialState.notes);
  const [currentNoteId, setCurrentNoteId] = useState(initialState.currentNoteId);
  const [hasSeenOnboarding, setHasSeenOnboarding] = useState(initialState.hasSeenOnboarding);
  const [isOnboardingOpen, setIsOnboardingOpen] = useState(!initialState.hasSeenOnboarding);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [captureField, setCaptureField] = useState<ShortcutField | null>(null);
  const [preferences, setPreferences] = useState(initialState.preferences);
  const [saveStatus, setSaveStatus] = useState<"saved" | "saving">("saved");
  const [previewHidden, setPreviewHidden] = useState(false);
  const [leftBoundaryPulse, setLeftBoundaryPulse] = useState(false);

  const currentIndex = Math.max(
    0,
    notes.findIndex((note) => note.id === currentNoteId),
  );

  const currentNote = notes[currentIndex] ?? notes[0];

  const notesLabel = `${currentIndex + 1} / ${notes.length}`;

  useEffect(() => {
    textareaRef.current?.focus();
  }, [currentNoteId, isOnboardingOpen, isSettingsOpen, previewHidden]);

  useEffect(() => {
    if (firstRenderRef.current) {
      firstRenderRef.current = false;
      return;
    }

    setSaveStatus("saving");
    const snapshot: PersistedState = {
      notes,
      currentNoteId,
      hasSeenOnboarding,
      preferences,
    };

    const timeout = window.setTimeout(() => {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot));
      setSaveStatus("saved");
    }, 280);

    return () => window.clearTimeout(timeout);
  }, [notes, currentNoteId, hasSeenOnboarding, preferences]);

  useEffect(() => {
    const targetSize = WINDOW_SIZE_PRESETS[preferences.windowSize];

    if (!isTauriRuntime()) {
      return;
    }

    void getCurrentWindow().setSize(targetSize).catch(() => {
      // Browser preview or missing permission should not break the UI.
    });
  }, [preferences.windowSize]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (captureField) {
        const modifierKeys = new Set(["Control", "Shift", "Alt", "Meta"]);

        if (modifierKeys.has(event.key)) {
          return;
        }

        event.preventDefault();
        setPreferences((current) => ({
          ...current,
          [captureField]: {
            ctrl: event.ctrlKey,
            alt: event.altKey,
            shift: event.shiftKey,
            meta: event.metaKey,
            key: normalizeShortcutKey(event.key),
          },
        }));
        setCaptureField(null);
        return;
      }

      if ((event.ctrlKey || event.metaKey) && event.key === ",") {
        event.preventDefault();
        setIsSettingsOpen((open) => !open);
        return;
      }

      if (event.key === "Escape") {
        event.preventDefault();

        if (isSettingsOpen) {
          setIsSettingsOpen(false);
          return;
        }

        if (isOnboardingOpen) {
          handleDismissOnboarding();
          return;
        }

        void handleCloseWindow();
        return;
      }

      if (isSettingsOpen || isOnboardingOpen || previewHidden) {
        return;
      }

      if (matchesShortcut(event, preferences.prevShortcut)) {
        event.preventDefault();
        goToPreviousNote();
        return;
      }

      if (matchesShortcut(event, preferences.nextShortcut)) {
        event.preventDefault();
        goToNextNote();
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [
    captureField,
    isOnboardingOpen,
    isSettingsOpen,
    preferences,
    previewHidden,
    currentIndex,
    currentNoteId,
    notes,
    hasSeenOnboarding,
  ]);

  function persistNow(nextState: PersistedState) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(nextState));
    setSaveStatus("saved");
  }

  function updateCurrentNote(body: string) {
    setSaveStatus("saving");
    const updatedAt = nowIso();
    setNotes((currentNotes) =>
      currentNotes.map((note) =>
        note.id === currentNote.id ? { ...note, body, updatedAt } : note,
      ),
    );
  }

  function createEmptyNote(): Note {
    const timestamp = nowIso();
    return {
      id: createId(),
      body: "",
      createdAt: timestamp,
      updatedAt: timestamp,
    };
  }

  function pulseLeftBoundary() {
    if (boundaryTimeoutRef.current) {
      window.clearTimeout(boundaryTimeoutRef.current);
    }

    setLeftBoundaryPulse(true);
    boundaryTimeoutRef.current = window.setTimeout(() => {
      setLeftBoundaryPulse(false);
      boundaryTimeoutRef.current = null;
    }, 240);
  }

  function goToPreviousNote() {
    if (currentIndex <= 0) {
      pulseLeftBoundary();
      return;
    }

    const nextId = notes[currentIndex - 1]?.id;
    if (!nextId) {
      return;
    }

    const snapshot: PersistedState = {
      notes,
      currentNoteId: nextId,
      hasSeenOnboarding,
      preferences,
    };

    persistNow(snapshot);
    startTransition(() => {
      setCurrentNoteId(nextId);
    });
  }

  function goToNextNote() {
    if (currentIndex === notes.length - 1) {
      const freshNote = createEmptyNote();
      const nextNotes = [...notes, freshNote];
      const snapshot: PersistedState = {
        notes: nextNotes,
        currentNoteId: freshNote.id,
        hasSeenOnboarding,
        preferences,
      };

      setNotes(nextNotes);
      persistNow(snapshot);
      startTransition(() => {
        setCurrentNoteId(freshNote.id);
      });
      return;
    }

    const nextId = notes[currentIndex + 1]?.id;
    if (!nextId) {
      return;
    }

    const snapshot: PersistedState = {
      notes,
      currentNoteId: nextId,
      hasSeenOnboarding,
      preferences,
    };

    persistNow(snapshot);
    startTransition(() => {
      setCurrentNoteId(nextId);
    });
  }

  function handleDismissOnboarding() {
    setHasSeenOnboarding(true);
    setIsOnboardingOpen(false);
  }

  async function handleCloseWindow() {
    const snapshot: PersistedState = {
      notes,
      currentNoteId,
      hasSeenOnboarding,
      preferences,
    };

    persistNow(snapshot);

    if (!isTauriRuntime()) {
      setPreviewHidden(true);
      return;
    }

    await getCurrentWindow().close();
  }

  if (previewHidden) {
    return (
      <main className="preview-state">
        <div className="preview-state__card">
          <span className="preview-state__eyebrow">Browser Preview</span>
          <h1>FloatNote window closed</h1>
          <p>
            Tauri 런타임에서는 이 시점에 창이 닫힙니다. 브라우저 프리뷰에서는 다시 열어서 레이아웃을
            계속 확인할 수 있게 남겨두었습니다.
          </p>
          <button
            type="button"
            className="preview-state__button"
            onClick={() => setPreviewHidden(false)}
          >
            Reopen preview
          </button>
        </div>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <section className={`note-window ${leftBoundaryPulse ? "note-window--pulse-left" : ""}`}>
        <header className="note-window__topbar" data-tauri-drag-region>
          <div className="note-window__brand">
            <span className="note-window__brand-mark">FloatNote</span>
            <span className="note-window__brand-sub">resume, write, move, close</span>
          </div>

          <div className="note-window__sequence">
            <button
              type="button"
              className="sequence-chip"
              onClick={goToPreviousNote}
              disabled={currentIndex === 0}
            >
              Older
            </button>
            <span className="note-window__position">{notesLabel}</span>
            <button type="button" className="sequence-chip" onClick={goToNextNote}>
              Newer
            </button>
          </div>

          <div className="note-window__actions">
            <span className={`save-chip save-chip--${saveStatus}`}>{saveStatus}</span>
            <button type="button" className="topbar-button" onClick={() => setIsSettingsOpen(true)}>
              Settings
            </button>
            <button type="button" className="topbar-button topbar-button--danger" onClick={() => void handleCloseWindow()}>
              Close
            </button>
          </div>
        </header>

        <section className="note-window__editor-shell">
          <div className="note-window__editor-frame">
            <div className="note-window__editor-meta">
              <span>Last viewed note</span>
              <span>raw markdown first, inline rendering later</span>
            </div>

            <textarea
              ref={textareaRef}
              className="note-window__textarea"
              spellCheck={false}
              value={currentNote?.body ?? ""}
              placeholder="제목 없이 바로 입력 시작"
              onChange={(event) => updateCurrentNote(event.currentTarget.value)}
            />
          </div>

          {isOnboardingOpen ? (
            <div className="overlay-layer">
              <div className="overlay-card">
                <span className="overlay-card__eyebrow">First run</span>
                <h2>FloatNote 시작하기</h2>
                <ol>
                  <li>{formatShortcutLabel(preferences.openShortcut)} 로 창 열기</li>
                  <li>마지막으로 본 노트에서 바로 입력</li>
                  <li>{formatShortcutLabel(preferences.nextShortcut)} / {formatShortcutLabel(preferences.prevShortcut)} 로 이동</li>
                </ol>
                <p>기본 단축키는 설정에서 바꿀 수 있습니다.</p>
                <div className="overlay-card__actions">
                  <button type="button" className="overlay-button" onClick={handleDismissOnboarding}>
                    시작하기
                  </button>
                </div>
              </div>
            </div>
          ) : null}

          {isSettingsOpen ? (
            <div className="overlay-layer overlay-layer--dimmed">
              <div className="settings-sheet">
                <div className="settings-sheet__header">
                  <div>
                    <span className="overlay-card__eyebrow">Preferences</span>
                    <h2>Settings</h2>
                  </div>
                  <button
                    type="button"
                    className="topbar-button"
                    onClick={() => {
                      setCaptureField(null);
                      setIsSettingsOpen(false);
                    }}
                  >
                    Done
                  </button>
                </div>

                <div className="settings-list">
                  <div className="settings-card">
                    <span className="settings-card__label">Global shortcut</span>
                    <div className="settings-card__row">
                      <div className="settings-card__value">{formatShortcutLabel(preferences.openShortcut)}</div>
                      <button
                        type="button"
                        className={`capture-button ${captureField === "openShortcut" ? "capture-button--active" : ""}`}
                        onClick={() => setCaptureField("openShortcut")}
                      >
                        {captureField === "openShortcut" ? "Listening..." : "Capture"}
                      </button>
                    </div>
                  </div>

                  <div className="settings-card">
                    <span className="settings-card__label">Note navigation</span>
                    <div className="settings-card__row">
                      <div className="settings-card__value">{formatShortcutLabel(preferences.prevShortcut)}</div>
                      <button
                        type="button"
                        className={`capture-button ${captureField === "prevShortcut" ? "capture-button--active" : ""}`}
                        onClick={() => setCaptureField("prevShortcut")}
                      >
                        {captureField === "prevShortcut" ? "Listening..." : "Capture prev"}
                      </button>
                    </div>
                    <div className="settings-card__row">
                      <div className="settings-card__value">{formatShortcutLabel(preferences.nextShortcut)}</div>
                      <button
                        type="button"
                        className={`capture-button ${captureField === "nextShortcut" ? "capture-button--active" : ""}`}
                        onClick={() => setCaptureField("nextShortcut")}
                      >
                        {captureField === "nextShortcut" ? "Listening..." : "Capture next"}
                      </button>
                    </div>
                    <p className="settings-card__hint">Prototype defaults only. Final defaults remain open.</p>
                  </div>

                  <div className="settings-card">
                    <span className="settings-card__label">Window size</span>
                    <div className="window-size-group">
                      {(["small", "medium", "large"] as WindowSizePreset[]).map((size) => (
                        <button
                          key={size}
                          type="button"
                          className={`size-pill ${preferences.windowSize === size ? "size-pill--active" : ""}`}
                          onClick={() =>
                            setPreferences((current) => ({
                              ...current,
                              windowSize: size,
                            }))
                          }
                        >
                          {size}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ) : null}
        </section>

        <footer className="note-window__footer">
          <span>Created {formatTimestamp(currentNote.createdAt)}</span>
          <span>Updated {formatTimestamp(currentNote.updatedAt)}</span>
        </footer>
      </section>
    </main>
  );
}

export default App;
