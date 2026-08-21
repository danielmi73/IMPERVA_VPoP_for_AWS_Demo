#!/usr/bin/env python3
"""
OWASP Top 10 Web & API Security Demonstration Backend
Engineered for Imperva Cloud WAF (Imperva for AWS / vPoP) Demonstrations
"""

import os
import sys
import json
import time
import base64
import urllib.parse
from datetime import datetime
from flask import Flask, request, jsonify, render_template, Response

app = Flask(__name__, template_folder='templates', static_folder='static')

# Mock in-memory database for demo purposes
USERS_DB = {
    1001: {"id": 1001, "username": "alice", "email": "alice@corp.internal", "role": "user", "balance": 15420.50, "token": "usr_sec_991823"},
    1002: {"id": 1002, "username": "bob", "email": "bob@corp.internal", "role": "user", "balance": 3200.00, "token": "usr_sec_772113"},
    1003: {"id": 1003, "username": "admin", "email": "admin@thalesgroup.com", "role": "super_admin", "balance": 999999.99, "token": "adm_sec_001928"}
}

ORDERS_DB = [
    {"order_id": "ORD-9821", "customer_id": 1001, "item": "Cloud Security License", "amount": 4500.00, "card_last4": "4242", "ssn_masked": "***-**-8812"},
    {"order_id": "ORD-9822", "customer_id": 1002, "item": "WAF Protection Add-on", "amount": 1200.00, "card_last4": "1111", "ssn_masked": "***-**-4491"}
]

AUDIT_LOGS = []

def record_log(event_type, details, blocked_by_waf=False):
    log_entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "client_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "user_agent": request.headers.get("User-Agent", "Unknown"),
        "origin_domain_header": request.headers.get("x-impv-origin-domain", "Not Present"),
        "event_type": event_type,
        "details": details,
        "blocked": blocked_by_waf
    }
    AUDIT_LOGS.insert(0, log_entry)
    if len(AUDIT_LOGS) > 50:
        AUDIT_LOGS.pop()
    return log_entry

# ==============================================================================
# UI & Core Endpoints
# ==============================================================================

@app.route("/")
def home():
    headers_dict = dict(request.headers)
    return render_template("index.html", headers=headers_dict)

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "service": "Imperva Cloud WAF Demo App",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), 200

@app.route("/api/debug/headers")
def inspect_headers():
    return jsonify({
        "client_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "imperva_origin_header": request.headers.get("x-impv-origin-domain", None),
        "cloudfront_viewer_country": request.headers.get("CloudFront-Viewer-Country", None),
        "cloudfront_viewer_city": request.headers.get("CloudFront-Viewer-City", None),
        "all_headers": dict(request.headers),
        "method": request.method,
        "url": request.url
    })

@app.route("/api/debug/audit-logs")
def get_audit_logs():
    return jsonify(AUDIT_LOGS)

# ==============================================================================
# OWASP TOP 10 WEB APPLICATION VULNERABILITIES
# ==============================================================================

# A01: Broken Access Control & Path Traversal / LFI
@app.route("/api/vulnerabilities/lfi")
def vuln_lfi():
    filepath = request.args.get("file", "welcome.txt")
    record_log("Path Traversal / LFI", {"file_param": filepath})
    
    if ".." in filepath or "/etc/" in filepath or "win.ini" in filepath:
        # If reached backend (bypassed or direct):
        return jsonify({
            "vulnerability": "A01:2021 - Broken Access Control / Path Traversal (LFI)",
            "status": "VULNERABLE_BACKEND_EXECUTED",
            "message": f"Simulated local file read for: {filepath}",
            "file_content": f"root:x:0:0:root:/root:/bin/bash\ndaemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin\nbin:x:2:2:bin:/bin:/usr/sbin/nologin",
            "imperva_defense": "Imperva Cloud WAF inspects path tokens and blocks Directory Traversal & Illegal Resource Access signatures."
        })
    return jsonify({"file": filepath, "content": "Welcome to the secure customer portal."})

# A02: Cryptographic Failures / Sensitive Data Exposure
@app.route("/api/vulnerabilities/sensitive-data")
def vuln_sensitive_data():
    record_log("Sensitive Data Exposure", {"endpoint": "/sensitive-data"})
    return jsonify({
        "vulnerability": "A02:2021 - Cryptographic Failures & Sensitive Data Leakage",
        "orders": ORDERS_DB,
        "internal_api_keys": [
            "sk_live_99214981290381029381029381029381",
            "AKIAIOSFODNN7EXAMPLE"
        ],
        "imperva_defense": "Imperva Cloud WAF Data Masking & DLP prevents outbound leakages of credit card numbers, SSNs, and private API keys."
    })

# A03: Injection (SQL Injection)
@app.route("/api/vulnerabilities/sqli")
def vuln_sqli():
    query = request.args.get("query", "alice")
    record_log("SQL Injection (SQLi)", {"query": query})
    
    # If malicious SQL reaches backend:
    if any(keyword in query.upper() for keyword in ["'", "OR", "UNION", "SELECT", "--", "/*", "DROP", "1=1"]):
        return jsonify({
            "vulnerability": "A03:2021 - Injection (SQL Injection)",
            "status": "VULNERABLE_BACKEND_EXECUTED",
            "executed_query": f"SELECT * FROM users WHERE username = '{query}';",
            "extracted_records": list(USERS_DB.values()),
            "imperva_defense": "Imperva Cloud WAF SQL Injection engine analyzes syntax trees and parameters to block SQL injection in real-time."
        })
    
    filtered_users = [u for u in USERS_DB.values() if query.lower() in u["username"].lower()]
    return jsonify({"query": query, "results": filtered_users})

# A03: Injection (Remote Command Execution / RCE)
@app.route("/api/vulnerabilities/rce")
def vuln_rce():
    cmd = request.args.get("cmd", "hostname")
    record_log("Command Injection / RCE", {"cmd": cmd})
    
    if any(char in cmd for char in [";", "|", "&", "$", "`", ">", "<"]):
        return jsonify({
            "vulnerability": "A03:2021 - Injection (OS Command Injection / RCE)",
            "status": "VULNERABLE_BACKEND_EXECUTED",
            "command_executed": cmd,
            "stdout": f"uid=0(root) gid=0(root) groups=0(root)\nLinux imperva-demo-app 6.1.0 #1 SMP AWS x86_64",
            "imperva_defense": "Imperva Cloud WAF OS Command Injection shield intercepts shell metacharacters, piping, and command separators."
        })
    return jsonify({"command": cmd, "stdout": "demo-app-node-01.ec2.internal"})

# A03 / Cross-Site Scripting (XSS)
@app.route("/api/vulnerabilities/xss")
def vuln_xss():
    payload = request.args.get("payload", "hello")
    record_log("Cross-Site Scripting (XSS)", {"payload": payload})
    
    if any(tag in payload.lower() for tag in ["<script", "javascript:", "onerror=", "onload=", "<svg", "<img"]):
        html_response = f"""
        <html>
          <body>
            <h3>Reflected XSS Vulnerability Result</h3>
            <p>Unsanitized user reflection: {payload}</p>
            <hr>
            <p><strong>Imperva Defense:</strong> Imperva WAF Cross-Site Scripting rule analyzes DOM injections, HTML tags, and event handlers to block payload execution.</p>
          </body>
        </html>
        """
        return Response(html_response, mimetype="text/html")
    return jsonify({"message": f"Safe echo: {payload}"})

# A05: Security Misconfiguration (Environment File / Git Exposure)
@app.route("/.env")
@app.route("/.git/config")
@app.route("/api/vulnerabilities/debug-dump")
def vuln_misconfig():
    record_log("Security Misconfiguration Probe", {"path": request.path})
    return jsonify({
        "vulnerability": "A05:2021 - Security Misconfiguration",
        "status": "VULNERABLE_BACKEND_EXECUTED",
        "exposed_file": request.path,
        "content": "DB_PASSWORD=SecretP@ssw0rd2026!\nAWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        "imperva_defense": "Imperva Cloud WAF automatically detects and blocks vulnerability scanners hunting for hidden sensitive files and configuration backups."
    })

# A06: Vulnerable and Outdated Components (Log4Shell / Spring4Shell simulation)
@app.route("/api/vulnerabilities/log4shell")
def vuln_log4shell():
    jndi_header = request.headers.get("X-Api-Version", request.args.get("header_val", ""))
    record_log("Log4j / JNDI Injection Probe", {"header_val": jndi_header})
    
    if "${jndi:" in jndi_header.lower():
        return jsonify({
            "vulnerability": "A06:2021 - Vulnerable Components (Log4Shell / CVE-2021-44228)",
            "status": "VULNERABLE_BACKEND_EXECUTED",
            "jndi_lookup_attempted": jndi_header,
            "imperva_defense": "Imperva Zero-Day & Virtual Patching engine immediately shields against zero-day exploit patterns like JNDI LDAP Lookups before backend code is updated."
        })
    return jsonify({"status": "Header processed", "value": jndi_header})

# A10: Server-Side Request Forgery (SSRF)
@app.route("/api/vulnerabilities/ssrf")
def vuln_ssrf():
    target_url = request.args.get("url", "https://api.weather.com")
    record_log("Server-Side Request Forgery (SSRF)", {"url": target_url})
    
    if any(meta in target_url for meta in ["169.254.169.254", "localhost", "127.0.0.1", "metadata.google.internal"]):
        return jsonify({
            "vulnerability": "A10:2021 - Server-Side Request Forgery (SSRF)",
            "status": "VULNERABLE_BACKEND_EXECUTED",
            "targeted_internal_url": target_url,
            "simulated_metadata_response": {
                "ami-id": "ami-0c55b159cbfafe1f0",
                "iam-role": "ImpervaDemoAppRole",
                "security-credentials": {
                    "AccessKeyId": "ASIAIOSFODNN7EXAMPLE",
                    "SecretAccessKey": "v9XyzFakeSecretKeyForDemo1234567890",
                    "Token": "IQoJb3JpZ2luX2VjE...",
                    "Expiration": "2026-08-19T20:00:00Z"
                }
            },
            "imperva_defense": "Imperva SSRF Protection blocks attempts to force web applications to fetch internal cloud metadata or loopback network addresses."
        })
    return jsonify({"fetched_url": target_url, "data": "External weather response: Sunny 25°C"})

# ==============================================================================
# OWASP TOP 10 API SECURITY VULNERABILITIES
# ==============================================================================

# API1:2023 - Broken Object Level Authorization (BOLA / IDOR)
@app.route("/api/v1/accounts/<int:user_id>/statement")
def api_bola(user_id):
    record_log("API BOLA / IDOR", {"requested_user_id": user_id})
    if user_id in USERS_DB:
        return jsonify({
            "vulnerability": "API1:2023 - Broken Object Level Authorization (BOLA)",
            "status": "VULNERABLE_BACKEND_EXECUTED",
            "account_data": USERS_DB[user_id],
            "imperva_defense": "Imperva API Security correlates authentication tokens with request parameters to prevent horizontal privilege escalation (BOLA)."
        })
    return jsonify({"error": "User not found"}), 404

# API3:2023 - Broken Object Property Level Authorization (Mass Assignment)
@app.route("/api/v1/users/register", methods=["POST"])
def api_mass_assignment():
    data = request.get_json(force=True, silent=True) or {}
    record_log("API Mass Assignment", {"payload": data})
    
    assigned_role = data.get("role", "user")
    is_admin = assigned_role in ["admin", "super_admin"]
    
    return jsonify({
        "vulnerability": "API3:2023 - Broken Object Property Level Authorization (Mass Assignment)",
        "status": "VULNERABLE_BACKEND_EXECUTED" if is_admin else "USER_REGISTERED",
        "created_user": {
            "username": data.get("username", "guest"),
            "role": assigned_role,
            "privilege_level": "ROOT_ADMINISTRATOR" if is_admin else "STANDARD_USER"
        },
        "imperva_defense": "Imperva API Security enforces strict OpenAPI/Swagger schema validation, blocking unexpected JSON parameters and unauthorized role escalation."
    })

# API4:2023 - Unrestricted Resource Consumption (API Rate Abuse)
@app.route("/api/v1/sms/send-otp", methods=["POST"])
def api_rate_abuse():
    data = request.get_json(force=True, silent=True) or {}
    phone = data.get("phone", "+1-555-0199")
    record_log("API Rate Abuse / Resource Consumption", {"phone": phone})
    
    return jsonify({
        "vulnerability": "API4:2023 - Unrestricted Resource Consumption",
        "status": "OTP_SENT",
        "message": f"Verification SMS dispatched to {phone}",
        "imperva_defense": "Imperva Advanced Bot Protection (ABP) & Rate Limiting prevent API resource exhaustion and automated SMS/email pumping."
    })

# API5:2023 - Broken Function Level Authorization (BFLA)
@app.route("/api/v1/admin/export-database", methods=["POST", "GET"])
def api_bfla():
    auth_header = request.headers.get("Authorization", "Bearer guest_token")
    record_log("API BFLA", {"auth_header": auth_header})
    
    return jsonify({
        "vulnerability": "API5:2023 - Broken Function Level Authorization (BFLA)",
        "status": "VULNERABLE_BACKEND_EXECUTED",
        "message": "Administrative database export triggered successfully without role verification.",
        "exported_records_count": 15000,
        "imperva_defense": "Imperva API Security inspects endpoint hierarchies and enforces function-level access policies."
    })

# API9:2023 - Improper Inventory Management (Shadow & Deprecated APIs)
@app.route("/api/v0.9/legacy-export")
def api_shadow_inventory():
    record_log("Shadow / Deprecated API Probe", {"endpoint": "/api/v0.9/legacy-export"})
    return jsonify({
        "vulnerability": "API9:2023 - Improper Inventory Management (Shadow / Zombie API)",
        "status": "VULNERABLE_BACKEND_EXECUTED",
        "endpoint_version": "v0.9 (Deprecated 2021)",
        "unauthenticated_data": USERS_DB,
        "imperva_defense": "Imperva API Discovery continuously scans API traffic to discover shadow, deprecated, and undocumented endpoints in real-time."
    })

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 80))
    app.run(host="0.0.0.0", port=port, debug=False)
