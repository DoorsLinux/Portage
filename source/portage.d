import std.stdio;
import std.format;
import source.subs;
import std.process;
import std.file;

int print_usage(bool err = false) {
  writeln("
usage: portage <command> <package>

PORTAGE is a meson-based package manager
written and used by DoorsOS, but can be configured for other OSes too.

Commands:
  install      Install a package.
  ask          Ask for the package, will return non-zero if it's not found.
  help         Show this message again.
");
  if (err)return 1;
  return 0;
}

void print_error(string errmsg, string progname = "portage") {
  writefln("%s: \033[31;1merror: \033[0m%s", progname, errmsg);
}

int main(string[] args) {
  if (args.length == 1) return print_usage();
  
  switch (args[1]) {
    case "ask":
      if (args.length == 2) { 
        print_error("'ask' requires one more argument, [package]");
        return 1;
      }
      writefln(":: Requesting `%s` from server...", args[2]);
      return ask(args[2]);
    case "install":
      writeln(":: Checking for package...");
      if (ask(args[2]) == 0) {
        writeln("package found!");
      } else {
        print_error("package not found: " ~ args[2]);
        return 1;
      }
      writeln("downloading version from git...");
      try {
        executeShell("git clone https://github.com/" ~ args[2] ~ " /tmp/gtp");
      } catch (ProcessException e) {
        print_error(e.msg);
        return 1;
      }
      writeln("changing working directory...");
      chdir("/tmp/gtp");
      writeln("configuring build...");
      executeShell("meson build");
      writeln("building package...");
      chdir("build");
      auto ninja = executeShell("ninja install");
      if (ninja.status != 0) {
        print_error("when building package:\noutput:\n" ~ ninja.output);
        return 1;
      }
      writeln(":: Running default post-installation");
      rmdirRecurse("/tmp/gtp");
      break;
    default:
      print_error(format("unknown command, `%s'", args[1]));
      return 1;
  }
  return 0;
}
