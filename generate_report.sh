#!/bin/bash
# Scheduled report generation from board.json
set -e
SRC="/home/mort/ai/ideas"
DATE=$(date -u +"%Y-%m-%d")
echo "[$(date -Iseconds)] Generating report for $DATE"
cd "$SRC"
# Generate report.html and report_*.html via python (same as manual)
python3 << 'PY'
import json, pathlib, datetime, math, html
board=json.loads(pathlib.Path("board.json").read_text())
date_str=datetime.datetime.utcnow().strftime("%Y-%m-%d")
gen_time=datetime.datetime.utcnow().isoformat()+"Z"
def fmt_people(n):
    if n>=1e9: return f"{n/1e9:.1f}B"
    if n>=1e6: return f"{n/1e6:.0f}M"
    return str(n)
def total_impact(imp, people):
    return imp*math.log10(people)
ideas=[t for t in board["tasks"] if t["type"]=="IDEA"]
rows=[]
for idea in ideas:
    imp=idea["initial_scores"]["impact_per_person"]
    feas=idea["initial_scores"]["feasibility"]
    know=idea["initial_scores"]["knowledge_share"]
    people=idea["people_affected_est"]
    ti=total_impact(imp, people)
    final=0.4*ti +0.3*feas+0.3*know
    researches=[c for c in board["tasks"] if c["parent_id"]==idea["id"] and c["type"]=="RESEARCH"]
    rows.append((final, idea, len(researches), ti, researches))
rows.sort(key=lambda x: x[0], reverse=True)
base_url="https://prometheananthropo.github.io/ForHumanity"
github_raw="https://raw.githubusercontent.com/prometheananthropo/ForHumanity/main"
html_out=[]
html_out.append(f"""<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Humanity Board - Snapshot {date_str}</title>
<style>
body{{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:1000px;margin:2rem auto;padding:0 1rem;line-height:1.5;color:#111;background:#fff}}
header{{border-bottom:3px solid #222;padding-bottom:1rem;margin-bottom:1.5rem}}
h1{{margin:0;font-size:2rem}}
h2{{margin-top:2.5rem;border-bottom:2px solid #222;padding-bottom:0.3rem}}
h3{{margin-top:1.5rem}}
table{{width:100%;border-collapse:collapse;font-size:0.85rem}}
th,td{{border:1px solid #ddd;padding:6px 8px;text-align:left}}
th{{background:#111;color:#fff}}
tr:nth-child(even){{background:#fafafa}}
.badge{{display:inline-block;padding:2px 8px;border-radius:999px;font-size:0.72rem;background:#eee}}
.badge.outside{{background:#ffe8a3;border:1px solid #e6c200}}
.card{{border:1px solid #ddd;border-radius:10px;padding:1.2rem;margin:1.2rem 0;background:#fff;page-break-inside:avoid}}
.meta{{color:#555;font-size:0.82rem}}
a{{color:#0b57d0}}
pre{{white-space:pre-wrap;background:#f6f8fa;padding:0.7rem;border-radius:6px;font-size:0.85rem}}
.snapshot{{background:#fff3cd;border:1px solid #ffe69c;padding:0.8rem;border-radius:6px;margin:1rem 0}}
</style></head><body>""")
html_out.append(f"<header><h1>Humanity Living Conditions — Snapshot Report</h1><div class='snapshot'><strong>Dated:</strong> {date_str} (generated {gen_time}) — Static snapshot. Board Live: <a href='{board.get('live_url')}'>{board.get('live_url')}</a> • Tasks: {len(board['tasks'])} • RESEARCH: {len([t for t in board['tasks'] if t['type']=='RESEARCH'])} • Pseudonym: <code>{board.get('pseudonym',{}).get('npub','')}</code></div></header>")
html_out.append(f"<h2>Ranked Table — All {len(ideas)} Ideas</h2>")
html_out.append("<table><tr><th>Rank</th><th>Idea</th><th>Cat</th><th>People</th><th>Final</th><th>Res</th><th>Flags</th></tr>")
for rank,(final,idea,res,ti,researches) in enumerate(rows,1):
    pstr=fmt_people(idea["people_affected_est"])
    outside='<span class="badge outside">outside</span>' if idea["flags"]["outside_the_box"] else ''
    title=html.escape(idea["title"][:60])
    html_out.append(f"<tr><td>{rank}</td><td>{title}</td><td>{idea['category']}</td><td>{pstr}</td><td><strong>{final:.1f}</strong></td><td>{res}</td><td>{outside}</td></tr>")
html_out.append("</table>")
html_out.append(f"<h2>Detailed Cards — All {len(ideas)} Ideas</h2>")
for rank,(final,idea,res,ti,researches) in enumerate(rows,1):
    outside_tag=" — <span class='badge outside'>OUTSIDE THE BOX</span>" if idea["flags"]["outside_the_box"] else ""
    html_out.append(f"<div class='card'><h3>#{rank} {html.escape(idea['title'])}{outside_tag}</h3>")
    html_out.append(f"<div class='meta'>ID: <code>{idea['id']}</code> • Category: <b>{idea['category']}</b> • People: <b>{fmt_people(idea['people_affected_est'])}</b> • Final <b>{final:.1f}</b> • Res: {res}</div>")
    html_out.append(f"<p>{html.escape(idea['body'])}</p>")
    if researches:
        html_out.append(f"<p><strong>Research ({len(researches)} parallel):</strong></p><ul>")
        for r in sorted(researches, key=lambda x: x.get('created_at',''), reverse=True)[:1]:
            md=r.get("result",{}).get("markdown","")[:400].replace("\n"," ")
            html_out.append(f"<li><code>{r['id'][:40]}...</code> model:{r.get('model',{}).get('name','?')}<br><em>{html.escape(md)}...</em></li>")
        html_out.append("</ul>")
    html_out.append("</div>")
from collections import Counter
cnt=Counter(t.get("model",{}).get("name","unknown") for t in board["tasks"] if "model" in t)
html_out.append("<h2>Stats</h2><ul>")
html_out.append(f"<li>Total IDEA: {len(ideas)} • RESEARCH: {len([t for t in board['tasks'] if t['type']=='RESEARCH'])} • Models: {', '.join(f'{m}:{c}' for m,c in cnt.most_common()[:5])}</li>")
html_out.append(f"<li>Generated: {gen_time}</li>")
html_out.append("</ul>")
html_out.append(f"""<h2>Agent Prompts</h2><ul>
<li><a href="{base_url}/prompt_research_only.html">SAFE</a> / <a href="{github_raw}/prompt_research_only.md">raw</a></li>
<li><a href="{base_url}/prompt_research_safe_push.html">SAFE PUSH</a> / <a href="{github_raw}/prompt_research_safe_push.md">raw</a></li>
<li><a href="{base_url}/prompt_research_plus.html">PLUS</a></li>
</ul>""")
html_out.append("</body></html>")
out_str="\n".join(html_out)
import pathlib as pl
pl.Path("report.html").write_text(out_str)
pl.Path(f"report_{date_str}.html").write_text(out_str)
# Full research version (with complete markdown)
# For scheduled, just generate snapshot, full is too heavy for cron
print(f"generated {len(out_str)} chars for {date_str}")
PY
# Generate PDF
weasyprint report.html report.pdf 2>&1 | tail -3
weasyprint report_${DATE}.html report_${DATE}.pdf 2>&1 | tail -3 || weasyprint report.html report_${DATE}.pdf 2>&1 | tail -3
ls -lh report*.pdf | tail -5
# Git commit + push if changed
cd /home/mort/ai/ideas
if ! git diff --quiet report.html report.pdf 2>&1; then
  git add report.html report.pdf report_${DATE}.html report_${DATE}.pdf 2>&1 | head -5
  git commit -m "scheduled report $DATE $(date -Iseconds)" 2>&1 | head -5
  git push https://$GITPAT@github.com/prometheananthropo/ForHumanity.git main 2>&1 | tail -10
  echo "pushed scheduled report $DATE"
else
  echo "no changes, not pushing"
fi
