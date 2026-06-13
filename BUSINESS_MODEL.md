# Business Model — v2 (improved)

Implementation brief for Claude Code. Supersedes `Shivaliva_Shanty_Business_Model.docx`.
This version is the result of a multi-lens review (monetization strategy, LLM unit economics,
brand/community fit, platform + legal + ops, revenue/GTM) with every load-bearing number
adversarially re-checked against the real proxy code and current API pricing.

> The original draft was smart and self-aware — it flagged the right three risks. The review's
> verdict is that those risks are not "tune later" footnotes; they are the model. Resolving them
> flips the plan from a brand own-goal into something that fits the game and actually banks money.

---

## TL;DR — the one decision

**Drop the $4.99/month subscription. Sell the game once; make the chat a headline feature you OWN, not a meter you rent.** Everything below is downstream of that.

The monthly sub is the single worst-fit option on the board for this specific game, for four independently-verified reasons. The good news the review surfaced: **the cost math means you never needed a subscription in the first place.**

---

## 1. Why the subscription has to go (all verified)

1. **It re-creates the exact thing the game is built against.** A monthly fee IS a recurring charge, and "earn-and-keep / no recurring charges" is both your #1 brand differentiator and the #1 documented reason Puzzle Pirates players quit. The "it only gates a social feature, not power" technicality does not survive contact with a returning player: stop paying, lose the feature that sold you the game, and it reads as decay even though gold never decays. *(Verdict: CONFIRMED.)*

2. **The salary math is upside-down.** $680/mo (2,500 AED) needs ~137 subs gross / ~195 net, **every month, churn-replaced**, versus the draft's own realistic ceiling of 25–450 *lifetime* subs. A one-time $9.99 base game (net ~$6.99 after a 30% store cut) clears $680 at ~98 sales/month and books real, non-churning money. *(The draft's subscriber-count arithmetic had a small error; corrected, the net-of-fees number is ~195, which only makes the point sharper.)*

3. **Charging breaks an SLA the stack can't honor.** Selling "unlimited" and especially "priority response" implies always-on. The proxy is a single Render *free-tier* process that sleeps after ~15 min (30–50s cold start), resets its counters on restart, serves FIFO with no priority lane, and lets one heavy user exhaust the shared daily token budget for everyone. For a free product that's a shrug; for a $4.99/mo product every one of those is a refund/chargeback. Charging *forces* a ~$7/mo always-on tier + per-user budgets you haven't built. *(Verdict: CONFIRMED.)*

4. **Subscriptions are the highest-ops, highest-friction path.** itch.io has **no** native subscription billing; Steam explicitly calls recurring billing "not well supported." So a sub forces an off-platform processor + a license-key flow you build/host/support, and recurring billing carries ~1–2% chargeback rates with ~70% of disputes being "forgot I subscribed." One-time purchases are first-class on both stores and avoid all of it. *(Verdict: CONFIRMED.)*

---

## 2. The cost reality (this is the part that frees you)

Modeled against the **real** proxy (`MAX_TOKENS_CAP` 400, 24-msg history, ~2.5k-token system prompt) and re-derived by the verifier:

| Per chat turn | Cost |
|---|---|
| Haiku 4.5, **uncached** | ~$0.0035–0.0045 |
| Haiku 4.5, **with prompt caching** | ~$0.0019–0.0027 (a ~40–55% cut) |
| **DeepSeek-tier (your current default)** | ~$0.0003–0.0004 (a few hundredths of a cent) |

| A user maxing 100 msgs/day for a full month | Cost |
|---|---|
| Haiku uncached | ~$9–13 |
| Haiku cached | ~$4–8 |
| **DeepSeek (current default)** | **~$0.80–1.30** |

Two things fall out of this:

- **No realistic human ever puts a "$4.99 unlimited" buyer underwater** on DeepSeek or cached-Haiku (break-even is hundreds-to-1,000+ messages/day). The scary "a whale bleeds me dry" story is fiction at the tiers you actually run.
- **The real (small) leak is the FREE tier on Haiku, not subscribers.** And the fix isn't a paywall — it's **prompt caching**, which is the single highest-leverage change and isn't wired in yet (see §6).

So: the feature is cheap enough to give away generously. Metering it is solving a problem you don't have, at the cost of the brand and the marketing hook.

---

## 3. The improved model

**Anchor: a one-time premium base game.** Free, generous **demo** (first island / a capped voyage, with chat fully on) feeding a paid full game at **$9.99** (**$7.99** launch week). "Chat freely with the whole crew" is the *headline selling point of the purchase*, not a metered add-on.

**Chat: a delightful bonus, never a dependency or a meter.** The 7-puzzle adventure + voyage loop is already fully complete without chat — keep it that way. Every player (incl. demo) gets chat that *feels* limitless. Abuse is handled **invisibly** by a high fair-use ceiling (~300–500/day) with an in-world line ("the crew's worn out, give 'em a rest") and **never a buy-button**. Your wallet is *already* protected server-side (global 1.5M-token/day budget + per-IP caps + kill switch + capped provider balance); "unlimited" is in fact already silently capped at 400/day per IP.

**Secondary stream (one, brand-safe): a one-time "Supporter Pack."** Name in credits + a few cosmetic-only items (ship skin, nameplate, a prestige trophy). This is the design-sanctioned cosmetic sink — pay *more* without anyone paying for *power* or a *monthly fee*. Later: cosmetic DLC packs, then a soundtrack once real music exists.

**If you ever truly need to meter chat (you probably won't): one-time unlock or buy-and-keep credits — never a sub.** A one-time "unlimited crew conversations" unlock ($4.99–9.99) or "Stardust Tokens" credit packs ($1.99/1,000, $6.99/5,000) raise the same money while honoring earn-and-keep (you're buying a *service*, kept forever — never gold, never power). Rename anything called a "Pass" (pass = recurring). **Don't build this until telemetry shows chat cost is actually a problem.**

---

## 4. Sequencing (this is the strategy)

The hard truth every lens landed on: **revenue is gated by playerbase size, not by which streams exist.** With zero players, every stream multiplies by zero. So:

- **Phase 1 — Growth / playtest (NOW):** free demo + **free, unmetered chat** + a "support Trojan Bulldog" name-your-price tip jar on itch. Spend the energy you'd have spent on billing plumbing on **visibility**: a Steam page with a wishlist button, devlogs (#2 is shipped), short clips built around the chat hook, and a Steam Next Fest demo slot. *Metering the hook now would actively sabotage the word-of-mouth you need.*
- **Phase 2 — Paid launch:** paid base game on itch + Steam. *Optionally* switch on the one-time chat unlock / credit packs.
- **Phase 3 — Post-launch (you have a population):** cosmetic DLC (ship skins, NPC outfits, parlor decor).
- **Phase 4 — Once real music exists:** soundtrack pack.

**Realistic target math:** ~$680/mo sustained needs roughly **2,000–6,000 lifetime owners**, or a Steam launch fed by **~15,000–40,000 wishlists**. That is a marketing problem to chip at over months, not a pricing knob. Treat $680/mo as a milestone the funnel grows into, not a launch-day baseline.

---

## 5. The three original risks — resolved

- **Risk 1 (recurring fees vs. the founding principle):** RESOLVED by dropping the sub for one-time purchase + a one-time unlock/credits if ever needed.
- **Risk 2 (per-message economics):** RESOLVED — costs are a fraction of a cent on the default provider; the only leak (free-tier Haiku) is closed by prompt caching, not by a paywall.
- **Risk 3 (legal/store policy):** RESOLVED for the realistic path — itch.io and Gumroad are merchant-of-record (they handle EU/UK VAT and global sales tax for you), and at this revenue a UAE solo dev owes 0% corporate tax (under AED 375k) and sits far below the AED 375k VAT-registration threshold. Cross-border tax is **not** a deciding factor. *One open item to confirm cheaply: that Gumroad currently pays out to a UAE-based creator (run a $1 live test before building anything).*

---

## 6. The one technical to-do worth doing regardless: prompt caching

Independent of which pricing model you pick, **wire Anthropic prompt caching into the proxy.** It's free money (a ~40–55% cut on the Haiku path) and it's the thing that makes the free tier costless.

- Today, `proxy/server.js` (`buildUpstream`, anthropic branch) sends `system` as a **plain string with no `cache_control`** → **0% of calls are cached** (verified against the source).
- `autoloads/npc_brain.gd` `compose_system` already builds an overwhelmingly **static** prefix (WORLD_RULES + VOICE_RULES + HUMAN_RULES + gazetteer + persona, well over Haiku's 4096-token cache floor) with only a small dynamic tail.
- **Change:** emit `system` as a 2-block array — a stable cached block (`cache_control: {type: "ephemeral"}`) + a volatile uncached tail (time-of-day, affinity, live scene/voyage context, the player's line). The 5-minute cache TTL lines up perfectly with an active back-and-forth.

(This is a code change only; deploying it to Render is your call.)

---

## 7. Public-copy guardrails (unchanged, still apply)

Never the literal word "AI" in user-facing strings (say "crew conversations", "chat with the crew"). Never "Troy" in public copy (use "Trojan Bulldog"). No em-dashes, no "---" rules in public copy; emojis OK. Never gate gameplay behind any purchase. Gold stays earn-only, never real-money-purchasable. Fail chat gracefully if the proxy is down (clear message, never a crash).

## 8. Comparables (verified web research, June 2026)

The market evidence backs every major call above.

- **A direct comparable proves the model: Suck Up!** — a shipped game whose whole loop is talking to LLM-powered NPCs. It is sold as a **one-time purchase, and that purchase price is what covers the per-interaction LLM API cost.** This is exactly the recommended structure (chat baked into a one-time buy), validated by a real product in the same niche. (Dev: Proxima.)
- **The cautionary tale is real and severe: Replika.** It charged about **$69.99/year** for an emotional-chat feature (ERP), then **removed it in Feb 2023 with no refunds** → documented user grief and a major backlash; it had to partially restore the feature for legacy users. The lesson for us is sharp: a recurring charge on an emotional AI-chat feature, and especially altering/removing it later, is the worst-case community outcome. Keep chat baked in and stable.
- **AI Dungeon** has repeatedly churned between "energy" and "credit" systems to cover AI cost; metered generation is the friction-heavy path. Avoid metering the hook.
- **Wishlist → sale, refined (GameDiscoverCo 2024-25):** ~**0.15x** of wishlists convert to sales in launch week for games with 10k+ wishlists, **but for titles priced over $10 the median drops to ~0.10x** (e.g. 50k wishlists ≈ ~8.5k first-week sales at the 0.17x top end; far less at >$10). Variance is enormous (10x lower to 20x higher than median). The top performers are **social/co-op/word-of-mouth** titles with **viral, clippable moments** — which is precisely the strength of the crew-chat hook. So: the >$10 price is fine, but it makes wishlist VOLUME and a clippable demo matter more, reinforcing §4's growth-first sequencing.

Sources: [GameDiscoverCo — state of Steam wishlist conversions 2024-25](https://newsletter.gamediscover.co/p/the-state-of-steam-wishlist-conversions) · [AI NPCs / Suck Up! cost model](https://wanderfolk.ai/ai-npcs-in-games/) · [Replika ERP removal + backlash (Wikipedia)](https://en.wikipedia.org/wiki/Replika) · [Replika $69.99 ERP charge then discontinued](https://www.michaelghurston.com/2023/02/replika-charged-users-69-99-for-erp-then-discontinued-it/) · [AI Dungeon energy/credits](https://en.wikipedia.org/wiki/AI_Dungeon)
