# Module Contract: `gmdl-feat.js` (Unchanged Behavior)
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Module Contract (Phase 1) -->
<!-- Date: 2026-10-13 -->

## 1. Overview & Architectural Role

`gmdl-feat.js` provides utility discovery enhancements to the `go-music-dl` web frontend, delivered via OpenResty injection in `<head>`.
In accordance with project scope constraints, **its functional behavior remains completely unchanged**.
This contract documents its existing behaviors to guarantee zero regressions during project execution.

---

## 2. Documented Feature Behaviors

### 2.1 Feature 1: Homepage Daily Recommended Songs Pill (`homeBtn`)
- **Activation Path:** Matches `^\/music\/?$`.
- **DOM Insertion:** Looks for existing recommendation button (`button[onclick="goToRecommend()"]`) and inserts a companion pill button before it.
- **Element Properties:**
  - `id="gmdl-daily-songs"`
  - `class="btn-pill btn-pill-fav"`
  - `innerHTML='<i class="fa-solid fa-dice"></i> 每日推荐歌曲'`
- **Action:** Clicking navigates to `/music/search?q=%20%20&page=1&page_size=10` (query with two encoded spaces).

### 2.2 Feature 2: Blank-Query Search "Load More" Button (`moreBtn`)
- **Activation Path:** Matches `^\/music\/search` where query parameter `q` is empty or whitespace-only.
- **DOM Insertion:** Appends a button after `.result-list`.
- **Element Properties:**
  - `id="gmdl-more-songs"`
  - `class="song-list-tool-action"`
  - `textContent="🎲 再来十首"`
- **Action:**
  - On click, increments query spaces count (`round = (round % 5) + 1`).
  - Fetches `/music/search?q=<spaces>&page=1&page_size=10`.
  - Parses response HTML and de-duplicates song cards by `dataset.id + '|' + dataset.source`.
  - Appends new unique cards to `.result-list`.
  - Calls `refreshDownloadLinks(list)` if defined in window scope.
  - Updates button label with count of newly added songs or retry state.

---

## 3. Unchanged Behavior Invariant

- **No API Changes:** No alterations to URL query formats, element IDs, or class names.
- **Zero Modifications:** Production logic in `gmdl-feat.js` is not modified during Tasks 2–7.
- **Syntax Integrity:** Must continue to pass `node --check gmdl-feat.js`.

---

## 4. Observable Acceptance Criteria

- **AC-FEAT-01:** `node --check gmdl-feat.js` exits 0.
- **AC-FEAT-02:** Existing exports, functions, and element IDs (`gmdl-daily-songs`, `gmdl-more-songs`) remain identical to baseline commit `126853a`.
- **AC-FEAT-03:** Clicking daily recommended songs button navigates to `/music/search?q=%20%20&page=1&page_size=10`.
- **AC-FEAT-04:** De-duplication logic in `moreBtn` filters duplicate song cards by id and source.
