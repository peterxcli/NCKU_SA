# freebsd setup

> run following command by order

## in root

----------------------

### install sudo

```shell
pkg install sudo
```

### add user

```shell
adduser
```

then set the user config

### add user to wheel

run

```shell
visudo
```

add user privilege

```diff
...

##
## User privilege specification
##
root ALL=(ALL:ALL) ALL
## Uncomment to allow members of group wheel to execute any command
- # %wheel ALL=(ALL:ALL) ALL
+ %wheel ALL=(ALL:ALL) ALL

## Same thing without a password
- # %wheel ALL=(ALL:ALL) NOPASSWD: ALL
+ %wheel ALL=(ALL:ALL) NOPASSWD: ALL

## Uncomment to allow members of group sudo to execute any command
# %sudo ALL=(ALL:ALL) ALL

## Uncomment to allow any user to run sudo if they know the password

...
```

and add user to group
`$ pw groupmod wheel -m <username>`

## Appendix

* Update your system to latest patch (login as root
  * `$ freebsd-update fetch install`

* lookup freebsd vserion and patch
  * `$ freebsd-version`

* wireguard
  * vpn config under the `/usr/local/etc/wireguard/` dir
    * ex: `/usr/local/etc/wireguard/vpn.conf`
  * then run `$ wg-quick up <username>`

* ssh hack
  * `$ fping -g 192.168.1.0/24`
  * `$ nmap -n -sP 10.0.0.0/24`
  * `$ hydra -l judge -P pass.txt -t 6 ssh://10.187.96.59:22`
* ssh log
  * `sudo grep 'sshd' /var/log/auth.log`

* expand vmdk disk amount
  * after you expand the disk size in vm manager(vmware, virtualbox)
  *
