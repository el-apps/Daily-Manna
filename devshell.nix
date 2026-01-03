{ pkgs }:

with pkgs;

let
  conditionalPackages = [ ];
in
with pkgs;

devshell.mkShell {
  name = "daily-manna";
  motd = ''
    Entered the Daily Manna Flutter Android development environment.
  '';
  env = [
    {
      name = "ANDROID_HOME";
      value = "${android-sdk}/share/android-sdk";
    }
    {
      name = "ANDROID_SDK_ROOT";
      value = "${android-sdk}/share/android-sdk";
    }
    {
      name = "JAVA_HOME";
      value = jdk.home;
    }
  ];
  packages = [
    flutter
    android-sdk
    gradle
    jdk
    git
    just
  ] ++ conditionalPackages;
}
