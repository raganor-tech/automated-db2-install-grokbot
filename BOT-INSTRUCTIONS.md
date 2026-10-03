# Bot instructions for the Db2 lab menu

Run this on the machine that has AlmaLinux 9 in WSL2, not from chat alone.

1. Confirm the file `v11.5.9_linuxx64_server_dec.tar.gz` is already on disk. If it is missing, stop and ask for the path. Do not download it.
2. Run `sudo bash db2-lab-menu.sh`.
3. The script prints the GROK BOT / DB2 / INSTALLATION heading, then a menu.
4. Use the menu in this order when asked to do a full lab: 1 check, 2 install, 3 start, 4 smoke test.
5. Choice 2 calls `passwd` for `db2inst1` and `db2fenc1`. Let the person type those on the machine. Never ask for them in chat, and never write them into a file.
6. Stop on the first failing step and show the terminal output. Do not continue past a failure.
7. Do not run `db2stop` unless the person asks.
