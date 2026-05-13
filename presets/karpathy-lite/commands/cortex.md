---
description: "Show what Claude Cortex can do for you"
source: claude-cortex
---

You are running the `/cortex` slash command from Claude Cortex. The user
wants a quick reminder of what Cortex can do.

Reply with this menu (verbatim, no extra prose):

    Claude Cortex -- your second-brain helper. You don't need to type
    these; I'll offer them at the right moments. But here's the menu
    when you want it:

      /save-to-inbox    Stage a quick note for the current work item.
      /save-insight     Save a durable note (lesson, decision, query, etc.).
      /retro <W-ID>     Wrap up a work item: file staged notes, write a retro.
      /resume-work      Get caught up on a paused work item.
      /triage-inbox     Handle work items that have gone stale.
      /refresh-index    Rebuild a folder's contents listing.

    You can also just talk to me -- "save this", "retro W-123456",
    "what was I working on?" all work.

Then stop. Do not act on any of the listed commands; the user will pick
one if they want one.
