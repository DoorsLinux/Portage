import std.stdio;
import std.format;
import source.subs;
import std.algorithm;
import std.process;
import std.file;
import std.path;
import std.string;
import source.gitversion;

string VERSION = "";

string fresh_or_maintained() {
  if (exists("/tmp/portage/version-portage")) return "maintained";
  else return "fresh";
}

int main(string[] args) {
  initialize_home();
  if (executeShell("git").status == 127) {
    print_error("failed to find git installation. please install git.");
    return -1;
  }
  if (args.length == 1) {
    writeln("'portage' requires one subcommand, say 'portage help' for a list of subcommands.");
    return 0;
  }
  try {
  switch (args[1]) {
    case "ask":
      if (args.length == 2) { 
        print_error("'ask' requires one more argument, [package]");
        return 1;
      }
      writefln(":: Requesting `%s` from server...", args[2]);
      return ask(args[2]);
    case "install":
      install(args[2]);
      break;
    case "build":
      if (exists(args[2]) && isDir(args[2])) {
        return build_directory(args[2]);
      }
      break;
    case "version":
      writeln("Signature: " ~ GIT_VERSION ~ "\nSupports E-Building: yes\nSupports PBuild: yes");
      break;
    case "status":
      writeln(fresh_or_maintained());
      break;
    case "upgrade":
      writeln(":: Updating portage!");
      install("thekaigonzalez/portage.codeberg");
      break;
    case "remove":
      remove_pkg(args[2]);
      break;
    case "list":
      list_installed();
      return 0;
    case "check":
      if (exists(HOME_DIR ~ "/version-" ~ args[2])) {
        writeln("Currently installed version of " ~ args[2] ~ ": " ~ (HOME_DIR ~ "/version-"~args[2]).readText.strip[0 .. 5]);
      } else {
        print_error("the requested package, `" ~ args[2] ~ "' was not found on the system.");
        return 1;
      }
      break;
    case "help":
      return print_usage(false);
    case "update":
      if (same_version(args[2])) {
        writeln("package '" ~ args[2] ~ "' up-to-date. nothing to do.");
        return 0;
      }
      install(args[2]);
      break;
    default:
      if (!exists(expandTilde("~/.config/portage/subcommands"))) mkdir(expandTilde("~/.config/portage/subcommands"));
      
      if (exists(expandTilde("~/.config/portage/subcommands/" ~ args[1]))) {
        string subf = args[1];
        string cmd = expandTilde("~/.config/portage/subcommands/" ~ subf) ~ " " ~ join(remove(args, 0).remove(0), " ");

        auto shellcd = executeShell(cmd);

        write(shellcd.output);
      } else {
        print_error(format("unknown command, `%s'", args[1]));
      }
      return 1;
  }
  } catch (Error e) {
    print_error("core error: " ~ e.msg);
    return 1;
  }
  return 0;
}
