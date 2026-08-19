import subprocess
import os
import glob
import time
import re
import threading
import urllib.request
from urllib.error import URLError, HTTPError
from datetime import datetime, timedelta
from collections import deque

# Live-view "lag budget": we push MJPEG frames straight to browsers over a
# WebSocket and render them on a <canvas>. The old HLS live path (2s segments
# + hls.js sitting ~6s behind the live edge + an ffmpeg MJPEG->H.264 re-encode)
# is what produced the 10-20s delay. ffmpeg/HLS is now used ONLY to build the
# DVR/replay buffer on disk -- replay can be a few seconds late, live cannot.
#
# Pull the camera URL from the docker-compose environment variable
CAMERA_URL = os.environ.get("CAMERA_URL", "http://192.168.1.100:8080/video")
BUFFER_DIR = "/app/buffer"
EXPORT_DIR = os.path.join(BUFFER_DIR, "exports")
PLAYLIST_PATH = os.path.join(BUFFER_DIR, "stream.m3u8")

# --- Live WebSocket plumbing -------------------------------------------------
_clients = set()     # asyncio.Queue instances, one per connected browser
_root_loop = None    # uvicorn's asyncio loop, captured at startup
_ffmpeg = None       # FFmpegWriter tee'ing frames into the DVR buffer


def start_live(root_loop):
    """Single MJPEG consumer: tees every camera frame to (a) any connected
    live-view browsers via WebSocket and (b) ffmpeg -> HLS DVR buffer."""
    global _root_loop, _ffmpeg
    _root_loop = root_loop

    os.makedirs(BUFFER_DIR, exist_ok=True)
    os.makedirs(EXPORT_DIR, exist_ok=True)
    # Clean stale HLS segments on startup (keep the exports subfolder)
    for f in glob.glob(f"{BUFFER_DIR}/*"):
        if os.path.isdir(f):
            continue
        try:
            os.remove(f)
        except OSError:
            pass

    print(f"Connecting to camera at {CAMERA_URL}...")
    print("Starting 5-Minute DVR window (live view is WebSocket MJPEG)...")
    _ffmpeg = FFmpegWriter()
    threading.Thread(target=_reader, daemon=True).start()


def add_client(q):
    _clients.add(q)


def remove_client(q):
    _clients.discard(q)


def _push_all(frame):
    for q in list(_clients):
        try:
            if q.full():          # drop the oldest buffered frame so the
                q.get_nowait()    # browser stays as close to live as possible
            q.put_nowait(frame)
        except Exception:
            pass


# --- Camera frame reader -----------------------------------------------------
def _reader():
    global _ffmpeg
    while True:
        try:
            _read_camera_stream()
        except (URLError, HTTPError, TimeoutError, OSError) as exc:
            print(f"[live] camera read error ({exc}); retrying...")
        except Exception as exc:  # keep the reader thread alive no matter what
            print(f"[live] unexpected camera error: {exc}")
        time.sleep(1.5)


def _read_camera_stream():
    req = urllib.request.Request(CAMERA_URL, headers={
        "Connection": "keep-alive",
        "Accept": "*/*",
    })
    with urllib.request.urlopen(req, timeout=15) as resp:
        ct = resp.headers.get("Content-Type", "")
        boundary = _extract_boundary(ct)
        print(f"[live] connected ({ct})")
        buf = b""
        while True:
            chunk = resp.read(16384)
            if not chunk:
                break
            buf += chunk
            frames, buf = _extract_frames(buf, boundary)
            for f in frames:
                _ffmpeg.write(f)
                if _root_loop is not None:
                    _root_loop.call_soon_threadsafe(_push_all, f)


def _extract_boundary(content_type):
    m = re.search(r"boundary=([^;\r\n]+)", content_type or "", re.IGNORECASE)
    if not m:
        return b""
    # Some cameras (e.g. IP Webcam) return the token already carrying the two
    # leading hyphens; strip them so the `\r\n--` + boundary delimiter is exact.
    tok = m.group(1).strip().strip('"').lstrip("-")
    return tok.encode("ascii", "ignore")


def _extract_frames(buf, boundary):
    if boundary:
        return _extract_multipart_frames(buf, boundary)
    return _extract_marker_frames(buf)


def _extract_multipart_frames(buf, boundary):
    frames = []
    delim = b"\r\n--" + boundary
    prev = buf.find(delim, 0)
    while prev != -1:
        cur = buf.find(delim, prev + len(delim))
        if cur == -1:
            break
        part = buf[prev + len(delim):cur]
        sep = part.find(b"\r\n\r\n")
        if sep != -1:
            img = part[sep + 4:]
            if img.endswith(b"\r\n"):
                img = img[:-2]
            elif img.endswith(b"\n"):
                img = img[:-1]
            if img.startswith(b"\xff\xd8") and img.endswith(b"\xff\xd9"):
                frames.append(img)
        prev = cur
    leftover = buf[prev:] if prev != -1 else buf
    return frames, leftover


def _extract_marker_frames(buf):
    """Fallback for streams that don't advertise a multipart boundary: split on
    JPEG SOI (FFD8) / EOI (FFD9) markers."""
    frames = []
    i = 0
    while True:
        s = buf.find(b"\xff\xd8", i)
        if s == -1:
            break
        e = buf.find(b"\xff\xd9", s)
        if e == -1:
            break
        frames.append(buf[s:e + 2])
        i = e + 2
    return frames, buf[i:]


# --- DVR / replay: ffmpeg fed from the same frames (tee) ---------------------
class FFmpegWriter:
    """Bounded queue + worker thread writing JPEG frames to ffmpeg's stdin to
    produce the rolling HLS DVR buffer. Decoupled from the live path so a slow
    encode can never delay live viewers; if the queue backs up we drop (skip)
    frames rather than fall behind."""

    _FFMPEG_CMD = [
        "ffmpeg", "-y", "-loglevel", "warning",
        "-framerate", "30", "-f", "mjpeg", "-i", "pipe:0",
        "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
        "-f", "hls",
        "-hls_time", "2",
        "-hls_list_size", "150",
        "-hls_flags", "delete_segments+program_date_time",
        f"{BUFFER_DIR}/stream.m3u8",
    ]

    def __init__(self, maxlen=1500):
        self.q = deque(maxlen=maxlen)
        self.proc = None
        self._start()
        threading.Thread(target=self._run, daemon=True).start()

    def _start(self):
        if self.proc is not None:
            try:
                self.proc.stdin.close()
            except Exception:
                pass
        self.proc = subprocess.Popen(
            self._FFMPEG_CMD, stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        print(f"[live] ffmpeg DVR started (pid {self.proc.pid})")

    def write(self, frame):
        if len(self.q) >= self.q.maxlen:
            try:
                self.q.popleft()
            except (IndexError, AttributeError):
                pass
        self.q.append(frame)

    def _run(self):
        while True:
            if self.proc is None or self.proc.poll() is not None:
                try:
                    self._start()
                except Exception:
                    time.sleep(1.0)
                    continue
            try:
                frame = self.q.popleft()
            except (IndexError, AttributeError):
                frame = None
            if frame is None:
                time.sleep(0.001)
                continue
            try:
                self.proc.stdin.write(frame)
                self.proc.stdin.flush()
            except Exception:
                try:
                    self.proc.stdin.close()
                except Exception:
                    pass
                self.proc = None
                time.sleep(0.1)


# ---------------------------------------------------------------------------
# Replay / DVR helpers
# ---------------------------------------------------------------------------

def list_segments():
    """Parse stream.m3u8 into an ordered list of segment metadata.

    Times are expressed as *composition time* in seconds, counting from the
    first segment currently present in the playlist (0-based). Both the client
    scrubber and the server export path use these same numbers so a selected
    time range maps consistently to the on-disk .ts segments.
    """
    if not os.path.exists(PLAYLIST_PATH):
        return {"available": False, "segments": [], "live_edge": 0.0}

    segments = []
    program_time = None
    start_sec = 0.0
    dur = 0.0
    media_sequence = 0

    with open(PLAYLIST_PATH, "r") as f:
        lines = f.read().splitlines()

    for line in lines:
        line = line.strip()
        if line.startswith("#EXT-X-MEDIA-SEQUENCE:"):
            media_sequence = int(line.split(":", 1)[1])
        elif line.startswith("#EXT-X-PROGRAM-DATE-TIME:"):
            ts = line.split(":", 1)[1].strip().replace("Z", "+00:00")
            try:
                program_time = datetime.fromisoformat(ts)
            except ValueError:
                program_time = None
        elif line.startswith("#EXTINF:"):
            dur = float(line.split(":", 1)[1].rstrip(","))
        elif line.startswith("#") or not line:
            continue
        else:
            # A segment filename line
            segments.append({
                "file": line,
                "start": round(start_sec, 3),
                "duration": round(dur, 3),
                "wall_time": program_time.isoformat() if program_time else None,
            })
            start_sec += dur
            if program_time:
                program_time += timedelta(seconds=dur)

    return {
        "available": True,
        "media_sequence": media_sequence,
        "segments": segments,
        "live_edge": round(start_sec, 3),
    }


def export_clip(start_sec, end_sec, speed, markup_png_path=None, filename=None):
    """Render [start_sec, end_sec] as a slow-mo, markup-overlaid MP4.

    Builds an ffmpeg concat demuxer input from the .ts segments overlapping the
    range, trims to the exact selection, applies slow-motion via setpts, and
    (optionally) overlays a transparent telestration PNG. Returns the output
    file path.
    """
    data = list_segments()
    if not data["available"] or not data["segments"]:
        raise RuntimeError("No replay buffer available yet")

    segments = data["segments"]
    live_edge = data["live_edge"]
    end_sec = min(end_sec, live_edge)
    if end_sec <= start_sec:
        raise RuntimeError("Invalid time range: end must be after start")

    # Segments that overlap the selection
    chosen = [
        s for s in segments
        if s["start"] < end_sec and (s["start"] + s["duration"]) > start_sec
    ]
    if not chosen:
        raise RuntimeError("Selected range falls outside the available buffer")

    first_start = chosen[0]["start"]
    rel_start = max(0.0, start_sec - first_start)
    rel_dur = end_sec - start_sec

    # Concat demuxer list (absolute paths, safe mode on)
    concat_list = os.path.join(EXPORT_DIR, "concat.txt")
    with open(concat_list, "w") as f:
        for s in chosen:
            f.write(f"file '{os.path.join(BUFFER_DIR, s['file'])}'\n")

    if filename is None:
        filename = f"clip_{int(time.time())}.mp4"
    out_path = os.path.join(EXPORT_DIR, filename)

    args = ["ffmpeg", "-y",
            "-f", "concat", "-safe", "0", "-i", concat_list]

    has_markup = bool(markup_png_path) and os.path.exists(markup_png_path)
    if has_markup:
        args += ["-i", markup_png_path]

    # Trim -> normalize -> slow-mo -> (scale markup to video -> overlay)
    # Note: scale2ref's first input is scaled to match the second (reference).
    # We want the markup [mark] scaled up to the video [v], so markup comes first.
    vf = (
        f"[0:v]trim=start={rel_start:.3f}:duration={rel_dur:.3f},"
        f"setpts=PTS-STARTPTS,setpts=PTS/{speed:.4f},"
        f"scale=trunc(iw/2)*2:trunc(ih/2)*2[v]"
    )
    out_label = "[v]"
    if has_markup:
        vf += (
            ";[1:v]format=rgba[mark];"
            "[mark][v]scale2ref=w=iw:h=ih[mk][vref];"
            "[vref][mk]overlay=0:0:format=auto[vout]"
        )
        out_label = "[vout]"

    args += [
        "-filter_complex", vf,
        "-map", out_label,
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        out_path,
    ]

    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0 or not os.path.exists(out_path):
        raise RuntimeError(f"ffmpeg export failed: {proc.stderr[-2000:]}")

    return out_path


# --- Instant replay capture --------------------------------------------------
REPLAY_PREFIX = "replay_"
# Keep only this many saved instant-replay clips so disk doesn't grow forever.
MAX_REPLAYS_KEPT = 10


def _prune_replays():
    clips = sorted(
        glob.glob(os.path.join(EXPORT_DIR, REPLAY_PREFIX + "*.mp4")),
        key=os.path.getmtime,
    )
    for old in clips[:-MAX_REPLAYS_KEPT]:
        try:
            os.remove(old)
        except OSError:
            pass


def capture_clip(window_sec=60.0, filename=None):
    """Save the most recent `window_sec` of the live DVR buffer as a standalone
    MP4 for interactive instant-replay.

    This is deliberately a *fast* path: we concatenate the .ts segments that
    overlap the requested window and stream-copy (`-c copy`) them into a single
    'faststart' MP4. No re-encode, so the save is near-instant; the HLS segment
    boundaries already carry keyframes, so the browser can seek and play the
    saved file at any speed (1 FPS .. 5x) without a fresh render.

    Returns dict with the on-disk path plus the exact captured window.
    """
    data = list_segments()
    if not data["available"] or not data["segments"]:
        raise RuntimeError("No replay buffer available yet")

    segments = data["segments"]
    live_edge = data["live_edge"]
    end_sec = live_edge
    start_sec = max(0.0, live_edge - window_sec)

    # Full segments that cover the window (keep leading/trailing segment whole so
    # the stream-copy trim stays keyframe aligned; ~2s of slack is fine for a
    # replay).
    chosen = [
        s for s in segments
        if s["start"] < end_sec and (s["start"] + s["duration"]) > start_sec
    ]
    if not chosen:
        raise RuntimeError("Selected range falls outside the available buffer")

    capture_start = chosen[0]["start"]
    duration = round(sum(s["duration"] for s in chosen), 3)

    # Concat demuxer list (absolute paths, safe mode on).
    concat_list = os.path.join(EXPORT_DIR, "replay_concat.txt")
    with open(concat_list, "w") as f:
        for s in chosen:
            f.write(f"file '{os.path.join(BUFFER_DIR, s['file'])}'\n")

    if filename is None:
        filename = f"{REPLAY_PREFIX}{int(time.time())}.mp4"
    if not filename.endswith(".mp4"):
        filename += ".mp4"
    out_path = os.path.join(EXPORT_DIR, filename)

    args = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "concat", "-safe", "0", "-i", concat_list,
        "-c", "copy",
        "-movflags", "+faststart",
        out_path,
    ]

    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0 or not os.path.exists(out_path):
        raise RuntimeError(f"replay capture failed: {proc.stderr[-2000:]}")

    _prune_replays()
    return {
        "path": out_path,
        "url_name": os.path.basename(out_path),
        "start": round(capture_start, 3),
        "end": round(end_sec, 3),
        "duration": duration,
    }