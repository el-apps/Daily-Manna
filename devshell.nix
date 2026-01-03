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
    {
      name = "GRADLE_OPTS";
      value = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${android-sdk}/share/android-sdk/build-tools/34.0.0/aapt2";
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
