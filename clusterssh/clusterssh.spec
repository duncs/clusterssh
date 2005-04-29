Name: clusterssh
Version: 3.4
Release: 3
Summary: Secure concurrent multi-server terminal control

Group: Applications/Productivity
License: GPL
URL: http://clusterssh.sourceforge.net
Source0: %{name}-%{version}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

%description
Control multiple terminals open on different servers to perform administration
tasks.

%prep
%setup -q

%build
%configure
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%{_bindir}/cssh
%{_mandir}/man1/cssh.1.gz

%doc COPYING AUTHORS README NEWS ChangeLog

%changelog

* Mon Apr 25 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.0-4
- Created initial spec file for building the RPM

#
# $Id$
#
