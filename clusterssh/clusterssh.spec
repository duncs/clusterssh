Name:          clusterssh
Version:       3.18.1
Release:       1%{?dist}
Summary:       Secure concurrent multi-server terminal control

Group:         Applications/Productivity
License:       GPL
URL:           http://clusterssh.sourceforge.net
Source0:       http://download.sourceforge.net/%{name}/%{name}-%{version}.tar.gz
BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:     noarch
Requires:      perl-Tk perl-X11-Protocol

%description
Control multiple terminals open on different servers to perform administration
tasks, for example multiple hosts requiring the same config within a cluster.
Not limited to use with clusters, however.

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
%defattr(-,root,root,-)
%doc COPYING AUTHORS README NEWS ChangeLog
%{_bindir}/cssh
%{_mandir}/man1/*.1*

%changelog

* Mon Nov 28 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.18.1-1
- Updates and bugfixes to cssh
- Updates to man page
- Re-engineer spec file

* Tue Aug 30 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.17.1-2
- spec file tidyups

* Mon Apr 25 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.0
- Please see ChangeLog in documentation area

