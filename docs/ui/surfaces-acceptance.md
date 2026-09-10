# Station UI acceptance

The minimum viewport is 1024×768; also inspect 1366×768 and 1600×1000.
The engine's fixture runner owns mount, geometry, focus, input and screenshots.
A fixture is evidence for its disclosed state, not for live station rendering.

| Surface | Required states | Acceptance evidence |
|---|---|---|
| HUD controls | empty hands, worn equipment, busy action groups, unavailable body | compact/regular/wide HUD and expanded-action fixtures; hands and action targets remain visible |
| Chat and inspection | empty, long log, expanded history, pinned/full receipt | separate bounded scrolling; chat input remains visible |
| Storage | populated, empty, nested containers | real click opens each container; close and store remain reachable |
| Crew board | lobby, full job, condition/respawn | labels explain unavailable choices; keyboard reaches available choices |
| Readouts and matter | populated, empty, long labels, unavailable device | title/status/body/footer; readout values never truncate controls |
| Construction | affordable, insufficient stock, selected recipe, empty roster | material counts beside unavailable arm; selected action has a word |
| Choices and shelves | selected, disabled, zero stock, empty | selection mark and text; stock explains disabled vend |
| Computers | offline, populated/full drives, source diagnostics, conflicts | device artwork, physical controls and status; file workspace fixtures |
| File readers | Markdown, ATMO, PEM, invalid ATMO | preview/source switch; invalid records retain editable source |
| File dialogs | dirty Create then Cancel/Save/Discard | one modal, preserved naming draft, restored focus, exactly one continuation |
| Hover and world overlays | edge action menu, speech/progress | targets stay inside viewport; pixel fonts use native multiples |
| Multiple documents | mixed families and long bodies | independent window scrolling and accessible close controls |

Representative gameplay captures over the actual station complement lab scenes.
Pack-art captures require the delivered atlas; portable engine fixtures do not.
