# Copyright (C) (2001-2005) (Duncan Ferguson) <duncan_ferguson@users.sf.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
bin_SCRIPTS = cssh
man1_MANS = cssh.1
CLEANFILES = $(bin_SCRIPTS) $(man1_MANS)
EXTRA_DIST = cssh.pl

cssh: $(srcdir)/cssh.pl
	rm -f cssh
	echo "#!"$(PERL) > cssh
	cat $(srcdir)/cssh.pl >> cssh
	chmod ugo+x cssh

cssh.1: $(srcdir)/cssh.pl
	rm -f cssh.1
	pod2man $(srcdir)/cssh.pl > cssh.1
	chmod 444 cssh.1

#
# $Id$
#
