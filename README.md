
# Simple Antivirus

This is a shell script checks for directory changes and when a change is detected it scans the directory for files it considers malicious. Malicious files become flagged and printed to the terminal then quarantined to a separate directory. There is also a restore tool that lets the user pick quarantined files from a list and decide whether each file was falsely flagged or genuinly malicious.



## Folder Hierarchy and Overview

```text
Os/
├── antivirusd.sh       # Antivirus monitor daemon (bash, infinite loop)
├── restore.sh          # Interactive quarantine restore/delete tool (bash)
├── Makefile            # Wrappers: `make antivirus`, `make restore`
├── README.md           # This file
├── dir/                # Monitored directory
│   └── geek.exe        # Example file under monitoring
├── malicious_dir/      # Quarantine directory for flagged files
│   └── Hangman.exe     # Example quarantined file
├── directory-info.last # Generated at runtime: last `ls -l dir` snapshot
└── directory-info.new  # Generated at runtime: current `ls -l dir` snapshot
```
## Prerequisites
## Step-by-step Instructions

### 1. Run the Antivirus daemon

cd /home/aly/programming/Os\
make antivirus\
or\
make

### 2. Run the Restore tool

cd /home/aly/programming/Os\
make restore 

### 3. Run the Cronjob script

cd /home/aly/programming/Os\
make antivirus-cron 
## Where Flagged-Extensions and Flagged-Keywords Are Defined

All detection logic lives in **`antivirusd.sh`**. There is no separate config file.

**1. Flagged extensions — `antivirusd.sh` lines 26–30 (`case` statement):**

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

**2. Flagged keywords — `antivirusd.sh` line 32 (`grep -qiE`):**

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

