#!/bin/bash
#
#  publish-site-two.sh  —  publishing for GitHub Pages site #2
#
#  Run it a few times to set itself up, then switch on automatic mode and
#  forget it exists: saving a file in the folder is all you ever do again.
#
#    1st run  -> makes an SSH key and stops, so you can paste it into GitHub
#    2nd run  -> clones the repository into a local folder
#    then     -> ./publish-site-two.sh --auto on
#                from that moment your Mac watches the folder and publishes
#                by itself, whether or not this window is open.
#
#  USAGE
#    ./publish-site-two.sh --auto on       publish automatically from now on
#    ./publish-site-two.sh --auto off      go back to manual
#    ./publish-site-two.sh --auto status   is it running? what did it do?
#
#    ./publish-site-two.sh                 publish right now, by hand
#    ./publish-site-two.sh "new seminar"   ... with your own commit message
#    ./publish-site-two.sh --compare       compare your OLD folder to the site
#    ./publish-site-two.sh --status        list what would be published
#
#  Make it runnable once with:   chmod +x publish-site-two.sh
#

set -u

# ══ CONFIG — fill these in once ═════════════════════════════════════════
GH_USER="enigmacgvst2-code"          # the GitHub username that owns site 2
GH_REPO="website"          # the repository name
COMMIT_NAME="Marianna Annunziatella"      # name shown on your commits
COMMIT_EMAIL="enigmacgvst2@gmail.com"        # email registered on THAT account

LOCAL_DIR="$HOME/Sites/$GH_REPO"          # where the site will live on your Mac
OLD_FOLDER="$HOME/website"                             # optional: your existing plain folder,
                                          # only used by --compare

CHECK_EVERY=300                           # automatic mode: seconds between checks
QUIET_FOR=1                               # ... but wait until you have not touched
                                          #     a file for this many minutes
# ── these two just need to differ between the two scripts; leave as is ──
SSH_ALIAS="github-two"
SSH_KEY="$HOME/.ssh/id_gh_two"
# ════════════════════════════════════════════════════════════════════════


AUTO_RUN=no
if [ "${1:-}" = "--auto-run" ]; then AUTO_RUN=yes; shift; fi

LABEL="local.publish.$GH_REPO"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOGFILE="$HOME/Library/Logs/publish-$GH_REPO.log"

if [ "$AUTO_RUN" = yes ]; then
  b()    { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
  info() { printf '[%s]   %s\n' "$(date '+%F %T')" "$*"; }
  warn() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
  notify() {
    command -v osascript >/dev/null 2>&1 && \
      osascript -e "display notification \"$1\" with title \"$GH_REPO\"" >/dev/null 2>&1
  }
  die()  { printf '[%s] STOPPED: %s\n' "$(date '+%F %T')" "$*"; notify "$1"; exit 1; }
else
  b()      { printf '\n\033[1m%s\033[0m\n' "$*"; }
  info()   { printf '   %s\n' "$*"; }
  warn()   { printf '\n\033[33m%s\033[0m\n' "$*"; }
  notify() { :; }
  die()    { printf '\n\033[31mStopped:\033[0m %s\n\n' "$*" >&2; exit 1; }
fi

command -v git >/dev/null 2>&1 || die "git is not installed. Run:  xcode-select --install"

case "$GH_USER$GH_REPO$COMMIT_EMAIL" in
  *CHANGE-ME*) die "Open this file in a text editor and fill in the CONFIG block at the top." ;;
esac


# ── 0. switching automatic mode on and off ──────────────────────────────
if [ "${1:-}" = "--auto" ]; then
  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  case "${2:-}" in

    on)
      [ -d "$LOCAL_DIR/.git" ] || die "Set the site up first — run this script with no
   arguments until it has cloned $GH_REPO into $LOCAL_DIR."
      [ -x "$SELF" ] || die "This file is not executable yet. Run:  chmod +x $SELF"
      mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
      cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>            <string>$LABEL</string>
  <key>ProgramArguments</key>
    <array>
      <string>$SELF</string>
      <string>--auto-run</string>
    </array>
  <key>StartInterval</key>    <integer>$CHECK_EVERY</integer>
  <key>WatchPaths</key>       <array><string>$LOCAL_DIR</string></array>
  <key>RunAtLoad</key>        <false/>
  <key>StandardOutPath</key>  <string>$LOGFILE</string>
  <key>StandardErrorPath</key><string>$LOGFILE</string>
  <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
      launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1
      launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null \
        || launchctl load "$PLIST" 2>/dev/null \
        || die "macOS refused to start the background job. The file is at $PLIST"
      b "Automatic publishing is ON for $GH_REPO"
      info "Edit and save files in $LOCAL_DIR — nothing else."
      info "Changes go live within about $((CHECK_EVERY / 60)) minutes."
      info "Check on it any time with:  $(basename "$0") --auto status"
      echo
      exit 0 ;;

    off)
      launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 \
        || launchctl unload "$PLIST" >/dev/null 2>&1
      rm -f "$PLIST"
      b "Automatic publishing is OFF for $GH_REPO"
      info "Your files are untouched. Publish by hand with:  $(basename "$0")"
      echo
      exit 0 ;;

    status)
      if launchctl list 2>/dev/null | grep -q "$LABEL"; then
        b "Automatic publishing is ON for $GH_REPO"
      else
        b "Automatic publishing is OFF for $GH_REPO"
      fi
      if [ -f "$LOGFILE" ]; then
        info "Last few things it did:"
        echo
        tail -n 12 "$LOGFILE" | sed 's/^/     /'
      else
        info "It has not run yet."
      fi
      if [ -d "$LOCAL_DIR/.git" ]; then
        PENDING=$(git -C "$LOCAL_DIR" status --porcelain)
        if [ -n "$PENDING" ]; then
          echo; info "Waiting to be published:"; printf '%s\n' "$PENDING" | sed 's/^/     /'
        fi
      fi
      echo
      exit 0 ;;

    *) die "Use one of:  --auto on   |   --auto off   |   --auto status" ;;
  esac
fi


# ── 1. an SSH key belonging to this account ─────────────────────────────
NEW_KEY=no
if [ ! -f "$SSH_KEY" ]; then
  [ "$AUTO_RUN" = yes ] && die "the SSH key is missing; run the script by hand once"
  b "Creating an SSH key for $GH_USER"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$SSH_KEY" -C "$COMMIT_EMAIL" -N "" -q \
    || die "could not create the key"
  NEW_KEY=yes
fi


# ── 2. teach ssh which key to use for this account ──────────────────────
touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"
if ! grep -qE "^Host[[:space:]]+$SSH_ALIAS([[:space:]]|\$)" "$HOME/.ssh/config"; then
  b "Adding '$SSH_ALIAS' to ~/.ssh/config"
  cat >> "$HOME/.ssh/config" <<EOF

Host $SSH_ALIAS
  HostName github.com
  User git
  IdentityFile $SSH_KEY
  IdentitiesOnly yes
EOF
fi


# ── 3. a brand new key has to be registered by hand, once ───────────────
if [ "$NEW_KEY" = yes ]; then
  b "One manual step, and only this once"
  echo
  cat "$SSH_KEY.pub"
  echo
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$SSH_KEY.pub" && info "(the key above is now on your clipboard)"
  fi
  info "1. Open github.com and sign in as $GH_USER — the Google button is fine"
  info "2. Settings  ->  SSH and GPG keys  ->  New SSH key"
  info "3. Paste the key, give it any title you like, click 'Add SSH key'"
  info "4. Run this script again"
  echo
  exit 0
fi


# ── 4. check GitHub recognises the key, and that it is the RIGHT account ─
GREETING=$(ssh -T -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
           -o ConnectTimeout=15 "git@$SSH_ALIAS" 2>&1 || true)
case "$GREETING" in
  *"successfully authenticated"*) ;;
  *) die "GitHub did not accept the key for $SSH_ALIAS.
   Check that the contents of $SSH_KEY.pub appear under
   github.com -> Settings -> SSH and GPG keys while signed in as $GH_USER.
   GitHub said: $GREETING" ;;
esac
WHO=$(printf '%s' "$GREETING" | sed -n 's/^Hi \([^!]*\)!.*/\1/p')
if [ -n "$WHO" ] && [ "$WHO" != "$GH_USER" ]; then
  die "This key belongs to GitHub user '$WHO', but this script is configured
   for '$GH_USER'. The two scripts have most likely been given the same
   SSH_KEY or SSH_ALIAS — they must differ."
fi


# ── 5. first time here: clone the repository ────────────────────────────
if [ ! -d "$LOCAL_DIR/.git" ]; then
  [ -e "$LOCAL_DIR" ] && die "$LOCAL_DIR already exists but is not a clone.
   Rename it out of the way first, then run this again."
  b "Cloning $GH_USER/$GH_REPO into $LOCAL_DIR"
  mkdir -p "$(dirname "$LOCAL_DIR")"
  git clone "git@$SSH_ALIAS:$GH_USER/$GH_REPO.git" "$LOCAL_DIR" || die "clone failed"
  git -C "$LOCAL_DIR" config user.name  "$COMMIT_NAME"
  git -C "$LOCAL_DIR" config user.email "$COMMIT_EMAIL"
  b "Ready. From now on, edit the files in $LOCAL_DIR"
  if [ -n "$OLD_FOLDER" ]; then
    info "First, run:  $0 --compare"
    info "to see what your old folder has that the live site does not."
  fi
  info "Then switch on automatic publishing:  $(basename "$0") --auto on"
  echo
  exit 0
fi


# ── 5b. an older clone may still talk to GitHub over https, which now asks
#        for a password on every push and refuses the one you type. Point it
#        at the SSH key instead.
WANT_URL="git@$SSH_ALIAS:$GH_USER/$GH_REPO.git"
HAVE_URL=$(git -C "$LOCAL_DIR" remote get-url origin 2>/dev/null || echo "")
if [ "$HAVE_URL" != "$WANT_URL" ]; then
  case "$HAVE_URL" in
    *"$GH_USER/$GH_REPO"*)
      b "Switching $GH_REPO from password-based https to your SSH key"
      git -C "$LOCAL_DIR" remote set-url origin "$WANT_URL" \
        || die "could not update the remote address of $LOCAL_DIR"
      info "was: $HAVE_URL"
      info "now: $WANT_URL" ;;
    "")
      die "$LOCAL_DIR has no 'origin' remote. Add one with:
   git -C $LOCAL_DIR remote add origin $WANT_URL" ;;
    *)
      die "$LOCAL_DIR points at a different repository:
     $HAVE_URL
   but this script is set up for $GH_USER/$GH_REPO. Check LOCAL_DIR, GH_USER
   and GH_REPO in the CONFIG block — the two scripts may be pointing at the
   same folder." ;;
  esac
fi

# an older clone may also be committing under the wrong name and address
[ -n "$(git -C "$LOCAL_DIR" config --local user.email || true)" ] \
  || git -C "$LOCAL_DIR" config user.email "$COMMIT_EMAIL"
[ -n "$(git -C "$LOCAL_DIR" config --local user.name || true)" ] \
  || git -C "$LOCAL_DIR" config user.name "$COMMIT_NAME"


# ── 6. the two read-only modes ──────────────────────────────────────────
if [ "${1:-}" = "--compare" ]; then
  [ -n "$OLD_FOLDER" ] || die "Set OLD_FOLDER in the CONFIG block first."
  [ -d "$OLD_FOLDER" ] || die "OLD_FOLDER '$OLD_FOLDER' does not exist."
  b "Comparing your old folder with the live site"
  diff -rq "$OLD_FOLDER" "$LOCAL_DIR" -x .git -x .DS_Store || true
  echo
  info "'Only in $OLD_FOLDER' = you never uploaded it; copy it into $LOCAL_DIR"
  info "'Only in $LOCAL_DIR' = it is on the site but missing from your old folder"
  info "'... differ'         = both versions changed; open each and decide"
  echo
  exit 0
fi

if [ "${1:-}" = "--status" ]; then
  b "Changes waiting to be published"
  git -C "$LOCAL_DIR" status --short
  echo
  exit 0
fi


# ── 7. publish ──────────────────────────────────────────────────────────
cd "$LOCAL_DIR" || die "cannot open $LOCAL_DIR"
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) \
  || die "$LOCAL_DIR is in an odd state — no current branch."

# Unattended: leave files alone until they have been still for a while, so a
# half-finished edit never goes live.
if [ "$AUTO_RUN" = yes ]; then
  if [ -z "$(git status --porcelain)" ]; then exit 0; fi
  STILL_WARM=$(find . -path ./.git -prune -o -type f -mmin "-$QUIET_FOR" -print 2>/dev/null | head -n 1)
  if [ -n "$STILL_WARM" ]; then
    info "still editing — will look again in $((CHECK_EVERY / 60)) minutes"
    exit 0
  fi
fi

b "Checking for changes made on github.com"
git pull --rebase --autostash origin "$BRANCH" \
  || die "could not merge the website's version with yours.
   Usually this means the same file changed in both places.
   Run 'git -C $LOCAL_DIR status' to see which, or ask for help before continuing."

# If GitHub changed a file you also edited, 'pull --autostash' can report
# success while leaving <<<<<<< / >>>>>>> conflict markers in your files
# (your own version stays safe in 'git stash'). Never publish that.
CONFLICTS=$( { git diff --name-only --diff-filter=U
               git grep -lE '^(<<<<<<<|>>>>>>>) ' -- . ; } 2>/dev/null | sort -u )
if [ -n "$CONFLICTS" ]; then
  die "Publishing paused: your edits clash with changes made on github.com in
$(printf '%s\n' "$CONFLICTS" | sed 's/^/     /')
   Nothing was published. Fix those files (look for <<<<<<< and >>>>>>>),
   or ask for help, then run this script again."
fi

git add -A
if git diff --cached --quiet; then
  [ "$AUTO_RUN" = yes ] && exit 0
  b "Nothing to publish — $GH_REPO is already up to date."
  echo
  exit 0
fi

DELETED=$(git diff --cached --name-status | awk '$1 ~ /^D/ { print "     " $2 }')
if [ -n "$DELETED" ]; then
  if [ "$AUTO_RUN" = yes ] || [ ! -t 0 ]; then
    git reset >/dev/null
    warn "NOT published: this would remove files from the live site."
    printf '%s\n' "$DELETED"
    info "Nothing was pushed. Run the script by hand to confirm the deletion."
    notify "Publishing paused — a change would delete pages. Run the script by hand."
    exit 1
  fi
  warn "This will REMOVE the following from the live site:"
  printf '%s\n' "$DELETED"
  printf '\n   Continue? [y/N] '
  read -r ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) ;;
    *) git reset >/dev/null; die "Cancelled. Nothing was pushed." ;;
  esac
fi

if [ "$AUTO_RUN" = yes ]; then
  MSG="automatic update $(date '+%Y-%m-%d %H:%M')"
else
  MSG="${1:-update $(date '+%Y-%m-%d %H:%M')}"
fi
git commit -q -m "$MSG"        || die "commit failed"
git push  -q origin "$BRANCH"  || die "push failed — are you online?"

if [ "$AUTO_RUN" = yes ]; then
  CHANGED=$(git show --stat --oneline HEAD | tail -n 1 | sed 's/^ *//')
  b "Published: $CHANGED"
else
  b "Published."
  info "The site rebuilds in about a minute."
  info "Progress: https://github.com/$GH_USER/$GH_REPO/actions"
  echo
fi
