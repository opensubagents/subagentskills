# lane-quirks.md

Quirks learned while authoring the three scrape recipes against the 18 Anthropic subprocessors. Each is a real failure mode that bit during the session; encoded here so the next agent doesn't re-derive them.

## trust.anthropic.com itself is Vanta-rendered

A plain fetch of https://trust.anthropic.com/subprocessors returns only the meta tags — the subprocessor table renders client-side from the Vanta SDK. The list has to be maintained by hand in data/subprocessors.json. When Anthropic updates the page, edit the JSON and bump verified_at.

Do NOT try to parse the HTML; you will get nothing useful and waste a fetch round-trip.

## npm lane

Scrape, don't search. registry.npmjs.org/-/v1/search?text=scope:X looks like a scope filter but is actually text-fuzzy — it returns packages whose name OR description contains the string. text=scope:aws-sdk returns 123,915 results, almost none of which are under @aws-sdk/. Use the HTML org page instead.

Use a real browser User-Agent. www.npmjs.com sits behind Cloudflare WAF. The default Node fetch UA gets 403s on some IP ranges. The skill's npmLane sets a Chrome UA explicitly. If you still get 403, retry from a different IP — ElevenLabs hit this in the verified snapshot.

firstPagePackages is a floor, not a total. The org page paginates client-side. The skill counts distinct /package/@slug/X anchors on page one only. A real total requires walking pagination, which the skill skips for cost.

Unscoped flagship packages return 0. Cloudflare publishes the unscoped cloudflare package; Twilio publishes twilio. Their @cloudflare/* and @twilio/* scopes are nearly empty. The snapshot records 0 with an npmNote — this is correct, not a bug.

## github lane

Use Search, not list-repos. GET /orgs/{org}/repos returns at most 100 per page and the count requires walking Link headers. GET /search/repositories?q=user:{slug}&per_page=1 returns the canonical total_count immediately with one HTTP call.

Watch the rate limit. Unauthenticated, the search API is 10 req/min per IP. The report tool fans out 16 of these in parallel — fine for one call, but two reports within a minute will hit 429s. Add a GITHUB_TOKEN Authorization: Bearer header if you need to run this in a loop.

Slug case matters. GitHub login slugs are case-insensitive in URLs but the API returns them in canonical case. aws works; AWS works; the canonical login is aws. The seed uses the canonical form.

## skills.sh lane

Read the meta description, not the page body. The page is Next.js-rendered; the body counts appear after hydration. The <meta name=description> tag is server-rendered and contains the canonical string `Browse N agent skills published by X across M repositories`. Match that regex.

404 is meaningful. Sentry has no skills.sh/sentry page (404 in the snapshot). That's a real "this vendor isn't on skills.sh" answer, not a fetch failure. The skill records null with a skillsShNote. Don't "fix" the 404 by guessing slugs.

Don't invent slugs for vendors without a presence. WorkOS, Intercom, Twilio, Iterable, Sift, Arkose Labs, Brave, ElevenLabs, Palantir, TurboPuffer all have skillsSh: null because skills.sh has no page for them as of 2026-05-21. Leave them null.

## Why the verified counts may drift

- npm: new packages published any day.
- github: repos created/archived continuously; total_count from search excludes archived if archived:false is appended (not in the skill, included by default).
- skills.sh: refreshed whenever the maintainers re-index.

The snapshot is a point-in-time read for fast lookup. When current numbers matter, call anthropic_subprocessor_report for the live fan-out.
