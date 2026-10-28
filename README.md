# Daily Manna 🤗📖
An app for building strong daily habits in interacting with the Word of God.

## Recording study sessions

- Create a study note with a title; passages are optional and can be added later.
- Saving changes to note text, concept-map cards, or passages automatically records one study session per note per local calendar day.
- Repeated edits that day count as the same session; opening an unchanged note or archiving/restoring it does not record activity.
- History and shared results identify note-based sessions by the note title, without requiring a main passage.
- To record reading without notes, use **Study → Record without a note** on a passage.

## Writing Markdown study notes

- Open a study note and select **Edit** to write or paste Markdown; **Save** returns to the formatted notes view.
- The shared edit toolbar provides heading decrease/increase (levels 1–6), bullet outdent/indent (up to nine levels), **Bold**, **Blockquote**, **Page break**, and **Save**.
- Select text before using Bold; line actions apply to the current line or all selected lines.
- With the Markdown text box focused, **Ctrl+B** (or **Cmd+B** on macOS) runs the same Bold action as the toolbar button.
- **Enter** continues a `-`, `+`, or `*` bullet at the same indentation; Enter on an empty bullet ends the list. **Tab** / **Shift+Tab** run the toolbar's bullet indent/outdent actions on the current or selected lines, keeping your cursor or selection in place.
- Use `**bold**` for steel-blue emphasis, nested `- ` lists for subpoints, and `> ` for green-outlined blockquotes.
- Start a paragraph or list item with the whole word `Read` to color it red; bold text within it stays blue. `Reader` does not trigger this styling.
- A standalone `\newpage` forces a PDF page break and appears as a divider in the notes view.
- Select **Generate PDF** (the PDF icon in the app bar), choose **Sequential**, **Opening**, or **Cut-and-stack**, then select **Generate**. All use numbered half-letter pages (8 pt, 0.75-inch margins).
- **Sequential** exports one half-letter page at a time. **Opening** places consecutive pages side by side on landscape Letter. **Cut-and-stack** arranges landscape Letter sheets so you can cut vertically and stack the right halves on the left halves.
- For Cut-and-stack, **Automatic duplex** off exports separate `-fronts.pdf` and `-backs.pdf` files for manual double-sided printing; on exports one interleaved PDF for an automatic duplex printer. Use landscape, 100% scale, and short-edge flip for either printing method.
- Export uses the current draft without saving it or recording a study session. On web it downloads the PDF file(s); on Android it opens one share sheet, including both files for manual duplex.
- PDF generation runs locally with bundled DejaVu Serif fonts, including bold and italic. It does not require Pandoc, LaTeX, a conversion server, or a font download.
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
