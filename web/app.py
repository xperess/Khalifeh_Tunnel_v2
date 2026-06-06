from flask import Flask, jsonify, render_template, abort
import subprocess

app = Flask(__name__)
ALLOWED_SERVICES = ["khalifeh-rathole-server", "khalifeh-rathole-client", "frps", "frpc", "hysteria2", "hysteria2-client"]

def get_status(name):
    try:
        output = subprocess.check_output(["systemctl", "is-active", name], stderr=subprocess.STDOUT).decode().strip()
        return output
    except Exception:
        return "inactive"

@app.route("/")
def index(): 
    return render_template("index.html")

@app.route("/api/status")
def status():
    return jsonify({s: get_status(s) for s in ALLOWED_SERVICES})

@app.route("/api/<action>/<name>")
def manage_service(action, name):
    if name not in ALLOWED_SERVICES or action not in ["start", "stop", "restart"]:
        abort(400, "Operation restricted due to security policy.")
    try:
        subprocess.run(["systemctl", action, name], check=True)
        return jsonify({"status": f"{action}ed", "service": name})
    except subprocess.CalledProcessError:
        return jsonify({"status": "failed", "service": name}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
