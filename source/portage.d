import std.stdio;
import std.format;
import source.subs;
import std.process;
import std.file;


int main(string[] args) {
  if (args.length == 1) {
    writeln("'portage' requires one subcommand, say 'portage help' for a list of subcommands.");
    return 0;
  }
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
    case "version":
      writeln("Portage is still in version 1!");
      break;
    case "upgrade":
      writeln(":: Updating portage!");
      install("thekaigonzalez/portage");
      break;
    case "help":
      return print_usage(false);
    default:
      print_error(format("unknown command, `%s'", args[1]));
      return 1;
  }
  return 0;
}
