from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import sqlite3
import engine
import os
import base64
import threading
import time
import asyncio

app = FastAPI()
DB_PATH = "/app/buffer/games.db"

# Serializes MP4 exports so only one ffmpeg render runs at a time
export_lock = threading.Lock()

# --- DATABASE INIT & MIGRATION ---
def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, name TEXT, date TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    c.execute('''CREATE TABLE IF NOT EXISTS players (id INTEGER PRIMARY KEY, game_id INTEGER, name TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS scores (id INTEGER PRIMARY KEY, player_id INTEGER, round INTEGER, score INTEGER)''')
    
    # Safe migration: add win_condition if it doesn't exist
    try:
        c.execute("ALTER TABLE games ADD COLUMN win_condition TEXT DEFAULT 'lowest'")
    except sqlite3.OperationalError:
        pass # Column already exists
        
    conn.commit()
    conn.close()

@app.on_event("startup")
async def startup_event():
    engine.start_live(asyncio.get_running_loop())
    init_db()

app.mount("/buffer", StaticFiles(directory="/app/buffer"), name="buffer")

@app.websocket("/ws/live")
async def ws_live(websocket: WebSocket):
    """Low-latency live view: the server pushes each camera JPEG frame as a
    binary WebSocket message; the browser blits it straight to a <canvas>.
    This replaces the old HLS live path that caused 10-20s of latency."""
    await websocket.accept()
    q = asyncio.Queue(maxsize=4)
    engine.add_client(q)
    try:
        while True:
            frame = await q.get()
            await websocket.send_bytes(frame)
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        engine.remove_client(q)

@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    with open("index.html", "r") as f:
        return HTMLResponse(content=f.read())

# --- API MODELS ---
class NewGameReq(BaseModel):
    name: str
    win_condition: str
    players: list[str]

class ScoreUpdateReq(BaseModel):
    player_id: int
    round: int
    score: int

# --- API ENDPOINTS ---
@app.post("/api/games/new")
def create_game(req: NewGameReq):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT INTO games (name, win_condition) VALUES (?, ?)", (req.name, req.win_condition))
    game_id = c.lastrowid
    for player in req.players:
        if player.strip():
            c.execute("INSERT INTO players (game_id, name) VALUES (?, ?)", (game_id, player.strip()))
    conn.commit()
    conn.close()
    return {"game_id": game_id}

@app.get("/api/games")
def list_games():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    # Fetch chronologically to correctly number duplicates
    games = [dict(row) for row in c.execute("SELECT * FROM games ORDER BY date ASC, id ASC").fetchall()]
    
    date_name_counts = {}
    processed_games = []
    
    for g in games:
        date = g['date'].split(' ')[0]
        key = f"{date}_{g['name']}"
        date_name_counts[key] = date_name_counts.get(key, 0) + 1
        
        g['display_name'] = f"{g['name']} {date_name_counts[key]}" if date_name_counts[key] > 1 else g['name']
        g['players'] = [r['name'] for r in c.execute("SELECT name FROM players WHERE game_id=?", (g['id'],)).fetchall()]
        
        # Insert at front so the final list is newest-first
        processed_games.insert(0, g)

    conn.close()
    return {"games": processed_games}

@app.get("/api/games/{game_id}")
def get_game(game_id: int):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    game = dict(c.execute("SELECT * FROM games WHERE id = ?", (game_id,)).fetchone() or {})
    players = [dict(row) for row in c.execute("SELECT * FROM players WHERE game_id = ?", (game_id,)).fetchall()]
    scores = [dict(row) for row in c.execute(
        "SELECT s.* FROM scores s JOIN players p ON s.player_id = p.id WHERE p.game_id = ?", (game_id,)
    ).fetchall()]
    conn.close()
    return {"game": game, "players": players, "scores": scores}

@app.post("/api/games/score")
def update_score(req: ScoreUpdateReq):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT id FROM scores WHERE player_id = ? AND round = ?", (req.player_id, req.round))
    existing = c.fetchone()
    if existing:
        c.execute("UPDATE scores SET score = ? WHERE id = ?", (req.score, existing[0]))
    else:
        c.execute("INSERT INTO scores (player_id, round, score) VALUES (?, ?, ?)", (req.player_id, req.round, req.score))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.delete("/api/games/{game_id}")
def delete_game(game_id: int):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("DELETE FROM scores WHERE player_id IN (SELECT id FROM players WHERE game_id = ?)", (game_id,))
    c.execute("DELETE FROM players WHERE game_id = ?", (game_id,))
    c.execute("DELETE FROM games WHERE id = ?", (game_id,))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.delete("/api/games/{game_id}/round/{round_num}")
def delete_round(game_id: int, round_num: int):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("DELETE FROM scores WHERE round = ? AND player_id IN (SELECT id FROM players WHERE game_id = ?)", (round_num, game_id))
    # Shift all subsequent rounds down by 1
    c.execute("UPDATE scores SET round = round - 1 WHERE round > ? AND player_id IN (SELECT id FROM players WHERE game_id = ?)", (round_num, game_id))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/api/stats")
def get_stats():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    most_games = c.execute("SELECT name, COUNT(DISTINCT game_id) as count FROM players GROUP BY name ORDER BY count DESC LIMIT 5").fetchall()
    
    highest_round = c.execute('''SELECT p.name, s.score, g.name as game_name 
                                 FROM scores s JOIN players p ON s.player_id = p.id 
                                 JOIN games g ON p.game_id = g.id ORDER BY s.score DESC LIMIT 1''').fetchone()
                                 
    lowest_round = c.execute('''SELECT p.name, s.score, g.name as game_name 
                                FROM scores s JOIN players p ON s.player_id = p.id 
                                JOIN games g ON p.game_id = g.id ORDER BY s.score ASC LIMIT 1''').fetchone()

    most_zeros = c.execute('''SELECT p.name, COUNT(*) as count FROM scores s 
                              JOIN players p ON s.player_id = p.id WHERE s.score = 0 
                              GROUP BY p.name ORDER BY count DESC LIMIT 1''').fetchone()

    best_avg = c.execute('''SELECT p.name, ROUND(AVG(s.score), 1) as avg_score 
                            FROM scores s JOIN players p ON s.player_id = p.id 
                            GROUP BY p.name ORDER BY avg_score ASC LIMIT 5''').fetchall()

    conn.close()
    return {
        "most_games": [dict(r) for r in most_games],
        "highest_round": dict(highest_round) if highest_round else None,
        "lowest_round": dict(lowest_round) if lowest_round else None,
        "most_zeros": dict(most_zeros) if most_zeros else None,
        "best_avg": [dict(r) for r in best_avg]
    }

# --- REPLAY / DVR EXPORT API ---

class ReplayExportReq(BaseModel):
    start: float
    end: float
    speed: float = 1.0
    markup: str | None = None  # data URL or raw base64 of the telestration PNG
    name: str | None = None

@app.get("/api/replay/timeline")
def replay_timeline():
    """Return the available buffer and segment list to drive the scrubber."""
    return engine.list_segments()

@app.post("/api/replay/export")
def replay_export(req: ReplayExportReq):
    """Render the selected clip as a slow-mo, marked-up MP4."""
    if req.speed <= 0:
        raise HTTPException(status_code=400, detail="Speed must be positive")

    markup_path = None
    if req.markup:
        # Accept either a data URL (data:image/png;base64,...) or raw base64
        b64 = req.markup.split(",", 1)[-1]
        markup_path = os.path.join(engine.EXPORT_DIR, "markup.png")
        with open(markup_path, "wb") as f:
            f.write(base64.b64decode(b64))

    filename = req.name or f"clip_{int(time.time())}.mp4"
    if not filename.endswith(".mp4"):
        filename += ".mp4"

    with export_lock:
        try:
            out_path = engine.export_clip(
                req.start, req.end, req.speed, markup_path, filename
            )
        except RuntimeError as e:
            raise HTTPException(status_code=400, detail=str(e))

    return {
        "url": f"/buffer/exports/{os.path.basename(out_path)}",
        "filename": os.path.basename(out_path),
    }

class ReplayCaptureReq(BaseModel):
    window: float = 60.0
    name: str | None = None

@app.post("/api/replay/capture")
def replay_capture(req: ReplayCaptureReq):
    """Save the most recent `window` seconds of the live buffer as a playable
    MP4 for interactive instant replay (seekable from ~1 FPS to 5x)."""
    if not (1.0 <= req.window <= 600.0):
        raise HTTPException(status_code=400, detail="Window must be 1-600 seconds")

    with export_lock:
        try:
            result = engine.capture_clip(req.window, req.name)
        except RuntimeError as e:
            raise HTTPException(status_code=400, detail=str(e))

    return {
        "url": f"/buffer/exports/{result['url_name']}",
        "filename": result["url_name"],
        "start": result["start"],
        "end": result["end"],
        "duration": result["duration"],
    }