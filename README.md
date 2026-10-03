# IBM Db2 11.5.9 on Windows 11 with WSL2 and AlmaLinux 9

A lab install of Db2 11.5.9 Community Edition (SERVER) inside AlmaLinux 9 on WSL2.

The Windows and AlmaLinux section is the usual official setup. The Db2 section is the install that was actually run on this lab on 8 Sep 2026. Terminal blocks below are the saved lab output, pasted as plain text. There is no color in that output, and there are no screenshots. No passwords are included.

## 1. Install WSL on Windows

Use Windows 11 (or Windows 10 build 19041 or newer). Open PowerShell as Administrator.

If WSL is not installed yet:

```powershell
wsl --install --no-distribution
```

Restart Windows if it asks you to. Confirm the default is WSL 2:

```powershell
wsl --status
wsl --list --online
```

New installs from `wsl --install` use WSL 2. If an older distro is still on WSL 1:

```powershell
wsl --set-version <DistroName> 2
```

Official reference: [Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

## 2. Install AlmaLinux 9

AlmaLinux 9 is available from the WSL CLI (WSL 2.4.4 or newer) and from the Microsoft Store. From an Administrator PowerShell:

```powershell
wsl --install AlmaLinux-9
wsl -d AlmaLinux-9
```

The first launch asks you to create a Linux user. Give that user sudo. On this lab the account was `user1` (uid 1000) and sudo required a password.

Check the distro and version:

```powershell
wsl -l -v
wsl -d AlmaLinux-9 -- cat /etc/os-release
```

You want `AlmaLinux-9` on version 2. Official reference: [AlmaLinux WSL](https://wiki.almalinux.org/documentation/wsl).

## 3. Db2 media

Download the Linux x64 server archive for 11.5.9 from IBM (`v11.5.9_linuxx64_server_dec.tar.gz`). The copy used in this lab had SHA256:

```text
cb106df7840362fb9a344520ca9fb5d62357e49d357b077101b1f7f44f51062a
```

Inside AlmaLinux, stage it under a user-writable lab directory. This lab used `/ars/home/bin/db2-lab/v11.5.9`. `/ars` and `/ars/home` stayed `root:root`. `bin`, `db2-lab`, and `v11.5.9` were owned by the lab user.

```bash
sudo mkdir -p /ars/home/bin/db2-lab/v11.5.9
sudo chown "$USER:$USER" /ars/home/bin /ars/home/bin/db2-lab /ars/home/bin/db2-lab/v11.5.9
cp /mnt/c/Users/<you>/Downloads/v11.5.9_linuxx64_server_dec.tar.gz /ars/home/bin/db2-lab/v11.5.9/
cd /ars/home/bin/db2-lab/v11.5.9
sha256sum v11.5.9_linuxx64_server_dec.tar.gz
tar -xzf v11.5.9_linuxx64_server_dec.tar.gz
```

The installer is then at `/ars/home/bin/db2-lab/v11.5.9/server_dec/`.

## 4. Minimum prerequisites

Only these packages were installed. 32-bit (`.i686`) packages were left out on purpose.

```bash
sudo dnf install -y --setopt=install_weak_deps=False libaio numactl-libs ksh binutils
```

What landed on AlmaLinux 9:

- libaio-0.3.111-13.el9
- numactl-libs-2.0.19-3.el9
- ksh-1.0.6-15.el9
- binutils-2.35.2-72.el9
- plus binutils-gold, diffutils, and elfutils-debuginfod-client

## 5. Prerequisite check

An earlier run failed on ksh and libaio before those packages were installed. After the `dnf` install:

```bash
cd /ars/home/bin/db2-lab/v11.5.9/server_dec
./db2prereqcheck -i -v 11.5.9.0
```

```text
Checking prerequisites for DB2 installation. Version "11.5.9.0". Operating system "Linux"
Validating "kernel level " ... Required minimum "3.10.0". Actual "6.18.33.2". Requirement matched.
Validating "Linux distribution " ... Required RHEL 9 SP2. Actual Version 9 Service pack 8. Requirement matched.
Validating "ksh symbolic link" ... Requirement matched.
Validating "libaio.so version " ... Requirement matched.
Validating 32-bit libstdc++.so.6 ... DBT3514W failed to find 32-bit library (warning).
Validating 32-bit libpam ... DBT3514W failed to find "/lib/libpam.so*" (warning).
```

The full second run exited 0. Those two 32-bit lines are the only remaining warnings.

## 6. Install the product only

No instance, no samples, no PCMK. Run as root from `server_dec`:

```bash
sudo ./db2_install \
  -b /opt/ibm/db2/V11.5 \
  -p SERVER \
  -n \
  -y \
  -f NOTSAMP \
  -f NOPCMK \
  -l /ars/home/bin/db2-lab/v11.5.9/db2_install.log
```

Stdout:

```text
The execution completed successfully.

For more information see the DB2 installation log at
"/ars/home/bin/db2-lab/v11.5.9/db2_install.log".
```

Stderr (warnings only; the install still succeeded):

```text
Requirement not matched for DB2 database "Server" . Version: "11.5.9.0".
DBT3514W  The db2prereqcheck utility failed to find the following 32-bit library file: "/lib/libpam.so*".
DBT3514W  The db2prereqcheck utility failed to find the following 32-bit library file: "libstdc++.so.6".
Unit db2fmcd.service could not be found.
```

`db2ls`:

```text
Install Path                       Level   Fix Pack   Special Install Number   Install Date                  Installer UID
/opt/ibm/db2/V11.5               11.5.9.0        0                            Tue Sep  8 22:31:20 2026 IST             0
```

Tail of the install log:

```text
Installing DB2 file sets :.......Success
Executing control tasks :.......Success
Updating global registry :.......Success
Starting DB2 Fault Monitor :.......Success
Updating the db2ls and db2greg link :.......Success
Registering DB2 licenses :.......Success
Setting default global profile registry variables :.......Success
Initializing instance list :.......Success
Updating global profile registry :.......Success
Required steps:
Set up a DB2 instance to work with DB2.
```

## 7. Instance users

System ids used on this lab:

| Name | id | Home | Group |
| --- | --- | --- | --- |
| group db2iadm1 | 1001 | | |
| group db2fsdm1 | 1002 | | |
| user db2inst1 | 1001 | /home/db2inst1 | db2iadm1 |
| user db2fenc1 | 1002 | /home/db2fenc1 | db2fsdm1 |

```bash
sudo groupadd -g 1001 db2iadm1
sudo groupadd -g 1002 db2fsdm1
sudo useradd -u 1001 -g db2iadm1 -m -d /home/db2inst1 db2inst1
sudo useradd -u 1002 -g db2fsdm1 -m -d /home/db2fenc1 db2fenc1
```

Set a password for each user locally (`passwd` or `chpasswd`). Do not put passwords in git, scripts, or chat.

## 8. Create the instance

No DAS:

```bash
sudo /opt/ibm/db2/V11.5/instance/db2icrt -u db2fenc1 db2inst1
```

```text
DB2 installation is being initialized.
Total number of tasks to be performed: 4
Task #1 Setting default global profile registry variables ... end
Task #2 Initializing instance list ... end
Task #3 Configuring DB2 instances ... end
Task #4 Updating global profile registry ... end
The execution completed successfully.
For more information see the DB2 installation log at "/tmp/db2icrt.log.47840".
DBI1446I  The db2icrt command is running.
DBI1070I  Program db2icrt completed successfully.
```

`db2level`:

```text
DB21085I  This instance or install (instance name, where applicable:
"db2inst1") uses "64" bits and DB2 code release "SQL11059" with level
identifier "060A010F".
Informational tokens are "DB2 v11.5.9.0", "s2310270807", "DYN2310270807AMD64",
and Fix Pack "0".
Product is installed at "/opt/ibm/db2/V11.5".
```

Side effect on this lab: `db2fmcd.service` ended up enabled. There was no intentional instance autostart.

## 9. AlmaLinux 9 library fix (required before db2start)

The first `db2start` failed because the AWS SDK libraries were not on the library path. Setting `LD_LIBRARY_PATH` in the session printed the same error. `db2start` is setuid/setgid, and `db2profile` clears `LD_LIBRARY_PATH`.

```text
db2start: error while loading shared libraries: libaws-cpp-sdk-transfer.so: cannot open shared object file: No such file or directory
```

`/home/db2inst1/sqllib/lib64` is a symlink to `/opt/ibm/db2/V11.5/lib64`, which is on the binary RUNPATH. As root, link the four AWS SDK libraries from the RHEL 9.2 build into that directory:

```bash
cd /opt/ibm/db2/V11.5/lib64
for lib in \
  libaws-cpp-sdk-transfer.so \
  libaws-cpp-sdk-s3.so \
  libaws-cpp-sdk-core.so \
  libaws-cpp-sdk-kinesis.so
do
  sudo ln -s "awssdk/RHEL/9.2/$lib" "$lib"
done
```

After the four symlinks, `ldd` resolved them through the instance lib64:

```text
libaws-cpp-sdk-transfer.so => /home/db2inst1/sqllib/lib64/libaws-cpp-sdk-transfer.so
libaws-cpp-sdk-s3.so => /home/db2inst1/sqllib/lib64/libaws-cpp-sdk-s3.so
libaws-cpp-sdk-core.so => /home/db2inst1/sqllib/lib64/libaws-cpp-sdk-core.so
libaws-cpp-sdk-kinesis.so => /home/db2inst1/sqllib/lib64/libaws-cpp-sdk-kinesis.so
```

## 10. Start the instance

As `db2inst1`:

```bash
sudo su - db2inst1
db2start
```

```text
09/08/2026 23:12:15     0   0   SQL1063N  DB2START processing was successful.
SQL1063N  DB2START processing was successful.
```

```text
The current database manager instance is:  db2inst1
```

## 11. Validate

`db2val -o -a` is not valid on Linux. `-o` ignores `-i`, `-a`, `-b`, and `-s`.

```text
DBI1329I  Usage:
 db2val [-h|-?]
        [-o]
        [-i inst_name1] | [-a]
... -o ignores -i, -a, -b, and -s.
```

As `db2inst1`, `db2val -o`:

```text
DBI1379I  The db2val command is running. This can take several minutes.
DBI1335I  Installation file validation for the DB2 copy installed at
      /opt/ibm/db2/V11.5 was successful.
DBI1343I  The db2val command completed successfully. For details, see
      the log file /tmp/db2val-260908_231614.log.
```

As root, `db2val -i db2inst1`:

```text
DBI1379I  The db2val command is running. This can take several minutes.
DBI1335I  Installation file validation for the DB2 copy installed at
      /opt/ibm/db2/V11.5 was successful.
DBI1339I  The instance validation for the instance db2inst1 was
      successful.
DBI1343I  The db2val command completed successfully. For details, see
      the log file /tmp/db2val-260908_231831.log.
```

## 12. Smoke-test database

Still as `db2inst1`. This lab left the instance running and did not run `db2stop`. `LABDB` was created under `/home/db2inst1`. The saved run:

```text
===CREATE===
DB20000I  The CREATE DATABASE command completed successfully.
===LIST===
 System Database Directory
 Number of entries in the directory = 1
Database 1 entry:
 Database alias                       = LABDB
 Database name                        = LABDB
 Local database directory             = /home/db2inst1
 Database release level               = 15.00
 Directory entry type                 = Indirect
 Catalog database partition number    = 0
===CONNECT===
 Database server        = DB2/LINUXX8664 11.5.9.0
 SQL authorization ID   = DB2INST1
 Local database alias   = LABDB
===SQL===
DB20000I  The SQL command completed successfully.
DB20000I  The SQL command completed successfully.
ID          NOTE
----------- ----------------------------------------------------------------
          1 hello lab
  1 record(s) selected.
===RESET===
DB20000I  The SQL command completed successfully.
STEP_D_OK
```

## Not part of this lab

- DAS
- a systemd unit or autostart for the instance
- extra database manager configuration
- extra users
- 32-bit pam
- `db2stop`
