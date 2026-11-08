#!/usr/bin/env bats
# A GitHub server error (502, 503, 504) is often gone a few seconds later, so
# every download of the install retries it instead of failing the install.

RETRY_FLAGS="--retry 5 --retry-delay 2"

setup() {
  load 'helpers/setup'
  BIN="$BATS_TEST_TMPDIR/bin"
  H="$BATS_TEST_TMPDIR/home"
  COUNT="$BATS_TEST_TMPDIR/installer-runs"
  mkdir -p "$BIN" "$H/.config/chezmoi"
  # An existing chezmoi config skips the module checklist, which is not under test.
  printf '[data]\n  modules = []\n' > "$H/.config/chezmoi/chezmoi.toml"
}

# The non-comment lines of the install's shell code that run curl or wget.
download_lines() {
  grep -nE '(curl|wget) -' "$REPO_ROOT/install.sh" "$REPO_ROOT"/.chezmoiscripts/*.sh* \
    "$REPO_ROOT"/.chezmoiscripts/*/*.sh* | grep -vE '^[^:]+:[0-9]+: *#'
}

@test "curl retries a 503 with the install's flags and gets the file" {
  command -v python3 > /dev/null 2>&1 || skip "python3 not available"
  hits="$BATS_TEST_TMPDIR/hits"
  port="$BATS_TEST_TMPDIR/port"
  # Answers 503 twice, then 200, and counts the requests.
  python3 -c '
import http.server, sys
hits, port = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    n = 0
    def do_GET(self):
        H.n += 1
        open(hits, "w").write(str(H.n))
        code = 503 if H.n <= 2 else 200
        self.send_response(code)
        self.end_headers()
        self.wfile.write(b"ok\n" if code == 200 else b"busy\n")
    def log_message(self, *a):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(port, "w").write(str(s.server_address[1]))
s.serve_forever()
' "$hits" "$port" &
  server=$!
  for _ in $(seq 50); do [ -s "$port" ] && break; sleep 0.2; done
  [ -s "$port" ] || { echo "the stub server did not start" >&2; return 1; }
  # shellcheck disable=SC2086 # the flags are words
  url="http://127.0.0.1:$(cat "$port")/file"
  # Piped, as the install uses it: what reaches the pipe cannot be taken back.
  # Without -f, curl writes each 503's body before retrying ("busy busy ok").
  run sh -c 'curl -fsSL $1 "$2" 2> /dev/null > "$3"' sh "$RETRY_FLAGS" "$url" "$BATS_TEST_TMPDIR/got"
  kill "$server"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/got")" = "ok" ]
  [ "$(cat "$hits")" -eq 3 ]
}

@test "every curl of the install retries server errors and fails on them" {
  run download_lines
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # The network probe of the preflight is the exception: it must answer fast.
  missing=$(printf '%s\n' "$output" | grep 'curl -' | grep -v -- '--max-time' | grep -v -- "$RETRY_FLAGS" || true)
  [ -z "$missing" ] || {
    printf 'curl without "%s":\n%s\n' "$RETRY_FLAGS" "$missing" >&2
    return 1
  }
  # -f keeps an error page out of the output, retried or final.
  unfailing=$(printf '%s\n' "$output" | grep 'curl -' | grep -vE 'curl( [^|)"]*)? -[a-zA-Z]*f' || true)
  [ -z "$unfailing" ] || {
    printf 'curl without -f:\n%s\n' "$unfailing" >&2
    return 1
  }
}

# A PATH without any real chezmoi, so install.sh downloads its installer: the
# stubs first, then the system tools only.
installer_stubs() {
  local fail_runs="$1"
  # The installer script curl returns: it fails its first FAIL_RUNS runs, as
  # get.chezmoi.io does when GitHub answers 503, then installs a stub chezmoi
  # into the folder given with -b.
  cat > "$BIN/curl" << STUB
#!/bin/sh
case "\$*" in
  *chezmoi.io/get*)
    cat << 'INSTALLER'
n=\$((\$(cat "$COUNT" 2> /dev/null || echo 0) + 1))
echo "\$n" > "$COUNT"
if [ "\$n" -le $fail_runs ]; then
  echo "curl: (22) The requested URL returned error: 503" >&2
  exit 1
fi
mkdir -p "\$2"
printf '#!/bin/sh\ncase "\$1" in source-path) exit 1 ;; esac\nexit 0\n' > "\$2/chezmoi"
chmod +x "\$2/chezmoi"
INSTALLER
    ;;
esac
exit 0
STUB
  printf '#!/bin/sh\nexit 0\n' > "$BIN/gh"
  printf '#!/bin/sh\ncase "$1" in --prefix) echo "%s/brew" ;; esac\n' "$BATS_TEST_TMPDIR" > "$BIN/brew"
  chmod +x "$BIN"/*
}

run_install() {
  run env -u CI -u CODESPACES -u GITHUB_TOKEN -u GH_TOKEN -u XDG_STATE_HOME \
    HOME="$H" XDG_CONFIG_HOME="$H/.config" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    sh "$REPO_ROOT/install.sh" --destination "$H/dest" < /dev/null
}

@test "a chezmoi installer that fails twice is run again and the install finishes" {
  installer_stubs 2
  run_install
  [ "$status" -eq 0 ]
  [ "$(cat "$COUNT")" -eq 3 ]
  # Into Homebrew's bin on macOS (the stub brew's prefix), ~/.local/bin elsewhere.
  [ -x "$H/.local/bin/chezmoi" ] || [ -x "$BATS_TEST_TMPDIR/brew/bin/chezmoi" ]
}

@test "a chezmoi installer that keeps failing stops the install after three runs" {
  installer_stubs 99
  run_install
  [ "$status" -ne 0 ]
  [ "$(cat "$COUNT")" -eq 3 ]
  [[ "$output" == *"chezmoi"* ]]
}
