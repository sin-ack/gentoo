# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: postgres.eclass
# @MAINTAINER:
# PostgreSQL <pgsql-bugs@gentoo.org>
# @AUTHOR:
# Aaron W. Swenson <titanofold@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: An eclass for PostgreSQL-related packages
# @DESCRIPTION:
# This eclass provides common utility functions that many
# PostgreSQL-related packages perform, such as checking that the
# currently selected PostgreSQL slot is within a range, adding a system
# user to the postgres system group, and generating dependencies.

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_POSTGRES_ECLASS} ]]; then
_POSTGRES_ECLASS=1

# @ECLASS_VARIABLE: _POSTGRES_ALL_VERSIONS
# @INTERNAL
# @DESCRIPTION:
# List of versions to reverse sort POSTGRES_COMPAT slots

_POSTGRES_ALL_VERSIONS=( 9999 17 16 15 14 13 )



# @ECLASS_VARIABLE: POSTGRES_COMPAT
# @PRE_INHERIT
# @DEFAULT_UNSET
# @DESCRIPTION:
# A Bash array containing a list of compatible PostgreSQL slots as
# defined by the developer. If declared, must be declared before
# inheriting this eclass. Example:
#@CODE
#POSTGRES_COMPAT=( 9.2 9.3 9.4 9.5 9.6 10 )
#POSTGRES_COMPAT=( 9.{2,3} 9.{4..6} 10 ) # Same as previous
#@CODE

# @ECLASS_VARIABLE: POSTGRES_DEP
# @DESCRIPTION:
# An automatically generated dependency string suitable for use in
# DEPEND and RDEPEND declarations.
POSTGRES_DEP="dev-db/postgresql:="

# @ECLASS_VARIABLE: POSTGRES_USEDEP
# @PRE_INHERIT
# @DEFAULT_UNSET
# @DESCRIPTION:
# Add the 2-Style and/or 4-Style use dependencies without brackets to be used
# for POSTGRES_DEP. If declared, must be declared before inheriting this eclass.
declare -p POSTGRES_USEDEP &>/dev/null && POSTGRES_DEP+="[${POSTGRES_USEDEP}]"

# @ECLASS_VARIABLE: POSTGRES_REQ_USE
# @DEFAULT_UNSET
# @DESCRIPTION:
# An automatically generated REQUIRED_USE-compatible string built upon
# POSTGRES_COMPAT. REQUIRED_USE="... ${POSTGRES_REQ_USE}" is only
# required if the package must build against one of the PostgreSQL slots
# declared in POSTGRES_COMPAT.

# @ECLASS_VARIABLE: PG_SLOT
# @DEFAULT_UNSET
# @DESCRIPTION:
# PG_SLOT is the chosen PostgreSQL slot that is used for the build.

# @ECLASS_VARIABLE: PG_CONFIG
# @DEFAULT_UNSET
# @DESCRIPTION:
# PG_CONFIG is the path to pg_config for the chosen PostgreSQL slot.
# For example, PG_CONFIG="pg_config15"

# @ECLASS_VARIABLE: _POSTGRES_COMPAT
# @INTERNAL
# @DESCRIPTION:
# Copy of POSTGRES_COMPAT, reverse sorted
_POSTGRES_COMPAT=()


if declare -p POSTGRES_COMPAT &> /dev/null ; then
	# Reverse sort the given POSTGRES_COMPAT so that the most recent
	# slot is preferred over an older slot.
	# -- do we care if dependencies are deterministic by USE flags?
	for i in ${_POSTGRES_ALL_VERSIONS[@]} ; do
		has ${i} ${POSTGRES_COMPAT[@]} && _POSTGRES_COMPAT+=( ${i} )
	done

	POSTGRES_DEP=""
	POSTGRES_REQ_USE=" || ("
	for slot in "${_POSTGRES_COMPAT[@]}" ; do
		POSTGRES_DEP+=" postgres_targets_postgres${slot/\./_}? ( dev-db/postgresql:${slot}="
		declare -p POSTGRES_USEDEP &>/dev/null && \
			POSTGRES_DEP+="[${POSTGRES_USEDEP}]"
		POSTGRES_DEP+=" )"

		IUSE+=" postgres_targets_postgres${slot/\./_}"
		POSTGRES_REQ_USE+=" postgres_targets_postgres${slot/\./_}"
	done
	POSTGRES_REQ_USE+=" )"
fi


# @FUNCTION: postgres_check_slot
# @DESCRIPTION:
# Verify that the currently selected PostgreSQL slot is set to one of
# the slots defined in POSTGRES_COMPAT. Automatically dies unless a
# POSTGRES_COMPAT slot is selected. Should be called in pkg_pretend().
postgres_check_slot() {
	if ! declare -p POSTGRES_COMPAT &>/dev/null; then
		die 'POSTGRES_COMPAT not declared.'
	fi

	# Don't die because we can't run postgresql-config during pretend.
	[[ "$EBUILD_PHASE" = "pretend" && -z "$(type -P postgresql-config 2> /dev/null)" ]] \
		&& return 0

	if has $(postgresql-config show 2> /dev/null) "${POSTGRES_COMPAT[@]}"; then
		return 0
	else
		eerror "PostgreSQL slot must be set to one of: "
		eerror "    ${POSTGRES_COMPAT[@]}"
		die "Incompatible PostgreSQL slot eselected"
	fi
}

# @FUNCTION: postgres_pkg_setup
# @DESCRIPTION:
# Initialize environment variable(s) according to the best
# installed version of PostgreSQL that is also in POSTGRES_COMPAT. This
# is required if pkg_setup() is declared in the ebuild.
# Exports PG_SLOT, PG_CONFIG, and PKG_CONFIG_PATH.
postgres_pkg_setup() {
	debug-print-function ${FUNCNAME} "$@"

	local compat_slot
	local best_slot
	for compat_slot in "${_POSTGRES_COMPAT[@]}"; do
		if use "postgres_targets_postgres${compat_slot/\./_}"; then
			best_slot="${compat_slot}"
			break
		fi
	done

	if [[ -z "${best_slot}" ]]; then
		local flags f
		for f in "${_POSTGRES_COMPAT[@]}"; do
			flags+=" postgres${f/./_}"
		done

		eerror "POSTGRES_TARGETS must contain at least one of:"
		eerror "    ${flags}"
		die "No suitable POSTGRES_TARGETS enabled."
	fi

	export PG_SLOT=${best_slot}
	export PG_CONFIG=$(type -P pg_config${best_slot//./})

	if [[ -z ${PG_CONFIG} ]] ; then
		die "Could not find pg_config for ${PG_SLOT}. Is dev-db/postgresql:${PG_SLOT} installed?"
	fi

	local pg_pkg_config_path="$(${PG_CONFIG} --libdir)/pkgconfig"
	if [[ -n "${PKG_CONFIG_PATH}" ]]; then
		export PKG_CONFIG_PATH="${pg_pkg_config_path}:${PKG_CONFIG_PATH}"
	else
		export PKG_CONFIG_PATH="${pg_pkg_config_path}"
	fi

	elog "PostgreSQL Target: ${best_slot}"
}

fi

EXPORT_FUNCTIONS pkg_setup
