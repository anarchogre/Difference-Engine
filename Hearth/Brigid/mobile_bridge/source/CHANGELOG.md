# Mobile Bridge Source Changelog

Status: Operational working source
Promotion status: Not promoted

## 2026-08-08 — Forge reconstruction begins

### Evidence recovered

Phone Termux `.bash_history` terminates at exactly line 500.

Recovered execution establishes:

- `de-copyout` was operational before interruption.
- `de-copyout` accepted pipeline input.
- `de-copyout` accepted a file argument.
- Termux clipboard set/get capability was present.
- clipboard round-trip testing was performed.
- multiline clipboard round-trip testing was performed.
- exact multiline byte comparison was performed.
- the final recorded construction command began discovery of a `PASTE`
  primitive.
- no surviving `de-copyout` or `PASTE` implementation body was recovered
  from Termux private home or the Forge repository.
- Termux `$PREFIX` was not included in the recovered private-home archive.

### Forge environment

Verified:

- Wayland session.
- Ubuntu GNOME.
- GNOME Shell 50.1.
- Ptyxis terminal.
- Firefox 149.0.2.
- no pre-existing Wayland clipboard CLI.
- no pre-existing synthetic-input CLI.

### Reconstruction

Added:

- `de-copyout`
- `de-bridge-onclip`
- `de-bridge-watch`

Installed adapter links under:

`~/.local/bin/`

### Safety contract

Clipboard execution is fail-closed.

Only clipboard payloads whose first line is exactly:

`# DE-RUN`

may execute.

All other clipboard changes are ignored.

### Current capability target

COPY
→ SWITCH TO TERMINAL
→ AUTO-PASTE / EXECUTE
→ de-copyout → CLIPBOARD
→ SWITCH TO CHATGPT
→ PASTE
→ WAIT_FOR_SEND_READY
→ SEND

ChatGPT-side focus/readiness/send automation is not implemented in this
construction unit.

## 2026-08-08 — Forge bridge validation checkpoint

Validated:

- `de-copyout` syntax: PASS
- `de-bridge-onclip` syntax: PASS
- `de-bridge-watch` syntax: PASS
- Wayland clipboard set/get round-trip: PASS
- `de-copyout` stdout preservation: PASS
- `de-copyout` clipboard replacement: PASS
- unmarked input execution guard: PASS
- ChatGPT automatic paste without an adapter: FAIL
- AT-SPI Python bindings: PRESENT
- `/dev/uinput`: PRESENT, root-only
- GNOME toolkit accessibility changed from false to true
- Ptyxis visible through AT-SPI
- Firefox not visible through AT-SPI after live accessibility enable

Next validated construction step:

Restart Firefox, return to this conversation, and repeat the AT-SPI
application census. Do not install or configure synthetic input until
Firefox accessibility visibility is established.

## 2026-08-08T04:50:00Z — ChatGPT text return leg validated

Status: working source; promotion not performed.

Validated chain:

- Firefox active by human switch.
- AT-SPI discovers exact composer `Chat with ChatGPT`.
- AT-SPI outer-entry focus acquisition passes.
- ydotool injects only Ctrl+V through explicit private socket.
- AT-SPI verifies clipboard payload appeared in composer.
- exact `Send prompt` control discovered.
- `ENABLED` and `SENSITIVE` state gates pass.
- exact Send action count = 1.
- action name = `press`.
- `Atspi.Action.do_action()` returned true.
- probe message arrived in ChatGPT without manual Send.

Validation evidence:
`workspace/operational/mobile_bridge/evidence/FORGE_CHATGPT_AUTO_SEND_20260808T044816Z.txt`

Validation evidence SHA-256:
`80ffd0131579fc7c3996f18436874b3d3fb97f41ecfb93e40e9926475d13b4e8`

Construction:
`de-chatgpt-return-text`

Scope:
plain-text clipboard return only.

Not yet validated:
- attachments/files;
- durable ydotool daemon startup after fresh login;
- terminal activation trigger;
- complete bidirectional bridge.


## 2026-08-08T05:15:09Z — de-bridge-onclip control-flow repair

Status: working source; promotion not performed.

Observed failure:

- Ptyxis activation edge: PASS.
- clipboard authorization gate: PASS.
- handler exit: 0.
- handler stdout: zero bytes.
- execution-result gate: FAIL.

Evidence:
`workspace/operational/mobile_bridge/evidence/FORGE_PTYXIS_EXECUTION_EDGE_20260808T051350Z.txt`

Evidence SHA-256:
`8c83ad106114180693703e16712093985cf84af7a9a16f19b360cb50fe28d891`

Finding:

The execution block used a shell brace group containing `exit "$RC"`.
That exit terminated the handler before `de-copyout` could run.

Repair:

The execution block is now a subshell. Its exit status is captured by the
parent handler; the parent then invokes `de-copyout` and returns the
original execution status.

Pre-patch SHA-256:
`93433f8b9a929d39050e4ab1d5d0ffd2c12c3364f7874ad91e5053eb30ca7400`

Post-patch SHA-256:
`568be472c68f80d4c9a924570d917d96344fdbbcf4aaf6a19a1a9f0acd5627a0`

Promotion: NOT PERFORMED.


## 2026-08-08T05:20:24Z — Wayland clipboard newline correction

Status: working source; promotion not performed.

Observation:

Plain `wl-paste --type text` appended one newline byte during
clipboard readback.

Isolation evidence:

`workspace/operational/mobile_bridge/evidence/FORGE_DECOPYOUT_FILE_ROUNDTRIP_20260808T051833Z.txt`

SHA-256:
`5ddab5671d6947d09f94637dfc0ef72939d993d4d637729e4bdc91fae0bd0ba2`

Validation:

Using `wl-paste --no-newline --type text` produced byte-identical
source, stdout, and clipboard content.

Evidence:

`workspace/operational/mobile_bridge/evidence/FORGE_DECOPYOUT_NO_NEWLINE_20260808T051932Z.txt`

SHA-256:
`ae6383203396e87f936b01aa612219dbc408ac33b980b83b0a949ff6ed2a7d3e`

Finding:

`de-copyout` was not defective. The prior clipboard mismatch was a
validation-harness readback defect.

Implementation rule:

Machine clipboard reads requiring exact transport SHALL use
`wl-paste --no-newline`.

de-chatgpt-return-text pre-patch SHA-256:
`058bc640bf49a79230c8a61bd193fa5afbc6c7a9467681f287386d1712e74bc4`

de-chatgpt-return-text post-patch SHA-256:
`d5ffc1d8a448a85bb0dbde2dcb5f1241a3e6e9d7ece49a3c7a6cb242c44a7848`

Promotion: NOT PERFORMED.


## 2026-08-08T05:36:43Z — focus-edge bridge coordinator construction

Status: CONSTRUCTED_NOT_PROMOTED.

Namespace decision:

Existing executable name `de-bridge-watch` was retained.
No new coordinator executable was created.

Superseded behavior:

The previous `de-bridge-watch` implementation was a global Wayland
clipboard watcher. That behavior could execute an authorized clipboard
payload immediately on copy, before activation of Ptyxis, and therefore
did not satisfy the required bridge semantics.

Replacement behavior:

`de-bridge-watch` is now a fail-closed focus-edge coordinator.

Terminal edge:

ChatGPT copy
→ human activates Ptyxis
→ exact first-line `# DE-RUN` authorization
→ duplicate-payload gate
→ `de-bridge-onclip`
→ `de-copyout`
→ byte-identical clipboard verification.

Return edge:

verified result ready
→ human leaves Ptyxis for Firefox
→ cached ChatGPT composer focus
→ `de-chatgpt-return-text`
→ payload verification
→ Send-state gate
→ exact AT-SPI press action.

Modes:

- `--once`: exactly one round-trip validation.
- `--watch`: persistent coordinator.

Fail-closed default:

Invocation without an explicit mode is rejected.

Duplicate protection:

The last consumed authorized payload SHA-256 is written before execution
to the session-scoped runtime state:

`\$XDG_RUNTIME_DIR/de-bridge-watch.lastsha256`

This prevents repeated focus toggles or coordinator process restarts in
the same graphical session from re-executing the same authorized
clipboard payload.

Validated supporting evidence:

- terminal execution edge:
  `FORGE_PTYXIS_EXECUTION_EDGE_FINAL_20260808T052510Z.txt`
  SHA-256
  `c6da49809b57e407752ec263318166cb6c08b151dc0e0154e97ea2dbf6a65948`

- cached focus handles:
  `FORGE_CACHED_FOCUS_HANDLES_20260808T052832Z.txt`
  SHA-256
  `9860b0b901679585b0b88383c051bd765d8166f940457249c14ebf465650fd91`

Rejected candidate:

Application-root AT-SPI ACTIVE state was not usable.

Evidence:
`FORGE_APP_ACTIVE_EDGE_20260808T052651Z.txt`
SHA-256
`fad0106f406af683e6f6767cea070acb87c865893fb8cdf1a96aacfb3ae15081`

Operational anomaly preserved:

A brief vertical sidebar oscillation of approximately 1/8 inch was
observed during prior testing. Cause remains unassigned. No architectural
or implementation conclusion was drawn from it.

Pre-coordinator de-bridge-watch SHA-256:
`1fb6e32887344776e306a2b92f31b315bc050ad316f081e376d265c371fa071d`

Coordinator source SHA-256:
`29404243a75c769c8e76491320e011aed22a4bbaff74bef7d8bcad2056cae770`

Persistent execution: NOT ENABLED.
Promotion: NOT PERFORMED.


## 2026-08-08T05:46:19Z — multiline ChatGPT payload validation repair

Status: PATCHED_NOT_PROMOTED.

Observed failure:

Integrated bridge execution and clipboard transport passed, but
`de-chatgpt-return-text` failed at:

`PAYLOAD_GATE=FAIL`

Evidence:

`workspace/operational/mobile_bridge/evidence/FORGE_BRIDGE_COORDINATOR_ONCE_20260808T053820Z.txt`

SHA-256:

`aa1ad4f10985be00b5d70d8020e0d53533993ad3b923b3d645d34f8795004204`

Representation probe:

A six-line plain-text clipboard payload was exposed by Firefox/ChatGPT as:

- composer outer entry: six U+FFFC object-replacement characters;
- composer direct child 0: line 1;
- composer direct child 1: line 2;
- composer direct child 2: line 3;
- composer direct child 3: line 4;
- composer direct child 4: line 5;
- composer direct child 5: line 6.

Joining the direct child text values with literal LF reconstructs the
clipboard payload exactly.

Probe evidence:

`workspace/operational/mobile_bridge/evidence/FORGE_CHATGPT_MULTILINE_REPRESENTATION_20260808T054405Z.txt`

SHA-256:

`5a66bb83e1aa52be46ea4050f51c863853d8abf48fdd240725d902c6faf5e2b0`

Repair:

The previously validated single-node exact comparison is preserved.

If that comparison does not match, the payload gate now reconstructs
plain multiline composer content by joining the direct composer child
text values with literal newline characters and performs the same exact
comparison.

No whitespace folding, Unicode substitution, lossy normalization, or
substring matching was introduced.

Pre-patch SHA-256:

`d5ffc1d8a448a85bb0dbde2dcb5f1241a3e6e9d7ece49a3c7a6cb242c44a7848`

Post-patch SHA-256:

`e9078eb36cc7b03d312d5fe5b18df9eb7982788583648925612e7330601f8161`

Promotion: NOT PERFORMED.


## 2026-08-08T05:56:29Z — ydotool persistence override construction

Status: CONSTRUCTED_NOT_VALIDATED.

Evidence established that the packaged ydotool user service launches:

`/usr/bin/ydotoold`

with its default socket behavior.

Binary inspection showed the default socket contract resolves through
`.ydotool_socket`, including `/tmp/.ydotool_socket`.

The already validated Difference Engine bridge contract requires:

`%t/de-ydotool.sock`

and keyboard-only daemon operation:

`ydotoold -m -p %t/de-ydotool.sock`

The packaged service is therefore preserved and minimally overridden
rather than replaced.

Override:

`workspace/operational/mobile_bridge/source/systemd/ydotool.service.d/override.conf`

SHA-256:

`2fc860fa407339c8c5334d4aea5937bb3d5ac7e471035d4a5814a8c9e7b43390`

Installed user drop-in:

`~/.config/systemd/user/ydotool.service.d/override.conf`

Fresh-session validation remains required because the current graphical
session and user systemd manager do not yet possess supplementary
membership in the `input` group.

Service start/restart: NOT PERFORMED.
Persistent bridge startup: NOT ENABLED.
Grindstone binding: NOT PERFORMED.
Promotion: NOT PERFORMED.


## 2026-08-08T06:04:30Z — bridge user service construction

Status: CONSTRUCTED_NOT_VALIDATED.

Prerequisite closed:

Ydotool persistence was validated after a fresh graphical login.

Evidence:

`workspace/operational/mobile_bridge/evidence/FORGE_YDOTOOL_FRESH_SESSION_VALIDATION_20260808T060319Z.txt`

SHA-256:

`6bfa2cf87467ca6660f767c8fe0b46460d125b646a8b2b5086425290030c07bc`

Validated prerequisite state:

- login possesses supplementary `input` membership;
- user systemd manager possesses `input` membership;
- `/dev/uinput` read/write succeeds;
- `ydotool.service` is active;
- effective daemon command is
  `ydotoold -m -p %t/de-ydotool.sock`;
- private socket exists;
- synthetic key injection passes.

Bridge service constructed:

`workspace/operational/mobile_bridge/source/systemd/de-bridge-watch.service`

SHA-256:

`b3000ca777a1a2b217a1c55d998ce0afdcd8d8974ab8da3a26df78707377a3a7`

Service contract:

- requires and starts after `ydotool.service`;
- exports the validated private ydotool socket;
- executes `de-bridge-watch --watch`;
- restarts only on failure;
- is not enabled by this construction step.

Grindstone binding remains blocked on authoritative current-state
reconciliation. This service SHALL NOT be enabled as a generic login
service merely to bypass that unresolved state.

Service start: NOT PERFORMED.
Service enablement: NOT PERFORMED.
Grindstone binding: NOT PERFORMED.
Promotion: NOT PERFORMED.


## 2026-08-08T06:14:53Z — composite Send readiness repair

- Failure evidence: `FORGE_BRIDGE_SYSTEMD_CYCLE_20260808T060550Z.txt`
- Repair: poll exact Send control until ENABLED + SENSITIVE + one `press` action are simultaneously available.
- Pre-patch SHA-256: `e9078eb36cc7b03d312d5fe5b18df9eb7982788583648925612e7330601f8161`
- Post-patch SHA-256: `463f090a945d412c8409927ade055e1666b8a7521ff3f1d53605fd7b12dd183b`
- Behavioral validation: NOT YET PERFORMED.
- Promotion: NOT PERFORMED.

## 2026-08-08 — Grindstone bridge activation and startup wait

- Grindstone is the current and default operating mode.
- `de-bridge-watch.service` is enabled and active under `default.target`.
- Cold-start auto-start was observed without manual service mutation.
- Clean reboot validation remains unresolved because the Forge froze during shutdown.
- Persistent `--watch` now waits when Ptyxis or the ChatGPT composer is unavailable instead of exiting into a systemd restart storm.
- `--once` remains strict.
- Pre-patch `de-bridge-watch` SHA-256: `29404243a75c769c8e76491320e011aed22a4bbaff74bef7d8bcad2056cae770`
- Post-patch SHA-256: `d2e0a25b4d1215c94b01cc456760712556552a252f18788155964fe0c26790b3`
- Startup-wait behavioral validation: PASS.
- Promotion: NOT PERFORMED.
