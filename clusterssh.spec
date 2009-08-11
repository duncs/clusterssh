Name:          clusterssh
Version:       3.26
Release:       1%{?dist}
Summary:       Secure concurrent multi-server terminal control

Group:         Applications/Productivity
License:       GPL
URL:           http://clusterssh.sourceforge.net
Source0:       http://easynews.dl.sourceforge.net/sourceforge/%{name}/%{name}-%{version}.tar.gz
BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:     noarch
BuildRequires: desktop-file-utils

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
mkdir -p %{buildroot}%{_datadir}/applications
desktop-file-install --vendor fedora                            \
        --dir ${RPM_BUILD_ROOT}%{_datadir}/applications         \
        --add-category X-Fedora                                 \
        %{name}.desktop
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/48x48/apps/
install -p -m 644 %{name}-48x48.png \
        %{buildroot}%{_datadir}/icons/hicolor/48x48/apps/%{name}.png
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/32x32/apps/
install -p -m 644 %{name}-32x32.png \
        %{buildroot}%{_datadir}/icons/hicolor/32x32/apps/%{name}.png
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/24x24/apps/
install -p -m 644 %{name}-24x24.png \
        %{buildroot}%{_datadir}/icons/hicolor/24x24/apps/%{name}.png

%post
touch --no-create %{_datadir}/icons/hicolor || :
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
   %{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :
fi

%postun
touch --no-create %{_datadir}/icons/hicolor || :
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
   %{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :
fi

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc COPYING AUTHORS README NEWS THANKS ChangeLog
%{_bindir}/cssh
%{_mandir}/man1/*.1*
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/applications/fedora-%{name}.desktop

%changelog

* Wed Jan 23 2008 Duncan Ferguson  <duncan_ferguson@users.sf.net> - 3.22-1
- Updates and fixed - see ChangeLog

* Wed Nov 28 2007 Duncan Ferguson  <duncan_ferguson@users.sf.net> - 3.21-1
- See ChangeLog

* Mon Nov 26 2007 Duncan Ferguson  <duncan_ferguson@users.sf.net> - 3.20-1
- Updates and fixes - see ChangeLog

* Tue Aug 15 2006 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.19.1-2
- Tidyups as per https://bugzilla.redhat.com/bugzilla/show_bug.cgi?id=199173

* Mon Jul 24 2006 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.19.1-1
- Update Changelog, commit all branch changes and release

* Tue Jul 18 2006 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.18.2.10-2
- Correct download URL (Source0)

* Mon Jul 17 2006 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.18.2.10-1
- Lots of amendments and fixes to clusterssh code
- Added icons and desktop file
- Submitted to Fedora Extras for review

* Mon Nov 28 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.18.1-1
- Updates and bugfixes to cssh
- Updates to man page
- Re-engineer spec file

* Tue Aug 30 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.17.1-2
- spec file tidyups

* Mon Apr 25 2005 Duncan Ferguson <duncan_ferguson@users.sf.net> - 3.0
- Please see ChangeLog in documentation area

