# Copyright 2022-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Scripts for btrfs maintenance tasks like periodic scrub, balance, trim or defrag"
HOMEPAGE="https://github.com/kdave/btrfsmaintenance"
SRC_URI="https://github.com/kdave/btrfsmaintenance/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 ~arm arm64 ~ppc ~ppc64 x86"
IUSE="systemd"

RDEPEND="
	app-shells/bash
	sys-apps/util-linux
	sys-fs/btrfs-progs
	systemd? ( sys-apps/systemd )
	!systemd? ( virtual/cron )
"

src_prepare() {
	# Fix config path into watching service
	sed -i 's%/etc/sysconfig/btrfsmaintenance%/etc/default/btrfsmaintenance%g' btrfsmaintenance-refresh.* ||
		die "Unable to patch btrfsmaintenance-refresh.*"
	rm btrfs-defrag-plugin.sh || die "cannot remove btrfs-defrag-plugin.sh" # not necessary on gentoo systems
	default
}

src_install() {
	dodoc README.md CONTRIBUTING.md CHANGES.md
	insinto /etc/default
	newins sysconfig.btrfsmaintenance btrfsmaintenance
	insinto /usr/share/btrfsmaintenance
	doins btrfsmaintenance-functions
	exeinto /usr/share/btrfsmaintenance
	doexe btrfs*.sh
	systemd_dounit *.service *.timer *.path
}

pkg_postinst() {
	elog "Installing default btrfsmaintenance scripts"
	if use systemd; then
		"${EROOT}"/usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh systemd-timer || die
	else
		"${EROOT}"/usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh || die
	fi
	elog "Now edit cron periods and mount points in /etc/default/btrfsmaintenance "
	elog "then run /usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh to"
	elog "update cron symlinks or run"
	elog "/usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh systemd-timer"
	elog "to update systemd timers."
	elog "You can also enable btrfsmaintenance-refresh.path service in order to"
	elog "monitor the config files changes and update systemd timers accordly."
}

pkg_prerm() {
	if [[ -z ${REPLACED_BY_VERSION} ]] ; then
		elog "Removing symlinks from btrfsmaintenance cron tasks"
		"${EROOT}"/usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh uninstall || die
	fi
}
