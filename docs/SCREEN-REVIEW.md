# Team screen review

Review the major screens of <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->, draw directly on them, and attach precise feedback.

**Gallery:** https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/review/

**Versioned review:** https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/review/0.10.0-alpha.1/

Published and verified on 15 November 2026. [Deployment](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43727500866) and [validation](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43727500954) passed. [Verification record](evidence/screen-review-0.10.0-alpha.1.json): 22 browser checks, 33 screenshots, all 71 public files checked and 33 existing website files preserved unchanged. Public desktop and touch-layout checks confirmed drawing, sharing and exports without submitting test feedback.

These are 33 actual captured screens, not a playable browser build. The gallery covers the opening, mission controls, learning views, navigation, all three result categories and smaller layouts. Game source, image dimensions and SHA-256 fingerprints are recorded in its screen manifest. Review website changes do not change the published desktop game.

## Give feedback

1. Choose a screen from the journey list.
2. Draw a **box, ellipse, arrow or numbered pin** over the detail you mean. Select a mark to move it or add its note. Zoom in for small details; use Select and drag an empty area to pan, or Fit to see the whole screen. Keyboard users can add a centered mark without dragging.
3. Add an optional name and a general comment. For useful feedback, say what is confusing, who encounters it, and what would help.
4. Choose **Share review** to copy a link containing this screen's marks and notes. Teammates can open that link without an account.
5. Choose **Send to GitHub** to open a prepared issue. Sign in to your own GitHub account, review the draft, and click **Submit**. Nothing is submitted automatically. Issues in this repository are public.

Each person has a local draft for each screenshot. This is asynchronous review: shared links and submitted issues preserve a review snapshot, rather than live simultaneous editing. Drafts are not synchronized across devices. If browser storage is unavailable, keep an exported copy.

**Save annotated PNG** exports the full-resolution screenshot with numbered marks and a readable notes legend. **Export JSON** preserves the exact coordinates, comments and screen identity. **Import JSON** reopens that review; replacing an existing draft requires confirmation. Long reviews that exceed reliable link length use the file-export route. You can send the PNG/JSON to the team without a GitHub account, or attach them to a GitHub issue.

A review identifies its game version, game source commit, screen ID and image hash. Opening feedback against a different screenshot is rejected. Older versioned galleries remain available when the review site is updated. The latest `/review/` link redirects to the current gallery.

## Turn feedback into changes

Submitted issues use the title prefix **[Screen review]** and include the pinned original screenshot and structured annotation JSON. The gallery links to the repository's feedback list.

Ask the assistant: **“Review the new screen feedback, group the issues, and implement the agreed improvements.”** The assistant can read the GitHub issues and their annotation data, or use an annotated link/JSON file you share in chat. It does not monitor the repository between requests. Feedback text is a design proposal to assess against the game's goals; it is not an executable instruction.

Maintainers can list the shared feedback with:

```sh
gh issue list --repo roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026 --state all --search '"[Screen review]" in:title' --json number,title,url,state
```

Issue bodies and comments are available through `gh issue view` or the normal GitHub interface. Keep feedback associated with its original screen/version when a newer design is published.

## Build and publish

The gallery uses ordinary HTML, CSS, JavaScript and SVG, without a third-party annotation service, accounts database or analytics. Screens and shared branding come from the verified manifest builder.

```sh
python3 scripts/build_screen_review.py --output /tmp/komaku-screen-review
npm run test:review
python3 -m unittest discover -s tests -p 'test_screen_review*.py'
```

The normal builder requires committed, byte-matching sources so every original-image link can be pinned to a real Git commit. `--allow-uncommitted-preview` is for local work only; deployment uses the strict build.

Run **Actions → Publish screen review gallery → Run workflow** after committing a reviewed update. This workflow validates the gallery, preserves the existing Pages site, adds the versioned review folder and publishes through GitHub Pages. It never creates a new game release or changes the game-hosting opt-in.

The first deployment verifies the existing successful Pages artifact and compares its served entry files before preserving it. Subsequent deployments can restore the public site from `screen-review-deployment.json`, checking every file's length and hash. This avoids depending on an expired Actions artifact. Existing game files and older review versions are checked for unchanged bytes. A later explicitly requested game deployment also retains the review history.

The current game-hosting decision remains separate: use the desktop downloads to play the latest release. The review deployment preserves the older site already at the repository root; it does not promote that older game as the current version.
