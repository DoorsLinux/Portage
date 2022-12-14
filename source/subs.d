module source.subs;

import std.stdio;
import std.net.curl;
import std.process;
import std.file;
import std.string;
import std.path;

int print_usage(bool err = false) {
  writeln("
usage: portage <command> <package>

PORTAGE is a meson-based package manager
written and used by DoorsOS, but can be configured for other OSes too.

Commands:
  install      Install a package.
  ask          Ask for the package, will return non-zero if it's not found.
  help         Show this message again.
  version      Print the version.
  build        Build a package.
  upgrade      Install portage itself (latest version)
  status       To fully understand what this command does, please refer to <https://github.com/thekaigonzalez/Portage/wiki/Maintaining-Portage>.
  check        Returns the version hash (from 0-5) of the requested package.
  list         List the installed packages and their versions  
  remove       Remove a package.

Synopses:
  install <package>
  ask <package>
  remove <package>
  build <directory>
  check <package>

  list ...
  status ...
  version ...
  upgrade ...
  help ...
");
  if (err)return 1;
  return 0;
}

string HOME_DIR = "";

void initialize_home() {
  HOME_DIR = expandTilde("~/.config/portage");
  if (!exists(HOME_DIR)) { mkdir(HOME_DIR); }
}

void list_installed() {
  foreach (string f ; dirEntries(HOME_DIR, SpanMode.depth)) {
    f = baseName(f);
    string pkg_version = readText(HOME_DIR ~ "/" ~ f);
    string pkg_name = f[f.indexOf("-")+1..$];
    writefln("package: %s\n\tversion: %s", pkg_name, pkg_version);
  }
}

int remove_pkg(string pkgname) {
  writeln(":: Trying to remove package, `" ~ pkgname ~ "'");
  writeln("cloning...");
  executeShell("git clone https://github.com/" ~ pkgname ~ " /tmp/gtp");
  writeln("changing working dir...");
  try {
  chdir("/tmp/gtp");
  } catch (Exception e) { print_error(e.msg); return -1; }
  
  if (exists("ebuild")) {
    print_error("if you are trying to use an E-Build removal process, do NOT use 'portage remove'.");
    print_error("instead, try to use the new E-Build 'removal' type please.");
    return -1;
  } 

  writeln(":: Executing remove hooks...");

  auto removeHook = executeShell(". ./pbuild && remove");

  if (removeHook.status == 127) {
    print_error("currently, your package does not support the 'remove' hook;\nbut give maintainers some time to adjust.");
    return -1;
  }

  writeln(":: Remove hook completed, package (hopefully) removed! ;)");
  rmdirRecurse("/tmp/gtp");
  remove(HOME_DIR ~ "version-" ~ pkgname[indexOf(pkgname, "/")+1 .. $]);
  return 0;
}

void print_error(string errmsg, string progname = "portage") {
  writefln("%s: \033[31;1merror: \033[0m%s", progname, errmsg);
}

int ask(string pkgname) {
  string veryify_site = "https://github.com/" ~ pkgname;

  try { get(veryify_site);return 0; } catch (CurlException) { return 1; }
}

bool same_version(string pkg) {
  auto git_latest = executeShell("git log --format='%H' -n 1");
  auto fs_latest = readText(HOME_DIR ~ "version-" ~ pkg);

  if (fs_latest == git_latest.output) return true;
  else return false;
}

int build_directory(string dirname) {
  writeln(":: Changing working_dir to " ~dirname ~ "...");
  if (!endsWith(dirname, "/")) dirname ~= "/";
  chdir(dirname);
  writeln(":: Checking for `ebuild' ...");
  if (!exists("./ebuild")) {
    print_error("no ebuild found.");
    return 1;
  }
  string author = executeShell(". ./ebuild && echo \"${author[0]}\"").output.strip;
  string repo = executeShell(". ./ebuild && echo \"${repository[0]}\"").output.strip;
  
  writeln(":: Cloning repository...");
  executeShell("git clone " ~ repo ~ " /tmp/gtp");
  
  writeln(":: Configuring repository...");

  // OK, so this is a bit tricky.
  // What I'm gonna do is copy the ebuild to the working
  // directory and i'm gonna try to run the instructions as
  // if they were in the current dir.
  if (!exists("/tmp/gtp/ebuild"))
  copy("./ebuild", "/tmp/gtp/ebuild");

  try {
    chdir("/tmp/gtp");
  }
  catch (FileException) {
    print_error("failed to change to the temporary directory!");
    rmdirRecurse("/tmp/gtp");
    return -1;
  }

  writeln("are you ready to build this software? Author: " ~ author ~ "");

  write("(y/n) ");
  string yn = readln().strip;

  if (yn == "n") { 
    rmdirRecurse("/tmp/gtp");
    return 1; }

  writeln(":: Building package...");
  
  executeShell(". ./ebuild && instruction");

  writeln(":: Running post-install ...");

  rmdirRecurse("/tmp/gtp");

  writeln("Installation completed!");

  return 0;
}

int install(string pkgname) {
  bool showdiff = false;
  writeln(":: Checking for package...");
  if (ask(pkgname) == 0) {
    writeln("package found!");
  } else {
    print_error("package not found: " ~ pkgname);
    return 1;
  }
  writeln("downloading version from git...");
  
  try {
    executeShell("git clone https://github.com/" ~ pkgname ~ " /tmp/gtp");
  } catch (ProcessException e) {
    print_error(e.msg);
    return 1;
  }

  writeln("changing working directory...");

  try {
    chdir("/tmp/gtp");
  } catch (FileException e) {
    print_error("temporary directory failed to create! this could be because
you specified a user instead of a package, if not, report this to https://github.com/DoorsLinux/Portage-Support/issues");
    return 1;
  }
  if (exists("ebuild")) {
    return build_directory("./");
  }
  string disp_pkgname = pkgname[indexOf(pkgname, '/')+1..$];
  if (exists(HOME_DIR)) {
    if (exists(HOME_DIR ~ "/version-" ~ disp_pkgname)) {
      string ver_last = readText(HOME_DIR ~ "/version-" ~ disp_pkgname);
      auto ver = executeShell("git log --format=\"%H\" -n 1");
      if (ver.output == ver_last) {
        writeln("warning: reinstalling, both versions are the same!");
      } else {
        writeln("upgrade: " ~ ver_last[0 .. 5] ~ " -> " ~ ver.output[0 .. 5]);
      }
      auto gitdiff = executeShell("git diff " ~ ver_last);
      
      if (gitdiff.output.length == 0) {
        if (showdiff)
        writeln("warning: no git diff found");
      } else {
        if (showdiff)
        writeln(gitdiff.output);
      }
    }
  } else {
    initialize_home();
  }

  writeln(":: (git) saving version information");
  try {
  File n = File(HOME_DIR ~ "/version-" ~ disp_pkgname, "w");
  n.write(executeShell("git log --format=\"%H\" -n 1").output);
  n.close();
  } catch (Exception e) {
    print_error("could not create diff cache: " ~ e.msg);
  }
  writeln(":: Running install hooks...");
  if (!exists("pbuild")) { 
    print_error("repository '" ~ disp_pkgname ~ "' does not support portage.");
    rmdirRecurse("/tmp/gtp");
    remove(HOME_DIR ~ "/version-" ~ disp_pkgname);
    return -1;
  }
  string author = executeShell(". ./pbuild && echo \"${author[0]}\"").output.strip;

  if (author.length == 0) {
    author = "(No Author information)";
  }
  writefln(":: Would you like to install this software by %s?", author);

  write("(y/n) ");
  string yn = readln().strip;

  if (yn == "n") {
    rmdirRecurse("/tmp/gtp");
    return 0;
  }
  writeln(":: Building package...");
  executeShell(". ./pbuild && build");
  // chdir("build");
  // auto ninja = executeShell("ninja install");
  // if (ninja.status != 0) {
  //  print_error("when building package:\noutput:\n" ~ ninja.output);
  //  return 1;
  // }
  writeln(":: Running default post-installation");
  rmdirRecurse("/tmp/gtp");
  return 0;
}
