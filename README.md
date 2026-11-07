# Daily Manna 🤗📖
An app for building strong daily habits in interacting with the Word of God.

## Recitation controls on Android

- Start a recording from **Recite** and allow microphone and notification access. Notifications must be enabled so the background recording always has accessible controls.
- Before recording, tap **Phone mic** (the default) or the headset name beneath the recording controls. A bottom sheet lists microphones with a checkmark on the selection and refreshes each time it opens. Connect or pair headsets in Android Settings, then reopen the sheet. Playback-only Bluetooth devices are not microphone options; other platforms retain their existing system-selected input.
- Microphone selection is locked while recording or muted. Stop the recording before choosing another microphone; switching does not splice separate recordings together.
- Android verifies the capture route at startup. If the chosen input cannot be established, startup fails rather than accepting another microphone. If the input disconnects or routing changes during recording, the app stops and saves the captured audio for review. Android reports route changes asynchronously, so a small amount of fallback audio may be captured before the stop completes.
- Android shows a native ongoing recording notification named **Recitation**, with **Mute/Unmute** and **Stop Recording**. It uses recording controls rather than Android's call template, whose built-in "Hang up" label cannot be customized.
- **Mute** pauses recording; **Unmute** resumes it. The same controls are available on the recitation screen. Audio interruptions reported by the recorder also update the muted state; resuming requires an explicit action.
- **Stop Recording** ends capture and keeps the recording for the existing playback, transcription, and grading flow. Tap the notification before stopping, or reopen Daily Manna afterward, to return to that screen.
- A microphone foreground service keeps the session active while another app is open or the screen is locked, without forcing the display to stay on. This is not a carrier/Telecom call and does not use the phone dialer.
- Leaving the recitation screen cancels an unfinished recording. Removing the app task, destroying its Flutter engine, or force-stopping the app ends the session; recordings are not restored after process death.
- Web retains the existing foreground recording workflow, with the new in-page mute control but no Android notification.

### Android device verification

1. Start a recording, lock the screen, and verify that speech still appears in the saved playback after unlocking.
2. Mute and unmute from both the notification and the app; verify that their states agree and paused speech is excluded from playback.
3. Select **Stop Recording** while recording and while muted; verify that playback opens with the captured audio and the notification disappears.
4. Deny microphone or notification permission, or disable the recitation notification channel in Settings; verify that starting fails visibly without leaving capture or a notification running.
5. Leave the recitation screen, remove the app task, and interrupt recording with another audio app; verify cleanup and that interrupted capture does not silently resume.
6. Check the notification and both actions on older and newer supported Android devices. Browser tests do not exercise Android notifications, lock-screen capture, or Bluetooth routing.
7. With a Bluetooth headset connected, select **Phone mic**, record speech close to the phone and away from the headset, and listen back. Repeat with the headset selected, then return to the phone input for another recording. Check classic Bluetooth and BLE headsets on supported Android versions.
8. Disconnect the selected headset before starting, while recording, and while muted. Verify that a missing input cannot start, an active recording stops and can be reviewed, and neither case silently selects the phone. Reconnect, reopen the microphone sheet, and explicitly select the input for a new recording.
9. Verify the microphone button is disabled during startup, capture, and mute; leaving during Bluetooth connection startup must release the route and foreground notification. After stopping or leaving, verify other apps can use their normal audio routes.

### Recorder dependency maintenance

- Native input verification currently adapts `record_android` 1.4.5 through its private recorder fields because that version exposes neither the active `AudioRecord` nor its session ID. It reads the actual capture route and adjusts the plugin's saved audio mode so muting a reused recorder does not undo Bluetooth routing.
- The adapter fails startup if those fields are unavailable; it does not assume that a preferred-device request succeeded. Its release-build keep rules live in `android/app/recitation-input-rules.pro`. Review the adapter and test a minified build on a device whenever upgrading `record_android`.

## Recording study sessions

- Every passage selector opens with a **Search** tab for typing a reference, alongside **Books**, **Review**, and **Suggestions**. Matching passages use the same list-tile styling as Suggestions, with a divider above the results. Tap a title to select it immediately; the other tabs retain their direct-selection behavior. There is no separate Preview section or confirmation button, and selection does not log activity.
- Open **Interact**, select a passage, then choose Memorize, Recite, or Study. To record reading without notes, choose **Study → Record without a note**.
- Enter a chapter (`1 jhn 2`) or verse range (`John 3:16–18`). Chapter-only references include their last verse automatically. Lists such as `John 1,3` offer each passage as a separate selectable title. Existing flows accept one within-chapter range at a time; cross-chapter ranges cannot be selected or silently shortened, and single-verse selectors require a single verse per result.
- Book names ignore case, spaces, and periods. Search tries exact names/IDs, then prefixes, then letters appearing in order (`jhn`, `dt`, `mrk`, or `hbk`), without a per-book abbreviation table. Ordered-letter matches with fewer skipped letters rank first; ties use Bible order. Book numbers must match, so `jhn` does not include numbered Johns. Only alternative names such as “Song of Songs” are listed explicitly. Ambiguous matches offer all valid passages (`D 8` offers Deuteronomy 8 and Daniel 8); a stronger matching tier suppresses weaker matches (`Dan 8` offers only Daniel 8). Each option uses that book's actual verse counts. Invalid references show an inline error and no selectable results.
- Existing multi-chapter reading records remain intact in History, details, and shared results.
- Create a study note with a title; passages are optional and can be added later.
- Saving changes to note text, concept-map cards, or passages automatically records one study session per note per local calendar day.
- Repeated edits that day count as the same session; opening an unchanged note or archiving/restoring it does not record activity.
- History and shared results identify note-based sessions by the note title, without requiring a main passage.

## Writing Markdown study notes

- Open a study note and select **Edit** to write or paste Markdown; **Save** returns to the formatted notes view.
- The shared edit toolbar provides heading decrease/increase (levels 1–6), bullet outdent/indent (up to nine levels), **Bold**, **Blockquote**, **Page break**, and **Save**.
- Select text before using Bold; line actions apply to the current line or all selected lines.
- With the Markdown text box focused, **Ctrl+B** (or **Cmd+B** on macOS) runs the same Bold action as the toolbar button.
- **Enter** continues a `-`, `+`, or `*` bullet at the same indentation; Enter on an empty bullet ends the list. **Tab** / **Shift+Tab** run the toolbar's bullet indent/outdent actions on the current or selected lines, keeping your cursor or selection in place.
- Use `**bold**` for steel-blue emphasis, nested `- ` lists for subpoints, and `> ` for green-outlined blockquotes.
- Start a paragraph or list item with the whole word `Read` to color it red; bold text within it stays blue. `Reader` does not trigger this styling.
- A standalone `\newpage` forces a PDF page break and appears as a divider in the notes view.
- Select **Generate PDF** (the PDF icon in the app bar), choose **Sequential**, **Opening**, **Cut-and-stack**, or **Cut-and-stack Duplex**, then select **Generate**. All use numbered half-letter pages (8 pt, 0.75-inch margins).
- **Sequential** exports one half-letter page at a time. **Opening** places consecutive pages side by side on landscape Letter. **Cut-and-stack** arranges landscape Letter sheets so you can cut vertically and stack the right halves on the left halves.
- **Cut-and-stack** exports separate `-fronts.pdf` and `-backs.pdf` files for manual double-sided printing; **Cut-and-stack Duplex** exports one interleaved PDF for a double-sided printer. Use landscape, 100% scale, and short-edge flip for either printing method.
- Export uses the current draft without saving it or recording a study session. On web it downloads the PDF file(s); on Android it opens one share sheet, including both files for manual duplex.
- PDF generation runs locally with bundled Bitstream Charter fonts, including bold and italic, matching the original sermon script. DejaVu Serif supplies missing symbols such as arrows. It does not require Pandoc, LaTeX, a conversion server, or a font download.
- PDF headings match the script's 8 pt `extarticle` sizes: H1 is 10.95 pt, H2 is 10 pt, and H3–H6 are 8 pt. H1–H5 are black; H6 and bold emphasis are steel blue. Heading spacing follows the script's nominal values rather than LaTeX's elastic page layout.
- PDF lists use hanging indents: wrapped lines and continuation paragraphs align with the item text, with deeper indentation for nested lists. Long items can continue across pages. Page numbers sit in the bottom margin, 30 TeX points below the body area, matching the script.
- PDF output follows the sermon styling and page-order conventions, but is not a pixel-identical LaTeX rendering.

## Editing concept maps

- Open a study note's **Concept Map** tab and select **Edit**.
- Use **+ Key point**, **+ Note**, or **+ Passage** in the toolbar to add a card.
- When a card is selected, the plus buttons automatically connect new cards to it and keep it selected for adding more branches. With no selection, new cards are unconnected.
- Select a card to add its actions to the toolbar: add/remove connections, show/hide passage text, change card type, or delete the card. Scroll the toolbar horizontally if needed.
- With a keyboard, Tab to a card to select it, then use Tab or Shift+Tab to reach its toolbar actions; after choosing **Connect**, Tab to the destination and press **Enter** or **Space**.
- Double-tap editable text to select a word and use the text-selection toolbar to cut, copy, or paste.
- Use **Change to note** to turn a key point into a free-flowing subpoint without losing its text or connections; **Change to key point** anchors it on the left again.
- To attach “The Lowly” after James 1:9, make it a Note, then select either card, choose **Connect** in the toolbar, and tap the other card.
- Select **Save** to persist your changes.

## Archiving study notes

- Open a study note in view mode, then select **⋮ → Archive note**.
- Use **Undo** in the confirmation snackbar to reverse the action.
- On **Study Notes**, switch between **Active** and **Archived**; open an archived note and select **⋮ → Restore note** to bring it back.
- Archiving keeps note content and past study-session links, but hides the note from the picker for new sessions.

## Development Setup

### With Nix (NixOS)

A reproducible Nix flake is provided using [android-nixpkgs](https://github.com/tadfisher/android-nixpkgs):

```bash
nix flake update              # Update flake inputs
nix develop                   # Enter the dev environment
```

This provides:
- Flutter (latest stable)
- JDK (default version)
- Android SDK (API 36, build-tools-36.0.0)
- NDK 26.1
- Gradle
- Git and Just for task automation
- Proper environment variables (`ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`)

Once in the dev shell, run:

```bash
just run-android              # Build and run on Android
just build-apk-prod          # Build release APK
just web                      # Run web version
just test                     # Run tests
just format                   # Format code
just analyze                  # Analyze code
```

The flake uses [android-nixpkgs](https://github.com/tadfisher/android-nixpkgs) for reproducible Android SDK packaging, updated daily from Google's repositories.

### Without Nix

Install Flutter and Android SDK manually following the [official Flutter documentation](https://flutter.dev/docs/get-started/install).

## Sources

KJV Bible in OSIS format is from [here](https://github.com/gratis-bible/bible/blob/master/en/kjv.xml).
