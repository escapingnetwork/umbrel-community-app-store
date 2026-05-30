package main

import (
	"encoding/json"
	"html/template"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

const (
	smpConfigDir   = "/etc/opt/simplex"
	xftpConfigDir  = "/etc/opt/simplex-xftp"
	smpStateDir    = "/var/opt/simplex"
	xftpStateDir   = "/var/opt/simplex-xftp"
)

type ServerStatus struct {
	SMPInitialized  bool   `json:"smp_initialized"`
	XFTPInitialized bool   `json:"xftp_initialized"`
	SMPFingerprint  string `json:"smp_fingerprint,omitempty"`
	SMPHost         string `json:"smp_host,omitempty"`
	XFTPFingerprint string `json:"xftp_fingerprint,omitempty"`
	XFTPHost        string `json:"xftp_host,omitempty"`
}

type InitRequest struct {
	Hostname     string `json:"hostname"`
	RequirePass  bool   `json:"require_pass"`
	Password     string `json:"password,omitempty"`
	StoreLog     bool   `json:"store_log"`
	EnableStats  bool   `json:"enable_stats"`
}

func main() {
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RealIP)

	// Static files (for future custom CSS/JS)
	r.Handle("/static/*", http.StripPrefix("/static/", http.FileServer(http.Dir("./web/static"))))

	// Main dashboard
	r.Get("/", handleDashboard)

	// Simple health endpoint for Umbrel proxy / Docker healthchecks
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// API
	r.Route("/api", func(r chi.Router) {
		r.Get("/status", handleStatus)
		r.Post("/init", handleInit)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("SimpleX Relay Dashboard starting on :%s", port)

	// Add basic recovery so one bad request doesn't kill the whole server
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					log.Printf("PANIC recovered: %v", rec)
					http.Error(w, "Internal Server Error", http.StatusInternalServerError)
				}
			}()
			next.ServeHTTP(w, r)
		})
	})

	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Printf("Server stopped: %v", err)
		// Do not call log.Fatal here — let the outer restart wrapper handle it
		os.Exit(1)
	}
}

func handleDashboard(w http.ResponseWriter, r *http.Request) {
	status := getStatus()

	tmpl := template.Must(template.New("dashboard").Funcs(template.FuncMap{
		"formatTime": func(t time.Time) string { return t.Format("2006-01-02 15:04") },
	}).Parse(dashboardHTML))

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tmpl.Execute(w, status); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	status := getStatus()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

func handleInit(w http.ResponseWriter, r *http.Request) {
	var req InitRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if req.Hostname == "" {
		http.Error(w, "Hostname is required", http.StatusBadRequest)
		return
	}

	result := performInitialization(req)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func getStatus() ServerStatus {
	status := ServerStatus{}

	// Check SMP
	if _, err := os.Stat(filepath.Join(smpConfigDir, "smp-server.ini")); err == nil {
		status.SMPInitialized = true
		status.SMPFingerprint = readFingerprint(filepath.Join(smpConfigDir, "fingerprint"))
		status.SMPHost = readHostFromIni(filepath.Join(smpConfigDir, "smp-server.ini"))
	}

	// Check XFTP
	if _, err := os.Stat(filepath.Join(xftpConfigDir, "xftp-server.ini")); err == nil {
		status.XFTPInitialized = true
		status.XFTPFingerprint = readFingerprint(filepath.Join(xftpConfigDir, "fingerprint"))
		status.XFTPHost = readHostFromIni(filepath.Join(xftpConfigDir, "xftp-server.ini"))
	}

	return status
}

func readFingerprint(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func readHostFromIni(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "host:") {
			return strings.TrimSpace(strings.TrimPrefix(line, "host:"))
		}
	}
	return ""
}

func performInitialization(req InitRequest) map[string]string {
	results := map[string]string{
		"smp":  "not attempted",
		"xftp": "not attempted",
	}

	// SMP Initialization
	smpArgs := []string{"init", "-y", "-n", req.Hostname}
	if req.StoreLog {
		smpArgs = append(smpArgs, "-l")
	}
	if req.RequirePass && req.Password != "" {
		smpArgs = append(smpArgs, "--password", req.Password)
	} else {
		smpArgs = append(smpArgs, "--no-password")
	}

	if err := runCommand("/usr/local/bin/smp-server", smpArgs...); err != nil {
		results["smp"] = "failed: " + err.Error()
	} else {
		results["smp"] = "success"
	}

	// XFTP Initialization
	xftpArgs := []string{"init", "-y", "-n", req.Hostname, "--quota", "10gb"}
	if err := runCommand("/usr/local/bin/xftp-server", xftpArgs...); err != nil {
		results["xftp"] = "failed: " + err.Error()
	} else {
		results["xftp"] = "success"
	}

	return results
}

func runCommand(binary string, args ...string) error {
	cmd := exec.Command(binary, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// dashboardHTML is a self-contained beautiful dashboard (Go + HTMX + Tailwind via CDN)
const dashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SimpleX Relay • Umbrel</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/htmx.org@1.9.12"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    <style>
        body { font-family: 'Inter', system_ui, sans-serif; }
        .font-display { font-family: 'Space Grotesk', 'Inter', sans-serif; font-weight: 600; }
        .section-header { font-size: 0.75rem; letter-spacing: 0.05em; font-weight: 600; text-transform: uppercase; }
    </style>
</head>
<body class="bg-zinc-950 text-zinc-200">
    <div class="max-w-5xl mx-auto px-6 py-10">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
            <div class="flex items-center gap-x-4">
                <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-500 flex items-center justify-center shadow-lg shadow-indigo-500/20">
                    <i class="fa-solid fa-server text-white text-3xl"></i>
                </div>
                <div>
                    <h1 class="text-3xl font-display tracking-tighter">SimpleX Relay</h1>
                    <p class="text-zinc-500 text-sm">Self-hosted SMP + XFTP • Tailscale-first</p>
                </div>
            </div>
            <div class="text-xs px-3 py-1.5 bg-zinc-900 border border-zinc-800 rounded-2xl flex items-center gap-x-2">
                <div class="w-2 h-2 bg-emerald-400 rounded-full animate-pulse"></div>
                <span class="text-emerald-400 font-medium">Dashboard Live</span>
            </div>
        </div>

        <!-- Status Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <!-- SMP -->
            <div class="bg-zinc-900 border border-zinc-800 rounded-3xl p-7">
                <div class="flex items-center gap-x-3 mb-5">
                    <div class="w-9 h-9 rounded-2xl bg-blue-500/10 flex items-center justify-center">
                        <i class="fa-solid fa-comments text-blue-400"></i>
                    </div>
                    <div>
                        <div class="section-header text-blue-400">SMP Server</div>
                        <div class="font-semibold text-xl">Message Relay</div>
                    </div>
                </div>
                {{if .SMPInitialized}}
                    <div class="space-y-3 text-sm">
                        <div class="flex justify-between items-center">
                            <span class="text-zinc-400">Status</span>
                            <span class="px-3 py-1 bg-emerald-500/10 text-emerald-400 rounded-2xl text-xs font-semibold">INITIALIZED</span>
                        </div>
                        {{if .SMPFingerprint}}<div><span class="text-zinc-400">Fingerprint:</span> <code class="font-mono text-xs bg-black px-2 py-0.5 rounded">{{.SMPFingerprint}}</code></div>{{end}}
                        {{if .SMPHost}}<div><span class="text-zinc-400">Host:</span> <span class="font-medium">{{.SMPHost}}</span></div>{{end}}
                    </div>
                {{else}}
                    <div class="px-4 py-3 bg-amber-500/10 border border-amber-500/20 rounded-2xl text-amber-300 text-sm">
                        Not initialized yet
                    </div>
                {{end}}
            </div>

            <!-- XFTP -->
            <div class="bg-zinc-900 border border-zinc-800 rounded-3xl p-7">
                <div class="flex items-center gap-x-3 mb-5">
                    <div class="w-9 h-9 rounded-2xl bg-violet-500/10 flex items-center justify-center">
                        <i class="fa-solid fa-file text-violet-400"></i>
                    </div>
                    <div>
                        <div class="section-header text-violet-400">XFTP Server</div>
                        <div class="font-semibold text-xl">File Relay</div>
                    </div>
                </div>
                {{if .XFTPInitialized}}
                    <div class="space-y-3 text-sm">
                        <div class="flex justify-between items-center">
                            <span class="text-zinc-400">Status</span>
                            <span class="px-3 py-1 bg-emerald-500/10 text-emerald-400 rounded-2xl text-xs font-semibold">INITIALIZED</span>
                        </div>
                        {{if .XFTPFingerprint}}<div><span class="text-zinc-400">Fingerprint:</span> <code class="font-mono text-xs bg-black px-2 py-0.5 rounded">{{.XFTPFingerprint}}</code></div>{{end}}
                        {{if .XFTPHost}}<div><span class="text-zinc-400">Host:</span> <span class="font-medium">{{.XFTPHost}}</span></div>{{end}}
                    </div>
                {{else}}
                    <div class="px-4 py-3 bg-amber-500/10 border border-amber-500/20 rounded-2xl text-amber-300 text-sm">
                        Not initialized yet
                    </div>
                {{end}}
            </div>
        </div>

        <!-- Initialization Wizard -->
        {{if not .SMPInitialized}}
        <div class="bg-zinc-900 border border-zinc-800 rounded-3xl p-8 mb-8" id="init-section">
            <div class="flex items-center gap-x-3 mb-6">
                <i class="fa-solid fa-magic text-emerald-400 text-xl"></i>
                <div class="font-semibold text-2xl tracking-tight">Initialize Your Relays</div>
            </div>

            <form hx-post="/api/init" hx-target="#init-result" hx-swap="innerHTML" class="space-y-6">
                <div>
                    <label class="block text-sm font-medium text-zinc-300 mb-2">Server Hostname (Tailscale MagicDNS recommended)</label>
                    <input type="text" name="hostname" placeholder="umbrel.yourname.ts.net" required
                           class="w-full bg-black border border-zinc-700 focus:border-emerald-500 rounded-2xl px-4 py-3 text-sm font-mono outline-none">
                    <p class="text-xs text-zinc-500 mt-1.5">Example: umbrel.yourname.ts.net or your custom domain</p>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="flex items-center gap-x-2 text-sm font-medium text-zinc-300 mb-2">
                            <input type="checkbox" name="require_pass" value="true" class="accent-emerald-500"> 
                            Require password for new queues
                        </label>
                        <input type="password" name="password" placeholder="Optional password" 
                               class="w-full bg-black border border-zinc-700 rounded-2xl px-4 py-2.5 text-sm font-mono outline-none">
                    </div>
                    <div class="space-y-2 text-sm">
                        <label class="flex items-center gap-x-2">
                            <input type="checkbox" name="store_log" value="true" checked class="accent-emerald-500"> 
                            Enable store log (recommended)
                        </label>
                        <label class="flex items-center gap-x-2">
                            <input type="checkbox" name="enable_stats" value="true" class="accent-emerald-500"> 
                            Enable daily statistics
                        </label>
                    </div>
                </div>

                <button type="submit"
                        class="w-full md:w-auto flex items-center justify-center gap-x-2 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 transition font-semibold px-8 py-3 rounded-2xl text-sm">
                    <i class="fa-solid fa-play"></i>
                    <span>Initialize SMP + XFTP Servers</span>
                </button>
            </form>

            <div id="init-result" class="mt-6 text-sm"></div>
        </div>
        {{end}}

        <!-- Tailscale Info -->
        <div class="bg-zinc-900 border border-zinc-800 rounded-3xl p-7 text-sm text-zinc-400">
            <div class="font-semibold text-white mb-2 flex items-center gap-x-2">
                <i class="fa-solid fa-shield-halved"></i>
                <span>Tailscale Recommended</span>
            </div>
            Once initialized, connect to your relays using the hostname above from any device on the same Tailscale network.
            No public ports needed.
        </div>
    </div>

    <script>
        // Optional: auto-refresh status every 30s
        setInterval(() => {
            htmx.trigger('#status-refresh', 'refresh');
        }, 30000);
    </script>
</body>
</html>`
