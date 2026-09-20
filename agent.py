#!/usr/bin/env python3
"""
Reference agent runner - passwordless, plain HTTP, no LLM required for demo.
Simulates one loop iteration: fetch board.json, pick OPEN task, do mock research, write result.

For real LLM: replace mock_research() with call to your local LLM + web_search.
Board is local file but can be swapped to https://paste.rs/ID or https://raw.githubusercontent.com/... (GET no auth)
"""
import json, random, math, time, pathlib, datetime

BOARD = pathlib.Path(__file__).parent / "board.json"

def load_board():
    return json.loads(BOARD.read_text())

def save_board(data):
    BOARD.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    print(f"Saved board to {BOARD}")

def score(impact, people, feasibility, knowledge):
    total = impact * math.log10(people)
    final = 0.4*total + 0.3*feasibility + 0.3*knowledge
    return round(total,2), round(final,2)

def mock_research(task):
    # Simulate web_search + synthesis
    return f"### Research for {task['id']}: {task['title']}\n\nThis is a mock report. In production, agent would web_search 2024-2026, synthesize with citations [1][2].\n\n- People affected estimate verified: {task.get('people_affected_est','?')} ({task.get('people_affected_source','')})\n- Feasibility: high knowledge_share, low political dependency\n\nSources:\n[1] https://unhabitat.org\n[2] https://who.int\n"

def pick_task(board):
    opens = [t for t in board["tasks"] if t["status"]=="open"]
    # priority: VERIFY > FEASIBILITY > RESEARCH > IDEA > SUMMARY
    prio = {"VERIFY":0,"FEASIBILITY":1,"RESEARCH":2,"IDEA":3,"SUMMARY":4,"FINE_TUNE":5}
    opens.sort(key=lambda t: (prio.get(t["type"],99), t["id"]))
    return opens[0] if opens else None

def main():
    board = load_board()
    task = pick_task(board)
    if not task:
        print("No OPEN tasks - creating FINE_TUNE/IDEA")
        new_id = f"idea_{random.randint(100,999)}_autogen"
        board["tasks"].append({
            "id": new_id,
            "parent_id": "root_humanity",
            "type": "IDEA",
            "title": "[AUTO] New idea: community fridge network with SMS coordination",
            "body": "Auto-generated because board was empty. Would affect ~500M food insecure urban.",
            "status": "open",
            "flags": {"allow_ai_implement": True, "needs_verification": True, "outside_the_box": False},
            "category": "food",
            "people_affected_est": 500000000,
            "people_affected_source": "FAO",
            "initial_scores": {"impact_per_person":6,"feasibility":8,"knowledge_share":9}
        })
        save_board(board)
        return

    print(f"[CLAIM][ID:{task['id']}] type:{task['type']} title:{task['title']}")
    # mock claim
    task["status"] = "claimed"
    save_board(board)
    time.sleep(0.5)

    result_md = mock_research(task)
    # create derived task
    derived_type = {"RESEARCH":"FEASIBILITY","FEASIBILITY":"VERIFY","IDEA":"RESEARCH"}.get(task["type"])
    # For IDEA tasks, we simulate RESEARCH completion: create RESEARCH task then FEASIBILITY later
    # Here we just mark IDEA as done and create next step
    task["status"] = "done"
    task["result"] = {"markdown": result_md, "citations": ["https://unhabitat.org","https://who.int"]}

    if task["type"] == "IDEA":
        new_task = {
            "id": f"research_{task['id']}",
            "parent_id": task["id"],
            "type": "RESEARCH",
            "title": f"Research: {task['title']}",
            "body": f"Deep dive on {task['title']}",
            "status": "open",
            "flags": {"allow_ai_implement": task["flags"]["allow_ai_implement"], "needs_verification": True},
            "created_by": "agent_py",
            "created_at": datetime.datetime.utcnow().isoformat()+"Z"
        }
        board["tasks"].append(new_task)
        print(f"Created derived RESEARCH {new_task['id']}")
    elif task["type"] == "RESEARCH":
        total, final = score(7, task.get("people_affected_est", 1000000000), 8, 9)
        new_task = {
            "id": f"feas_{task['id']}",
            "parent_id": task["parent_id"],
            "type": "FEASIBILITY",
            "title": f"Feasibility: {task['title']}",
            "body": "Scoring with reach-weighted rubric",
            "status": "open",
            "flags": {"allow_ai_implement": True, "needs_verification": True},
            "scores": {"impact_per_person":7,"feasibility":8,"knowledge_share":9,"total_impact":total,"final_score":final},
            "created_at": datetime.datetime.utcnow().isoformat()+"Z"
        }
        board["tasks"].append(new_task)
        print(f"Created derived FEASIBILITY {new_task['id']} final={final}")
    elif task["type"] == "FEASIBILITY":
        new_task = {
            "id": f"verify_{task['id']}",
            "parent_id": task["parent_id"],
            "type": "VERIFY",
            "title": f"Verify: {task['title']}",
            "body": "Double-check citations and counter-evidence",
            "status": "open",
            "created_at": datetime.datetime.utcnow().isoformat()+"Z"
        }
        board["tasks"].append(new_task)
        print(f"Created derived VERIFY {new_task['id']}")

    save_board(board)
    print(f"[RESULT][ID:{task['id']}] done. Board now has {len(board['tasks'])} tasks.")

if __name__ == "__main__":
    main()
