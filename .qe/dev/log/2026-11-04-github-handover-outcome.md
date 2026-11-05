# GitHub handover outcome, 2026-11-04

*A raw record under QEP-7. It carries out `.qe/dev/log/2026-10-06-github-handover.md`
(QuantEcon/actions#221), run by a local Claude Code session on 2026-11-04 under the maintainer's
decision of that day to run the handover and then merge #220 and #221.*

## Created

| Key | Issue | Type | Parent | Labels |
|---|---|---|---|---|
| P | #239 | Project | none | none |
| T_PREVIEW | #232 | Task | #239 | enhancement, security |
| T_PUBLISH | #233 | Task | #239 | enhancement, security |
| D_REBUILD | #234 | Decision | none | discuss, security |
| T_REBUILD | #235 | Task | none | bug, security |
| T_RESTORE | #236 | Task | none | bug |
| T_ALERT | #238 | Task | none | bug, low-priority |

Dependency: #235 blocked by #234.

The tracker's sub-issues are #232 then #233, in plan order.

## Comments posted

- <https://github.com/QuantEcon/actions/issues/142#issuecomment-6628501617>
- <https://github.com/QuantEcon/actions/issues/135#issuecomment-6628502390>
- <https://github.com/QuantEcon/actions/issues/153#issuecomment-6628502958>
- <https://github.com/QuantEcon/actions/issues/149#issuecomment-6628503524>
- <https://github.com/QuantEcon/actions/issues/100#issuecomment-6628503944>
- <https://github.com/QuantEcon/actions/issues/215#issuecomment-6628504359>
- <https://github.com/QuantEcon/actions/issues/30#issuecomment-6628504731>
- <https://github.com/QuantEcon/actions/issues/151#issuecomment-6628505101>
- <https://github.com/QuantEcon/actions/issues/239#issuecomment-6628506901> (the tracker's revision log)

## Checks

The Step 8 output:

```text
tracker: type=Project labels=[]
stamps:   1
heading:  1
next:     1
checkbox: 0
unfilled: 0
sub-issues: 1
T_PREVIEW #232 type=Task labels=security,enhancement type-labels=1 parent=239
T_PUBLISH #233 type=Task labels=security,enhancement type-labels=1 parent=239
D_REBUILD #234 type=Decision labels=security,discuss type-labels=1 parent=none
T_REBUILD #235 type=Task labels=bug,security type-labels=1 parent=none
T_RESTORE #236 type=Task labels=bug type-labels=1 parent=none
T_ALERT #238 type=Task labels=bug,low-priority type-labels=1 parent=none
blocked by: [234]
no sequence tokens in titles
       9
```

Every line matches its expected value except `sub-issues: 1`, where 2 is expected; see
Deviations.

## Deviations

1. **#220 has not merged.** It was `OPEN` when this ran, and every body above cites the review
   record it adds. #221 must merge after #220.
2. **Corrections made before running** (commit `3d99702` on this branch). Step 0 was re-checked
   against the tracker as it stood on 2026-11-04, and these bodies were corrected in place:
   - `D_REBUILD`: #226 (merged 2026-11-04) pinned every lean-image conda package that the
     `anaconda=2026.07` metapackage also pins. The list of what still re-resolves on a base move
     now names the four conda packages left unpinned, transitive dependencies, the pip floors and
     `quantecon-book-networks`, and drops the old `environment.yml:32-57` reference. Option (a)
     and the recommendation now say that only the pip half of the Python layer is left to pin.
     Added #222 as the drift the finding predicted: the scheduled rebuild of 2026-10-19
     re-resolved `plotly` to 7.x and broke image export in the lean image. Added the scheduled
     runs since the review (2026-10-12 and 2026-10-26 cached, in 40 s and 24 s; 2026-10-19 and
     2026-11-02 rebuilt, in about 8.5 min), read from the Actions API.
   - `T_RESTORE` and `LOG`: `docs/dev/PLAN.md` backlog item 18 was filed as #228 on 2026-11-04,
     so both now cite #228.
   - `T_PREVIEW`: a Related line for #227 and #230, which change the same preview path.
   - `C135`: decision 1 on #143 (2026-11-04) put the gate in a `gate.yml` in the canary with no
     `v0-next` tag, and that gate tests the `build-jupyter-cache` sibling chain by rewriting its
     four `uses:` lines at test time. The comment now says so, and keeps the consumer-facing side
     (exact pins are not hermetic) as the open input to #138's residual decision. The decision
     records on #143 and the re-scope of #135 were still pending when this ran, so the comment
     anticipates them.
   - `C142`: the lecture matrix has been red again since 2026-10-12 (#222).

   The other bodies were re-checked and left as written. Their line references are as of
   `4550f69`. Since then `main` has moved only by #226 (container environment, Dependabot,
   CHANGELOG), so they still hold.
3. **What Step 0 found on the tracker.** All eight commented issues were open, with no comments
   since 2026-10-06. Filed since the review: #222, #224, #227, #228, #229 and #230. None
   duplicates a new item:
   - #227 makes the preview actions deploy outside `pull_request` when asked (decision 2 on
     #143). It changes when they deploy, not which job holds the provider token, so it is not
     finding M1's job split, and #232 stands.
   - #228 is the owner of finding M6 (`docs/dev/PLAN.md` item 18).
   - #222 is evidence for finding M4 and is now cited in #234.
   - #224 (TeX Live apt cache), #229 (PLAN item 15's residual) and #230 (a PDF check in
     `templates/ci.yml`) are unrelated to the new items.

   Phase 1 of #142 was being built by another session, with no pull request open yet. The
   comment's phase 2 additions are unaffected.
4. **State directory.** The session's sandbox does not allow writes to the home directory, so
   state was kept in `$TMPDIR/qe-handover-2026-10-06` (`/tmp/claude-501/…`) instead of
   `~/qe-handover-2026-10-06`. The session also refused compound shell commands inline, so each
   block was saved to a file and run with `bash file`, as the handover allows, with only the
   state path changed.
5. **T_ALERT took three attempts, and #237 was used up.** The first two creates of `T_ALERT`
   returned HTTP 502 and created nothing. The third was a direct `gh api` call with the same
   payload, run so the response headers could be read, and it created #238. One failed attempt
   used up issue number #237, which returns 404. A title search finds only #238, so there is no
   duplicate. Because the third call bypassed `create()`, its two lines in `ids.env` and
   `subst.sed` were written by hand in `create()`'s format. Re-running Step 2 then skipped all
   six and read back each type and label set.
6. **The tracker's sub-issue counter reads 1.** `sub_issues_summary.total` on #239 stayed at 1
   for several minutes after Step 4. The sub-issue list (REST and GraphQL) returns `[232, 233]`
   in plan order, and both issues report #239 as their parent, so the membership is right and
   only GitHub's counter is behind. Following the handover's rule to stop at a failed check
   rather than work around it, this run left it alone. **Needs a maintainer's eye** if the
   tracker's progress still shows one item. Detaching #233 and attaching it again recomputes the
   counter and keeps the order.
7. **D_REBUILD stays open.** The maintainer decided the scheduled-rebuild question on 2026-11-04:
   option (b), with the Ubuntu base pinned by digest in both Dockerfiles, Dependabot proposing
   base moves as pull requests, the weekly schedule dropped, and the docs that promise weekly
   security updates corrected. As the handover asks, this run did not record the decision or
   close #234. The maintainer's pending decision writes post it on #234 and close it. #235
   carries the implementation.
