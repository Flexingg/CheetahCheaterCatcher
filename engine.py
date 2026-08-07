import subprocess
import os
import glob

# Pull the camera URL from the docker-compose environment variable
CAMERA_URL = os.environ.get("CAMERA_URL", "http://192.168.1.100:8080/video")
BUFFER_DIR = "/app/buffer"

def start_hls_buffer():
    os.makedirs(BUFFER_DIR, exist_ok=True)
    
    # Clean up old HLS segments on startup
    for f in glob.glob(f"{BUFFER_DIR}/*"):
        try:
            os.remove(f)
        except OSError:
            pass

    print(f"Connecting to camera at {CAMERA_URL}...")
    print("Starting 5-Minute DVR window...")
    
    # Creates a rolling 5-minute playlist (150 segments of 2 seconds each)
    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-i", CAMERA_URL,
        "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
        "-f", "hls",
        "-hls_time", "2", 
        "-hls_list_size", "150", 
        "-hls_flags", "delete_segments",
        f"{BUFFER_DIR}/stream.m3u8"
    ]
    
    # We let stdout pass through so you can read FFmpeg errors in Portainer logs
    return subprocess.Popen(ffmpeg_cmd)