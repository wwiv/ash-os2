#! /bin/sh
#	$NetBSD: mknodes.sh,v 1.1 2004/01/16 23:24:38 dsl Exp $

# Copyright (c) 2003 The NetBSD Foundation, Inc.
# All rights reserved.
#
# This code is derived from software contributed to The NetBSD Foundation
# by David Laight.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The NetBSD Foundation nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

nodetypes=$1
nodes_pat=$2
objdir="$3"

exec <$nodetypes
exec >$objdir/nodes.h.tmp

echo "/*"
echo " * This file was generated by mknodes.sh"
echo " */"
echo

tagno=0
while IFS=; read -r line; do
	line="${line%%#*}"
	IFS=' 	'
	set -- $line
	IFS=
	[ -z "$2" ] && continue
	case "$line" in
	[" 	"]* )
		IFS=' '
		[ $field = 0 ] && struct_list="$struct_list $struct"
		eval field_${struct}_$field=\"\$*\"
		eval numfld_$struct=\$field
		field=$(($field + 1))
		;;
	* )
		define=$1
		struct=$2
		echo "#define $define $tagno"
		tagno=$(($tagno + 1))
		eval define_$struct=\"\$define_$struct \$define\"
		struct_define="$struct_define $struct"
		field=0
		;;
	esac
done

echo

IFS=' '
for struct in $struct_list; do
	echo
	echo
	echo "struct $struct {"
	field=0
	while
		eval line=\"\$field_${struct}_$field\"
		field=$(($field + 1))
		[ -n "$line" ]
	do
		IFS=' '
		set -- $line
		name=$1
		case $2 in
		nodeptr ) type="union node *";;
		nodelist ) type="struct nodelist *";;
		string ) type="char *";;
		int ) type="int ";;
		* ) name=; shift 2; type="$*";;
		esac
		echo "      $type$name;"
	done
	echo "};"
done

echo
echo
echo "union node {"
echo "      int type;"
for struct in $struct_list; do
	echo "      struct $struct $struct;"
done
echo "};"
echo
echo
echo "struct nodelist {"
echo "	struct nodelist *next;"
echo "	union node *n;"
echo "};"
echo
echo
echo "union node *copyfunc(union node *);"
echo "void freefunc(union node *);"

exec <$nodes_pat
exec >$objdir/nodes.c.tmp
mv -f $objdir/nodes.h.tmp $objdir/nodes.h || exit 1

echo "/*"
echo " * This file was generated by mknodes.sh"
echo " */"
echo

while IFS=; read -r line; do
	IFS=' 	'
	set -- $line
	IFS=
	case "$1" in
	'%SIZES' )
		echo "static const short nodesize[$tagno] = {"
		IFS=' '
		for struct in $struct_define; do
			echo "      SHELL_ALIGN(sizeof (struct $struct)),"
		done
		echo "};"
		;;
	'%CALCSIZE' )
		echo "      if (n == NULL)"
		echo "	    return;"
		echo "      funcblocksize += nodesize[n->type];"
		echo "      switch (n->type) {"
		IFS=' '
		for struct in $struct_list; do
			eval defines=\"\$define_$struct\"
			for define in $defines; do
				echo "      case $define:"
			done
			eval field=\$numfld_$struct
			while
				[ $field != 0 ]
			do
				eval line=\"\$field_${struct}_$field\"
				field=$(($field - 1))
				IFS=' '
				set -- $line
				name=$1
				cl=")"
				case $2 in
				nodeptr ) fn=calcsize;;
				nodelist ) fn=sizenodelist;;
				string ) fn="funcstringsize += strlen"
					cl=") + 1";;
				* ) continue;;
				esac
				echo "	    ${fn}(n->$struct.$name${cl};"
			done
			echo "	    break;"
		done
		echo "      };"
		;;
	'%COPY' )
		echo "      if (n == NULL)"
		echo "	    return NULL;"
		echo "      new = funcblock;"
		echo "      funcblock = (char *) funcblock + nodesize[n->type];"
		echo "      switch (n->type) {"
		IFS=' '
		for struct in $struct_list; do
			eval defines=\"\$define_$struct\"
			for define in $defines; do
				echo "      case $define:"
			done
			eval field=\$numfld_$struct
			while
				[ $field != 0 ]
			do
				eval line=\"\$field_${struct}_$field\"
				field=$(($field - 1))
				IFS=' '
				set -- $line
				name=$1
				case $2 in
				nodeptr ) fn="copynode(";;
				nodelist ) fn="copynodelist(";;
				string ) fn="nodesavestr(";;
				int ) fn=;;
				* ) continue;;
				esac
				f="$struct.$name"
				echo "	    new->$f = ${fn}n->$f${fn:+)};"
			done
			echo "	    break;"
		done
		echo "      };"
		echo "      new->type = n->type;"
		;;
	* ) echo "$line";;
	esac
done

exec >/dev/null
mv -f $objdir/nodes.c.tmp $objdir/nodes.c || exit 1
