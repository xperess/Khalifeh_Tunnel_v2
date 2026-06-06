from flask import Flask, jsonify, render_template, abort
import subprocess

app = Flask(__name__)

ALLOWED_SERVICES = [
    "khalifeh-rathole-server",
    "khalifeh-rathole-client",
    "frps",
    "frpc",
    "hysteria2",
    "hysteria2-client",
    "khalifeh-failover"
]

def get_status(name):
    try:
        res = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
        return res.stdout.strip()
    except:
        return "inactive"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/status")
def status():
    return jsonify({s: get_status(s) for s in ALLOWED_SERVICES})

@app.route("/api/<action>/<name>")
def manage(action, name):
    if name not in ALLOWED_SERVICES or action not in ["start", "stop", "restart"]:
        abort(400, "Unauthorized action or service target.")
    try:
        subprocess.run(["systemctl", action, name], check=True)
        return jsonify({"status": "success", "service": name, "action": action})
    except subprocess.CalledProcessError:
        return jsonify({"status": "failed"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)