import std.stdio;
import std.net.curl;
import std.process;
import std.file;
import std.string;

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
  upgrade      Install portage itself (latest version)
");
  if (err)return 1;
  return 0;
}

void print_error(string errmsg, string progname = "portage") {
  writefln("%s: \033[31;1merror: \033[0m%s", progname, errmsg);
}



int ask(string pkgname) {
  string veryify_site = "https://github.com/" ~ pkgname;

  try { get(veryify_site);return 0; } catch (CurlException) { return 1; }
}

int install(string pkgname) {
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
  string disp_pkgname = pkgname[indexOf(pkgname, '/')+1..$];
  writeln(":: Getting last installed version...");
  if (exists("/tmp/.portage")) {
    if (exists("/tmp/.portage/.version-" ~ pkgname)) {
      string ver_last = readText("/tmp/.portage/.version-" ~ disp_pkgname);
      
      auto gitdiff = executeShell("git diff " ~ ver_last);
      if (gitdiff.output.length == 0) {
        writeln("warning: no git diff found");
      }
      else {
        writeln(gitdiff.output);
      }
    }
  } else {
    mkdir("/tmp/.portage");
  }

  writeln(":: (git) saving version information");
  try {
  File n = File("/tmp/.portage/.version-" ~ disp_pkgname, "w");
  n.write(executeShell("git log --format=\"%H\" -n 1").output);
  n.close();
  } catch (Exception e) {
    print_error("could not create diff cache: " ~ e.msg);
  }
  writeln(":: Running install hooks...");
  executeShell("source ./pbuild && build");
  writeln("building package...");
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
