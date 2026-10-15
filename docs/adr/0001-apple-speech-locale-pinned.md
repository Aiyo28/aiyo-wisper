# Apple Speech transcribes one pinned locale per pass

WhisperKit's auto-detect mixed languages mid-sentence (e.g. CN/EN bleed). `SpeechTranscriber(locale:)` transcribes exactly one language, so each pass is pinned to a locale and that is the fix, not a limitation to work around. Multi-language "Auto" is built on top of it: one pinned pass per supported locale, keeping the pass with the highest acoustic confidence, because Apple's API has no spoken-language detector. The cost is one extra pass per additional language.
