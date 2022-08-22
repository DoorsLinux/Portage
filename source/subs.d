import std.stdio;
import std.net.curl;
import std.process;
import std.file;
import std.string;
// import std.json;

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

bool same_version(string pkg) {
  auto git_latest = executeShell("git log --format='%H' -n 1");
  auto fs_latest = readText("/tmp/portage/version-" ~ pkg);

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
  string author = executeShell("source ./ebuild && echo \"${author[0]}\"").output;
  string repo = executeShell("source ./ebuild && echo \"${repository[0]}\"").output.strip;
  
  writeln(":: Cloning repository...");
  executeShell("git clone " ~ repo ~ " /tmp/gtp");
  
  writeln(":: Configuring repository...");

  // OK, so this is a bit tricky.
  // What I'm gonna do is copy the ebuild to the working
  // directory and i'm gonna try to run the instructions as
  // if they were in the current dir.

  copy("./ebuild", "/tmp/gtp/ebuild");

  try {
    chdir("/tmp/gtp");
  }
  catch (FileException) {
    print_error("failed to change to the temporary directory!");
    rmdirRecurse("/tmp/gtp");
    return -1;
  }

  writeln("would you like to install this software by: " ~ author ~ "?");

  write("(y/n) ");
  string yn = readln();

  if (yn == "n") { return 1; }

  writeln(":: Building package...");
  
  executeShell("source ./ebuild && instruction");

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
  string disp_pkgname = pkgname[indexOf(pkgname, '/')+1..$];
  if (exists("/tmp/portage")) {
    if (exists("/tmp/portage/version-" ~ disp_pkgname)) {
      string ver_last = readText("/tmp/portage/version-" ~ disp_pkgname);
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
    mkdir("/tmp/portage");
  }

  writeln(":: (git) saving version information");
  try {
  File n = File("/tmp/portage/version-" ~ disp_pkgname, "w");
  n.write(executeShell("git log --format=\"%H\" -n 1").output);
  n.close();
  } catch (Exception e) {
    print_error("could not create diff cache: " ~ e.msg);
  }
  writeln(":: Running install hooks...");
  if (!exists("pbuild")) { 
    print_error("repository '" ~ disp_pkgname ~ "' does not support portage.");
    rmdirRecurse("/tmp/gtp");
    remove("/tmp/portage/version-" ~ disp_pkgname);
    return -1;
  }
  string author = executeShell("source ./pbuild && echo \"${author[0]}\"").output.strip;

  if (author.length == 0) {
    author = "(No Author information)";
  }
  writefln(":: Would you like to install this software by %s?", author);

  write("(y/n) ");
  string yn = readln();

  if (yn == "n") {
    return 0;
  }
  writeln(":: Building package...");
  executeShell("source ./pbuild && build");
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
