# Tasks: implement-photo-passes

Checks from `app/` (Flutter 3.47.5): `flutter analyze --fatal-infos`, `dart format
--set-exit-if-changed .`, `flutter test`; from the root `privacy_check.py` and `core_purity.py`. No
private-corpus file in the repository; no Ninox.

## 1. Mobile — dispatch (after `fix-jpeg-frame-header` is merged)

- [x] 1.1 Report first: does the platform decoder apply EXIF orientation (design §3)? State the
      evidence. *Done when* it is at the top of the report. (done: 18a5445)
- [x] 1.2 Image decode to an RGBA buffer at a target size, no new dependency. *Done when* a host test
      decodes a synthetic image at two sizes. (done: 18a5445)
- [x] 1.3 The image pass list of design §2, injectable, stable ids, `p1-native` unchanged. *Done
      when* the order/id/drop tests pass. (done: 18a5445)
- [x] 1.4 Orientation handled per §3 and geometry consistent across passes per §4. *Done when* the
      synthetic oriented-image and two-scale tests pass. (done: 18a5445)
- [x] 1.5 Read-only and cleanup unchanged for images. *Done when* the hash and cleanup tests pass. (done: 18a5445)
- [x] 1.6 Harness reports pass agreement as numbers only. *Done when* the JSON writer test covers it. (done: 18a5445)

## 2. Orchestrator and product owner

- [x] 2.1 Review the lane report; device run on the 18 photographs; numbers only. (done: 18a5445, 19-photograph S22 run in docs/Plan/diario/2026-10-17.md)
- [ ] 2.2 PO reads the numbers; no pass is dropped or weighted before T2.5.
- [x] 2.3 Merge with `--no-ff` after the PO's approval. (done: 18a5445)
