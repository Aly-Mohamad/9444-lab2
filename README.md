
# Simple Antivirus

This is a shell script checks for directory changes and when a change is detected it scans the directory for files it considers malicious. Malicious files become flagged and printed to the terminal then quarantined to a separate directory. There is also a restore tool that lets the user pick quarantined files from a list and decide whether each file was falsely flagged or genuinly malicious.

## Table of Contents

- [Overview](#folder-hierarchy-and-overview)
- [Prerequisites](#prerequisites)
- [Usage — Step-by-Step](#step-by-step-instructions)
- [Where Flagged-Extensions and Flagged-Keywords Are Defined](#where-flagged-extensions-and-flagged-keywords-are-defined)
- [Cron Job](#cron-job)
- [Whitelist](#whitelist)

## Folder Hierarchy and Overview

```text
Os/
├── antivirusd.sh       # Antivirus monitor daemon (bash, infinite loop)
├── antivirus-cron.sh   # One-shot scan for cron scheduling (bash, single pass)
├── restore.sh          # Interactive quarantine restore/delete tool (bash)
├── Makefile            # Wrappers: `make antivirus`, `make restore`
├── README.md           # This file
├── dir/                # Monitored directory
│   └── geek.exe        # Example file under monitoring
├── malicious_dir/      # Quarantine directory for flagged files
│   └── Hangman.exe     # Example quarantined file
├── .whitelist          # Basenames of restored (false-positive) files, one per line
├── directory-info.last # Generated at runtime: last `ls -l dir` snapshot
└── directory-info.new  # Generated at runtime: current `ls -l dir` snapshot
```
## Prerequisites


- **OS:** Ubuntu (20.04 / 22.04 / 24.04) or any Debian-based Linux. Also works on WSL.
- **Tools used by the scripts (all standard on Ubuntu):**
  - `bash` — interpreter (`#!/bin/bash`)
  - `coreutils` — `ls`, `cp`, `rm`, `sleep`, `basename`, `mkdir`
  - `diffutils` — `cmp` (for snapshot comparison)
  - `grep` — for keyword scan (`grep -qiE`)
  - `make` — only needed for `make antivirus` / `make restore` shortcuts

### How to Install Them on Ubuntu

```bash
sudo apt update
sudo apt install -y bash coreutils diffutils grep make

# Verify:
bash --version
ls --version
cmp --version
grep --version
make --version
```

No extra packages and no root required to run the tools.

## Step-by-step Instructions

### 1. Run the Antivirus daemon
```bash
cd /home/aly/programming/Os

make
# or
make antivirus
# or
./antivirusd.sh dir malicious_dir 2
```

### 2. Run the Restore tool
```bash
cd /home/aly/programming/Os

make restore
# or
./restore.sh dir malicious_dir
```

### 3. Run the Cronjob script
```bash
cd /home/aly/programming/Os

make antivirus-cron
# or
./antivirus-cron.sh dir malicious_dir
```

## Where Flagged-Extensions and Flagged-Keywords Are Defined

All detection logic lives in **`antivirusd.sh`**. There is no separate config file.

**1. Flagged extensions — `antivirusd.sh` lines 23–27 (`case` statement inside `scan_directory()`):**

```bash
case "$file" in
    *.exe|*.bat|*.vbs|*.scr|*.ps1)
        malicious=true
        ;;
esac
```

- List: `*.exe`, `*.bat`, `*.vbs`, `*.scr`, `*.ps1`
- To add e.g. `*.js` / `*.dll`: edit that line to
  `*.exe|*.bat|*.vbs|*.scr|*.ps1|*.js|*.dll)`.

**2. Flagged keywords — `antivirusd.sh` line 29 (`grep -qiE` inside `scan_directory()`):**

```bash
if grep -qiE 'virus|trojan|malware|worm|ransomware' "$file"; then
    malicious=true
fi
```

- List (case-insensitive, extended regex): `virus`, `trojan`, `malware`,
  `worm`, `ransomware`
- Flags: `-q` (quiet), `-i` (ignore case), `-E` (extended regex).
- To add e.g. `spyware`: change to `'virus|trojan|malware|worm|ransomware|spyware'`.
- Note: `grep` scans binary `.exe` files too; a match anywhere flags it.
  Combined with the extension rule, every `.exe` is already flagged regardless
  of content.
## Cron Job

### Prerequisites (before configuring cron)

**1. cron installed and running on Ubuntu:**
   ```bash
   sudo apt update
   sudo apt install -y cron
   sudo systemctl enable cron
   sudo systemctl start cron
   sudo systemctl status cron --no-pager
   ```
**2. Script is executable and paths are correct:**
   ```bash
   cd /home/aly/programming/Os
   chmod +x antivirus-cron.sh
   ls -l antivirus-cron.sh dir malicious_dir
   # Test it once manually before scheduling:
   ./antivirus-cron.sh dir malicious_dir
   echo "exit code: $?"
   ls -l dir/ malicious_dir/
   ```

### Step-by-step manual to configure the cron job

**Goal: run the scan every 1 minute at second 23.**

**Steps:**

**1. Open your personal crontab:**
   ```bash
   crontab -e
   # use vim
   ```
**2. Add this line (all on one line, absolute paths):**
   ```cron
   * * * * * sleep 23; cd /home/aly/programming/Os && ./antivirus-cron.sh dir malicious_dir >> /home/aly/programming/Os/antivirus-cron.log 2>&1
   ```
   - `* * * * *` = every minute.
   - `sleep 23;` = wait 23 seconds so the scan fires at second ~23.
   - `cd ... && ./antivirus-cron.sh dir malicious_dir` = run one scan pass.
   - `>> ...log 2>&1` = append `Same`/`Changed`/`... is malicious` output to a log.

**3. Save and exit (esc then :wq in vim). You should see:**
   `crontab: installing new crontab`.

**4. Verify it is installed and cron is running:**
   ```bash
   crontab -l
   sudo systemctl status cron --no-pager | head -n 10
   ```
**5. Wait ~2 minutes, then check the log and quarantine dirs:**
   ```bash
   sleep 130; tail -n 20 /home/aly/programming/Os/antivirus-cron.log
   ls -l /home/aly/programming/Os/dir/ /home/aly/programming/Os/malicious_dir/
   grep CRON /var/log/syslog | tail -n 10  # shows cron executed the job
   ```
**6. To stop/remove the schedule later:**
   ```bash
   crontab -e   # delete (or comment with #) the antivirus-cron line, save
   crontab -l   # confirm it is gone
   ```

### Cron expression: every 3rd Friday of the month at 12:31 am

Plain cron has no "Nth weekday of month" field, so `31 0 * * 5` alone would run
**every** Friday at 00:31. The standard workaround is to run every Friday at
00:31 and add a `test` guard that only lets the 3rd Friday (days 15–21 of the
month) through:

```cron
31 0 * * 5 [ $(date +\%d) -ge 15 -a $(date +\%d) -le 21 ] && cd /home/aly/programming/Os && ./antivirus-cron.sh dir malicious_dir >> /home/aly/programming/Os/antivirus-cron.log 2>&1
```

- `31 0 * * 5` = at 00:31 on every Friday (`5` = Friday; `0` = Sunday).
- `[ $(date +\%d) -ge 15 -a $(date +\%d) -le 21 ]` = only continue if the
  day-of-month is 15–21, which is exactly the 3rd Friday. (`\%` — the backslash
  is required in crontabs because unescaped `%` means newline.)
- `&& ...` = run the scan + log only when the guard passes.
- Why 15–21? The 1st Friday falls on days 1–7, 2nd on 8–14, **3rd on 15–21**,
  4th on 22–28 (5th, if it exists, on 29–31).

## Whitelist

Restoring a file with `restore.sh` used to be pointless: the file still matched
its flagged extension/keyword, so the next scan re-quarantined it. The whitelist
fixes that — a restored file is remembered as a false positive and skipped by
all future scans, even after the daemon is stopped and restarted.

**How a file gets added to the whitelist (`restore.sh`, choice `1` branch):**

1. User picks a quarantined file and chooses `1. Restore`.
2. After `cp quarantine → dir` + `rm quarantine`, the script runs:
   ```bash
   touch ".whitelist"
   if ! grep -Fxq "$filename" ".whitelist"; then
       echo "$filename" >> ".whitelist"
   fi
   echo "$filename added to whitelist"
   ```
3. So `.whitelist` (in the project directory, one basename per line) gains an
   entry, e.g. `note.exe`. Choosing `2` (delete) or `3` (leave) adds nothing.
   Because it is a plain file on disk, it **persists across daemon runs**.

**How the daemon checks it during a scan (`antivirusd.sh` lines 15–19 and
`antivirus-cron.sh`, top of the `for` loop inside `scan_directory()`, before the
extension/keyword checks):**

```bash
# Bonus 2: Whitelist check - skip files restored as false positives
whitelist_name=$(basename "$file")
if [ -f ".whitelist" ] && grep -Fxq "$whitelist_name" ".whitelist"; then
    echo "$file is whitelisted, skipping"
    continue
fi
```

- `grep -Fxq` = exact (`-x`), fixed-string (`-F`), quiet (`-q`) match, so only
  the exact basename is skipped (no substring/regex surprises).
- The `continue` skips both the `*.exe|*.bat|...` extension check and the
  `grep -qiE 'virus|...'` keyword check for that file.
- Applies to both scanners, so neither the looping daemon nor the cron
  one-shot scan will re-flag a whitelisted file.

**Manage it manually:**

```bash
cat .whitelist                    # inspect entries
rm .whitelist                     # clear all (restored files become flaggable again)
sed -i '/^note\.exe$/d' .whitelist  # remove one entry
```

