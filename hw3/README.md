# zfs (connect with SA hw3)

## Step 1: Add three 1GB disks

* Power off your FreeBSD VM if it's currently running.
* In the VMware interface, right-click the FreeBSD VM and select "Settings".
* In the Hardware tab, click "Add" to start the Add Hardware wizard.
* Select "Hard Disk" and click "Next".
* Choose the type of virtual disk (SCSI is typically fine), and click "Next".
* Specify the disk capacity as 1GB and click "Next".
* Review your settings and click "Finish" to add the disk.
* Repeat these steps two more times to add a total of three 1GB disks to your VM.

## Part 2: ZFS Configuration

Create a ZFS RAID-Z pool named sa_pool with your three 1GB disks as devices. Replace sdX, sdY, sdZ with your disk identifiers:

```bash
geom disk list #use this command to check your disk name first
```

```bash
sudo zpool create sa_pool raidz /dev/sdX /dev/sdY /dev/sdZ #please modify the disk name
```

Create a new filesystem called data in pool sa_pool and set the properties:

```bash
sudo zfs create sa_pool/data
sudo zfs set compression=lz4 sa_pool/data
sudo zfs set copies=2 sa_pool/data
sudo zfs set atime=off sa_pool/data
sudo zfs set mountpoint=/sa_data sa_pool/data
Set /sa_data permissions and ownership:
bash
Copy code
sudo chmod 755 /sa_data
sudo chown root:wheel /sa_data
```

### score check session (40/100)

```bash
sudo zpool list -Ho name #contain sa_pool

sudo zfs get -o value mountpoint sa_pool/data | tail -1 #return /sa_data

sudo zfs get -o value compression sa_pool/data | tail -1 # return lz4

sudo zfs get -o value copies sa_pool/data | tail -1 #return 2

sudo zfs get -o value atime sa_pool/data | tail -1 ##return off

ls -l / | grep sa_data | cut -d ' ' -f 1 #return drwxr-xr-x

ls -l / | grep sa_data | cut -d ' ' -f 5,7 # #return root wheel
```

## Part 3: Logrotate

Create a logrotate configuration file:

Open a terminal or SSH into your FreeBSD system.
Use a text editor (e.g., nano, vi) to create the logrotate configuration file:

```bash
sudo mkdir -p /etc/logrotate.d
sudo vim /etc/logrotate.d/fakelog
```

In the editor, add the following configuration:

```bash
/var/log/fakelog.log {
    rotate 10
    size 1k
    copytruncate
    missingok
    notifempty
    create
    create 0644 root wheel
    olddir /var/log/fakelog/
}
```

Save the file and exit the editor.

```bash
sudo mkdir -p /var/log/fakelog
sudo logrotate -v --debug /etc/logrotate.d/fakelog
```

### score check session (75/100)

```bash
sudo rm -rf /sa_data/log/* /var/log/fakelog.log.*  /var/log/fakelog/*

curl -o fakeloggen.py https://gist.githubusercontent.com/Vincent550102/fbc8a56bc0f6c28624ce1e7b3b8a8c80/raw/c1f0eec843e1121f99400c6adbae7cc5ddfe50d2/fakeloggen.py

sudo python3 fakeloggen.py 55 --logrotate

ls -l /var/log/fakelog/ | sed '1d' | wc -l # return 10

ls -lh /var/log/fakelog/ | tail -10 | awk '{print $5}' | sed "s/K//" | awk '{if ($1 >= 1 && $1 <=1.5) print "Number is in range"; else print "Number is not in range"}' # all is Number is in range
```

## Part 4: ZFS Managing tools

```bash
sudo vim /usr/local/bin/sabktool
```

then paste in

```python
#!/usr/bin/env python3

import subprocess
import sys
import os
import shutil

def create_snapshot(name):
    cmd = ['sudo', 'zfs', 'snapshot', f'sa_pool/data@{name}']
    subprocess.run(cmd)

def remove_snapshot(name):
    if name == 'all':
        cmd = ['sudo', 'zfs', 'list', '-t', 'snapshot', '-o', 'name']
        snapshots = subprocess.run(cmd, capture_output=True, text=True).stdout.split('\n')
        for snapshot in snapshots:
            if 'sa_pool/data' in snapshot:
                cmd = ['sudo', 'zfs', 'destroy', snapshot]
                subprocess.run(cmd)
    else:
        cmd = ['sudo', 'zfs', 'destroy', f'sa_pool/data@{name}']
        subprocess.run(cmd)

def list_snapshots():
    cmd = ['sudo', 'zfs', 'list', '-t', 'snapshot', '-o', 'name']
    snapshots = subprocess.run(cmd, capture_output=True, text=True).stdout.split('\n')
    for snapshot in snapshots:
        if 'sa_pool/data' in snapshot:
            print(snapshot)

def rollback_snapshot(name):
    cmd = ['sudo', 'zfs', 'rollback', '-r', f'sa_pool/data@{name}']
    subprocess.run(cmd)

def logrotate():
    if not os.path.exists('/sa_data/log/'):
        mkdir_cmd = ['sudo', 'mkdir', '-p', '/sa_data/log']
        subprocess.run(mkdir_cmd)
    #shutil.copy2('/var/log/fakelog.log', '/sa_data/log/')
    cmd = ['sudo', 'cp', '/var/log/fakelog.log', '/sa_data/log/']
    subprocess.run(cmd)
    cmd = ['sudo', 'logrotate', '/etc/logrotate.d/fakelog']
    subprocess.run(cmd)

def clean_logs():
    shutil.rmtree('/sa_data/log/', ignore_errors=True)
    for file in os.listdir('/var/log/'):
        if 'fakelog.log' in file:
            os.remove(os.path.join('/var/log/', file))

def print_help():
    help_message = """
    Usage:
    sabktool create <snapshot-name>
    sabktool remove <snapshot-name> | all
    sabktool list
    sabktool roll <snapshot-name>
    sabktool logrotate
    """
    print(help_message)

def main():
    if len(sys.argv) < 2:
        print_help()
        return

    command = sys.argv[1]

    if command == 'create':
        if len(sys.argv) < 3:
            print('Error: snapshot name required')
            return
        create_snapshot(sys.argv[2])

    elif command == 'remove':
        if len(sys.argv) < 3:
            print('Error: snapshot name required')
            return
        remove_snapshot(sys.argv[2])

    elif command == 'list':
        list_snapshots()

    elif command == 'roll':
        if len(sys.argv) < 3:
            print('Error: snapshot name required')
            return
        rollback_snapshot(sys.argv[2])

    elif command == 'logrotate':
        logrotate()

    elif command == 'clean':
        clean_logs()

    else:
        print_help()

if __name__ == '__main__':
    main()
```
