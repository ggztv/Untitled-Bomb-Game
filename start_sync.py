import os
import json
import time
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import threading

# Configuration
WATCH_DIR = r"F:\python\UBG\src"
PORT = 8080
GIT_CHECK_INTERVAL = 10  # Check GitHub every 10 seconds
FILE_CHECK_INTERVAL = 2  # Check files every 2 seconds

# Store file contents
file_cache = {}

def scan_scripts():
    """Scan all .lua and .luau files and return their contents"""
    scripts = {}
    src_path = Path(WATCH_DIR)
    
    if not src_path.exists():
        return scripts
    
    # Look for both .lua and .luau files
    for lua_file in list(src_path.rglob("*.lua")) + list(src_path.rglob("*.luau")):
        # Get relative path from src folder
        rel_path = lua_file.relative_to(src_path)
        
        # Convert path to forward slashes and keep original extension
        roblox_path = str(rel_path).replace("\\", "/")
        
        try:
            with open(lua_file, 'r', encoding='utf-8') as f:
                content = f.read()
                scripts[roblox_path] = content
        except Exception as e:
            print(f"Error reading {lua_file}: {e}")
    
    return scripts

def watch_files():
    """Watch for file changes"""
    global file_cache
    
    while True:
        new_cache = scan_scripts()
        
        # Check for changes
        if new_cache != file_cache:
            changed = []
            for path, content in new_cache.items():
                if path not in file_cache or file_cache[path] != content:
                    changed.append(path)
            
            if changed:
                print(f"📝 File changes detected: {', '.join(changed)}")
            
            file_cache = new_cache
        
        time.sleep(FILE_CHECK_INTERVAL)

def auto_pull():
    """Auto-pull from GitHub"""
    print("🔄 Auto-pull watcher started")
    
    while True:
        try:
            # Fetch updates from GitHub
            subprocess.run(["git", "fetch"], cwd=r"F:\python\UBG", capture_output=True)
            
            # Check if there are changes
            result = subprocess.run(
                ["git", "status", "-uno"],
                cwd=r"F:\python\UBG",
                capture_output=True,
                text=True
            )
            
            if "Your branch is behind" in result.stdout:
                print("📥 Pulling changes from GitHub...")
                pull_result = subprocess.run(
                    ["git", "pull"],
                    cwd=r"F:\python\UBG",
                    capture_output=True,
                    text=True
                )
                print(pull_result.stdout)
                print("✅ Updated from GitHub!")
            
        except Exception as e:
            print(f"Git error: {e}")
        
        time.sleep(GIT_CHECK_INTERVAL)

class SyncHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/scripts":
            # Return all scripts as JSON
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            response = json.dumps(file_cache)
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def start_server():
    """Start HTTP server"""
    server = HTTPServer(("localhost", PORT), SyncHandler)
    print(f"🌐 HTTP server running on http://localhost:{PORT}")
    server.serve_forever()

if __name__ == "__main__":
    print("=" * 50)
    print("GitHub Auto-Sync System")
    print("=" * 50)
    print(f"📁 Watching files: {WATCH_DIR}")
    print(f"🔄 Auto-pull interval: {GIT_CHECK_INTERVAL}s")
    print(f"🌐 Server: http://localhost:{PORT}")
    print("Press Ctrl+C to stop\n")
    
    # Create src folder structure if it doesn't exist
    Path(WATCH_DIR).mkdir(parents=True, exist_ok=True)
    
    # Start file watcher in background
    file_watcher_thread = threading.Thread(target=watch_files, daemon=True)
    file_watcher_thread.start()
    
    # Start auto-pull in background
    auto_pull_thread = threading.Thread(target=auto_pull, daemon=True)
    auto_pull_thread.start()
    
    # Start server in main thread
    try:
        start_server()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")