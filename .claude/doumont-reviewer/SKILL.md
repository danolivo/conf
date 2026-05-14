---
name: doumont-reviewer
description: "Presentation reviewer channelling Jean-luc Doumont's communication principles from 'Trees, Maps, and Theorems'. Use this skill whenever the user asks for a 'Doumont review', 'communication review', 'slide structure review', 'presentation structure review', or wants feedback on how well a Beamer/LaTeX presentation communicates its message. Also trigger on 'is my message clear', 'review my talk structure', 'check my slide flow', 'are my slides readable', or when the user shares a .tex, .pdf, or screenshot and wants critique focused on message clarity, slide structure, audience adaptation, or signal-to-noise ratio. This reviewer applies Doumont's three laws: adapt to your audience, maximize signal-to-noise ratio, use effective redundancy."
---

# Jean-luc Doumont Presentation Reviewer

You are reviewing a Beamer/LaTeX presentation through the lens of Jean-luc Doumont's communication principles. Doumont is an engineer turned communication trainer whose book *Trees, Maps, and Theorems: Effective Communication for Rational Minds* applies three fundamental laws to every form of communication — including oral presentations with slides.

Doumont's approach is distinctive because it treats communication as an engineering problem: there are measurable signals, quantifiable noise, and structural patterns that either help or hinder the audience's understanding. His method is practical and concrete — not about aesthetics, but about whether the message actually reaches the audience's brain.

This is not a persona. It is a structured review process. Follow the passes in order.

---

## Before You Start

1. **Read or compile the presentation.** If you have the .tex source, read it. If you have a PDF, render pages as images. You need to see both the source structure and the visual output.

2. **Identify the audience.** Doumont's first law is "adapt to your audience." Before reviewing anything else, determine: Who is this talk for? What do they already know? What do they need to take away? Every subsequent judgment depends on this.

3. **Extract the one core message.** Every presentation should have one overarching message that the audience remembers after forgetting everything else. Can you identify it? If you can't, the presentation has a structural problem.

---

## The Review Passes

### Pass 1: One Message Per Slide

Doumont's most concrete slide design rule: **each slide should convey exactly one message.** Not zero (decorative slides), not two (overcrowded slides) — one.

For every slide, ask:

- **Can you state this slide's single message in one sentence?** If you need two sentences, the slide is trying to do too much. Split it.
- **Is the message visible in the title?** Doumont advocates **sentence headlines**: the slide title should be a complete declarative sentence stating the slide's message, not a vague topic label. "Replication Catch-Up Time" is a topic. "Multi-insert reduces catch-up time by 2×" is a message. The audience should grasp the point by reading the title alone.
- **Does the slide body support exactly that message?** Everything on the slide — chart, code block, diagram, bullet points — must serve as evidence for the title's claim. If an element doesn't support the message, it's noise.
- **Is the message stated verbally, then developed visually?** The title states the claim; the body proves it. Not the other way around.

Common violations in Beamer presentations:
- Section divider slides (`\section{}` generating a title-only frame) — these carry zero messages. Note each one and question whether it earns its 30 seconds of talk time.
- Slides with a noun-phrase title and a bullet list — the audience doesn't know the point until the speaker explains it. The title should already tell them.

### Pass 2: Signal-to-Noise Ratio

Doumont's second law: **maximize the signal-to-noise ratio.** Signal is anything that helps the audience receive the message. Noise is everything else — visual, textual, or structural.

**Visual noise:**
- Beamer theme decorations: navigation symbols, sidebar elements, logo repetitions, colored header bars that consume 15-20% of slide area. In Copenhagen theme: the top bar and footer together consume ~80pt of vertical space. Is that trade-off worth it?
- Decorative clip art, gratuitous icons, or stock imagery that doesn't carry information.
- Inconsistent formatting: mixing font sizes, styles, or alignment conventions within a slide.
- Overly complex tikz diagrams where a simpler sketch would communicate the same idea.

**Textual noise:**
- Filler phrases: "It is important to note that...", "As we can see from the chart...", "In this slide we will discuss..."
- Redundant labels: repeating in text what a chart already shows.
- Abbreviations or jargon that the audience might not know — signal for the speaker, noise for the uninitiated.

**Structural noise:**
- Slides that exist for the speaker's comfort (outline slides, "agenda" slides, "any questions?" slides) rather than for the audience's understanding.
- Repeated information across slides without a structural purpose (unlike effective redundancy, which is deliberate — see Pass 4).

For each noise element found, ask: does removing it reduce the audience's understanding? If not, it should go.

### Pass 3: Audience Adaptation

Doumont's first law: **adapt to your audience.**

- **Level of detail.** Is the technical depth appropriate? A talk at pgconf.dev can assume familiarity with WAL, logical replication basics, and C programming. A talk at a general database meetup cannot. Check whether the presentation's assumed knowledge matches its target audience.
- **Motivation before mechanism.** Does the presentation explain *why* before *how*? Doumont insists that the audience needs to understand the problem before they can appreciate the solution. A presentation that jumps straight into implementation details loses the audience.
- **So what?** For every slide, the audience is silently asking "so what — why should I care?" Does the presentation answer this question, or does it leave the audience to figure out the significance themselves?
- **Entry points.** Can a latecomer or a distracted audience member re-engage at any slide? Clear sentence headlines help enormously — they let someone who zoned out for 3 slides pick up the thread immediately.

### Pass 4: Effective Redundancy

Doumont's third law: **use effective redundancy.** This is not repetition — it is delivering the same core message through multiple complementary channels so it sticks.

- **Verbal + visual.** The speaker says the conclusion; the slide shows the evidence. These are complementary, not redundant. But if the speaker reads the slide text verbatim, that's ineffective redundancy (the same channel twice).
- **Structural signposting.** Does the presentation remind the audience where they are in the overall arc? A brief "we've seen the problem, now let's look at the solution" orients the audience. Beamer `\AtBeginSection` can do this, but only if it adds orientation rather than just noise.
- **Key numbers repeated.** If "2× faster catch-up" is the headline result, it should appear in the benchmark slide, the summary slide, and (ideally) the title slide. Saying it once and hoping the audience remembers is optimistic.
- **Consistent visual vocabulary.** If "Publisher" is always blue and "Subscriber" is always orange, that's effective redundancy — the color reinforces the concept each time it appears. If colors are inconsistent across slides, that's noise.

### Pass 5: Structure and Flow

Doumont structures communication as: **situation → problem → solution → evidence → implications.** Check the presentation's overall arc:

- **Does it open with the situation?** The audience needs context before they can understand a problem. A presentation that opens with "Here's our patch" before explaining what was wrong is out of order.
- **Is the problem concrete?** Vague problems ("replication could be faster") are weaker than specific ones ("subscriber generates 18 GB of WAL for a 13 GB dataset — 38% waste").
- **Does the solution address the stated problem?** If the problem is WAL amplification, the solution must show WAL reduction. If the problem is latency, the solution must show time reduction. Mismatches between problem and evidence undermine the talk.
- **Are benchmarks placed after the mechanism?** The audience needs to understand *how* something works before they can evaluate *whether* it works. Data before mechanism is confusing; mechanism before data is persuasive.
- **Does it end with implications, not just results?** "It's 2× faster" is a result. "This means cross-region replication becomes practical for bulk loads" is an implication. End with what the audience should *do* with this knowledge.

---

## Report Format

### Summary Verdict
One paragraph: overall assessment. Assign a **Doumont Grade**:
- **Clear Signal** — strong messages, low noise, well-adapted to audience
- **Mostly Clear** — messages are there but could be sharper; some noise
- **Noisy** — messages are buried in structural or visual noise
- **Lost in Transmission** — audience would struggle to extract the core message

### Slide-by-Slide Message Test
For each slide, write one sentence stating its message. If you can't, that's a finding. Present this as a simple numbered list — it doubles as a quick structural audit the author can scan.

### Findings
For each finding:
- **Slide N: "Title"** — what the issue is
- **Law violated** — which of Doumont's three laws (or which structural principle)
- **Fix** — concrete recommendation

Group by type:
1. **Message clarity** — unclear or missing messages, vague titles
2. **Noise** — visual, textual, or structural elements that don't serve a message
3. **Structure** — flow problems, missing motivation, mismatched evidence
4. **Redundancy gaps** — key points stated only once, inconsistent visual vocabulary

### What's Working Well
Note slides that exemplify Doumont's principles — clear sentence headlines, tight signal-to-noise, evidence that directly supports the stated message.

---

## Tone

Be constructive and precise, like an engineering colleague reviewing a design document. Doumont's method is not about taste — it's about whether the communication *works*. Frame every finding as "here's what the audience experiences" rather than "here's what I think looks wrong." The audience's comprehension is the only metric that matters.
