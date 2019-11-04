#!/bin/bash
set -e

# Crush into a minimal production image to be deployed via some type of image
# updating system.
# IMPORTANT: The Debian system is not longer functional at this point,
# for example, apt and dpkg will stop working


filesystem()  {
   UNNEEDED_PACKAGES="libfdisk1 cpio hostname gzip "

   remove_packages "${UNNEEDED_PACKAGES}"

   # Partition and file system tools
   rm -f usr/sbin/*fdisk
   rm -f usr/sbin/mkfs*
   rm -f usr/sbin/fsck*

   # No need for fuse
   find usr etc -name '*fuse*' -prune -exec rm -r {} \;

   rm -f usr/bin/hostnamectl
}

package_management()  {
   UNNEEDED_PACKAGES="apt libapt-pkg5.0 debconf libdebconfclient0 debian-archive-keyring "

   remove_packages "${UNNEEDED_PACKAGES}"

   # Show what's left package-wise before dropping dpkg itself
   COLUMNS=300 dpkg -l

   # Drop dpkg
   dpkg --purge --force-remove-essential --force-depends  dpkg

   # No apt or dpkg, no need for its configuration archives
   rm -rf etc/apt
   rm -rf etc/dpkg
}

systemd()  {
   # Unused systemd generators
   rm -f lib/systemd/system-generators/systemd-cryptsetup-generator
   rm -f lib/systemd/system-generators/systemd-debug-generator
   rm -f lib/systemd/system-generators/systemd-gpt-auto-generator
   rm -f lib/systemd/system-generators/systemd-hibernate-resume-generator
   rm -f lib/systemd/system-generators/systemd-rc-local-generator
   rm -f lib/systemd/system-generators/systemd-system-update-generator
   rm -f lib/systemd/system-generators/systemd-sysv-generator

   # Efi blobs
   rm -rf usr/lib/systemd/boot

   # Translation catalogs
   rm -rf usr/lib/systemd/catalog

   # Misc systemd utils
   rm -f usr/bin/bootctl
   rm -f usr/bin/busctl
   rm -f usr/bin/localectl
   rm -f usr/bin/systemd-cat
   rm -f usr/bin/systemd-cgls
   rm -f usr/bin/systemd-cgtop
   rm -f usr/bin/systemd-delta
   rm -f usr/bin/systemd-detect-virt
   rm -f usr/bin/systemd-mount
   rm -f usr/bin/systemd-path
   rm -f usr/bin/systemd-run
   rm -f usr/bin/systemd-socket-activate

   # Systemd dns resolver
   #find usr etc -name '*systemd-resolve*' -prune -exec rm -r {} \;

   # Systemd network configuration
   #find usr etc -name '*networkd*' -prune -exec rm -r {} \;

   # systemd ntp client (connman is in use)
   #find usr etc -name '*timesyncd*' -prune -exec rm -r {} \;

   # systemd hw database manager (connman is in use)
   find usr etc -name '*systemd-hwdb*' -prune -exec rm -r {} \;
}

ncurses()  {
   UNNEEDED_PACKAGES="ncurses-bin ncurses-base libncursesw5 libncurses5 "
   remove_packages "${UNNEEDED_PACKAGES}"

   # Utils using ncurses
   rm -f usr/bin/pg
   rm -f usr/bin/watch
   rm -f usr/bin/slabtop
}


misc_packages()  {
   UNNEEDED_PACKAGES="perl-base insserv init-system-helpers adduser passwd libsemanage1 libsemanage-common libsepol1 gnupg gpgv "
   remove_packages "${UNNEEDED_PACKAGES}"
}


misc_directories()  {
    # Drop directories not part of ostree
    # Note that /var needs to exist as ostree bind mounts the deployment /var over
    # it
    rm -rf var/* srv share

    # ca-certificates are in /etc drop the source
    rm -rf usr/share/ca-certificates

    # No bash, no need for completions
    rm -rf usr/share/bash-completion

    # No zsh, no need for comletions
    rm -rf usr/share/zsh/vendor-completions

    # drop gcc-6 python helpers
    rm -rf usr/share/gcc-6

    # Drop sysvinit leftovers
    rm -rf etc/init.d
    rm -rf etc/rc[0-6S].d

    # Drop upstart helpers
    rm -rf etc/init

    # Various xtables helpers
    rm -rf usr/lib/xtables

    # Drop all locales
    # TODO: only remaining locale is actually "C". Should we really remove it?
    rm -rf usr/lib/locale/*

    # local compiler
    rm -f usr/bin/localedef

    # lsb init function leftovers
    rm -rf usr/lib/lsb

    # boot analyser
    rm -f usr/bin/systemd-analyze

    # Only needed when adding libraries
    rm -f usr/sbin/ldconfig*

    # Games, unused
    rm -rf usr/games

    # Remove pam module to authenticate against a DB
    # plus libdb-5.3.so that is only used by this pam module
    rm -f usr/lib/*/security/pam_userdb.so
    rm -f usr/lib/*/libdb-5.3.so

    # remove NSS support for nis, nisplus and hesiod
    rm -f usr/lib/*/libnss_hesiod*
    rm -f usr/lib/*/libnss_nis*
}

# Removing unneeded packages
remove_packages()  {
   UNNEEDED_PACKAGES="$@"

   for PACKAGE in ${UNNEEDED_PACKAGES}
   do
	echo "Forcing removal of ${PACKAGE}"
	if ! dpkg --purge --force-remove-essential --force-depends "${PACKAGE}"
	then
		echo "WARNING: ${PACKAGE} isn't installed"
	fi
   done
}

# Either skip specific components or crush all
while getopts ":s:" opt; do
  case $opt in
    s)
      IFS=','
      array=($OPTARG)
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: crush.sh [-s <component1>[,<component2>]]"
      echo "Available components: filesystem package_management systemd ncurses misc_packages misc_directories"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

components=(filesystem package_management systemd ncurses misc_packages misc_directories)

# Before crushing image, ignore components based on input, if required.
for i in "${array[@]}"; do
   components=("${components[@]/$i}")
done

for j in "${components[@]}"; do
   ${j}
done
