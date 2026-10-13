#!/usr/bin/env perl
use strict;
use warnings;
use File::Copy;
use POSIX qw(strftime);

my $config_file = $ARGV[0] || "/etc/nixos/configuration.nix";
my $target_user = $ARGV[1] || $ENV{SUDO_USER} || $ENV{USER} || "levandoski";

if (! -f $config_file) {
    die "Configuration file not found: $config_file\n";
}

# Read existing configuration
open my $fh, '<', $config_file or die "Cannot read $config_file: $!\n";
my $content = do { local $/; <$fh> };
close $fh;

# List of Zenith required packages
my @zenith_pkgs = (
    # Core & Shell
    "hyprland",
    "quickshell",
    "hyprpaper",
    "hyprsunset",
    "foot",
    "fish",
    "eza",
    "zoxide",
    "bat",
    "fastfetch",
    "yazi",
    "swaylock",
    
    # Utilities & Tools
    "jq",
    "wl-clipboard",
    "cliphist",
    "grim",
    "slurp",
    "ffmpeg",
    "wf-recorder",
    "wtype",
    "brightnessctl",
    "ddcutil",
    "playerctl",
    "wireplumber",
    "python3",
    "openssl",
    "xdg-utils",
    "glib",
    "upower",
    "cava",
    "mpvpaper",
    "bibata-cursors",
    "papirus-icon-theme",
    "udisks2",
    "udiskie",
    "gvfs",
    
    # Qt6 / QML libraries
    "qt6.qtmultimedia",
    "qt6.qtdeclarative",
    "qt6.qtsvg",
    
    # Python helpers
    "python3Packages.secretstorage",
    "python3Packages.cryptography",
);

# 1. Check packages inside environment.systemPackages
if ($content =~ /(environment\.systemPackages\s*=\s*(?:with\s+pkgs;\s*)?\[)([\s\S]*?)(\];)/) {
    my $prefix = $1;
    my $pkg_block = $2;
    my $suffix = $3;
    
    my @missing;
    for my $pkg (@zenith_pkgs) {
        # Check if package name is already present as a word/token in the block
        my $escaped = quotemeta($pkg);
        if ($pkg_block !~ /\b$escaped\b/) {
            push @missing, $pkg;
        }
    }
    
    if (@missing) {
        my $added_str = "\n    # Zenith dependencies\n";
        for my $p (@missing) {
            $added_str .= "    $p\n";
        }
        # Insert before closing bracket
        my $new_pkg_block = $pkg_block . $added_str . "  ";
        $content =~ s/\Q$prefix$pkg_block$suffix\E/$prefix$new_pkg_block$suffix/;
    }
} else {
    # If environment.systemPackages is not found, add it before the final closing brace
    my $new_block = "\n  environment.systemPackages = with pkgs; [\n";
    for my $p (@zenith_pkgs) {
        $new_block .= "    $p\n";
    }
    $new_block .= "  ];\n";
    $content =~ s/(\n\s*\}\s*)$/$new_block$1/;
}

# 2. Check environment.sessionVariables for QML2_IMPORT_PATH
if ($content =~ /(environment\.sessionVariables\s*=\s*\{)([\s\S]*?)(\};)/) {
    my $prefix = $1;
    my $var_block = $2;
    my $suffix = $3;
    
    if ($var_block !~ /QML2_IMPORT_PATH/) {
        my $new_var_block = $var_block . "\n    QML2_IMPORT_PATH = \"/run/current-system/sw/lib/qt-6/qml\";\n  ";
        $content =~ s/\Q$prefix$var_block$suffix\E/$prefix$new_var_block$suffix/;
    }
} else {
    my $new_block = "\n  environment.sessionVariables = {\n    QML2_IMPORT_PATH = \"/run/current-system/sw/lib/qt-6/qml\";\n  };\n";
    $content =~ s/(\n\s*\}\s*)$/$new_block$1/;
}

# 3. Check PAM for swaylock
if ($content !~ /security\.pam\.services\.swaylock/) {
    my $pam_block = "\n  # PAM profile for swaylock & Zenith password vault\n  security.pam.services.swaylock = {};\n";
    $content =~ s/(\n\s*\}\s*)$/$pam_block$1/;
}

# 4. Check Services & Hardware for Zenith
if ($content !~ /services\.power-profiles-daemon\.enable/) {
    my $block = "\n  services.power-profiles-daemon.enable = true;\n";
    $content =~ s/(\n\s*\}\s*)$/$block$1/;
}

if ($content !~ /services\.upower\.enable/) {
    my $block = "\n  services.upower.enable = true;\n";
    $content =~ s/(\n\s*\}\s*)$/$block$1/;
}

if ($content !~ /hardware\.bluetooth\.enable/) {
    my $block = "\n  hardware.bluetooth.enable = true;\n";
    $content =~ s/(\n\s*\}\s*)$/$block$1/;
}

if ($content !~ /hardware\.i2c\.enable/) {
    my $block = "\n  hardware.i2c.enable = true;\n";
    $content =~ s/(\n\s*\}\s*)$/$block$1/;
}

if ($content !~ /programs\.fish\.enable/) {
    my $block = "\n  programs.fish.enable = true;\n";
    $content =~ s/(\n\s*\}\s*)$/$block$1/;
}

# 5. Check tmpfiles rules for Zenith wallpaper sync & SDDM bridge
if ($content =~ /(systemd\.tmpfiles\.rules\s*=\s*\[)([\s\S]*?)(\];)/) {
    my $prefix = $1;
    my $rules_block = $2;
    my $suffix = $3;
    if ($rules_block !~ /\/var\/lib\/zenith/) {
        my $new_rules = $rules_block . "    \"d /var/lib/zenith 0777 root root -\"\n  ";
        $content =~ s/\Q$prefix$rules_block$suffix\E/$prefix$new_rules$suffix/;
    }
} elsif ($content !~ /\/var\/lib\/zenith/) {
    my $tmpfiles_block = "\n  # Zenith shared directory for wallpaper & SDDM sync\n  systemd.tmpfiles.rules = [\n    \"d /var/lib/zenith 0777 root root -\"\n  ];\n";
    $content =~ s/(\n\s*\}\s*)$/$tmpfiles_block$1/;
}

# 6. Check Fonts
if ($content !~ /fonts\.packages/ && $content !~ /fonts\.fonts/) {
    my $fonts_block = "\n  fonts.packages = with pkgs; [\n    nerd-fonts.jetbrains-mono\n    noto-fonts\n    noto-fonts-color-emoji\n    noto-fonts-cjk-sans\n    noto-fonts-extra\n  ];\n";
    $content =~ s/(\n\s*\}\s*)$/$fonts_block$1/;
}

# 7. Check user extraGroups for "i2c"
if ($target_user && $content =~ /(users\.users\."?$target_user"?[\s\S]*?extraGroups\s*=\s*\[)([\s\S]*?)(\];)/) {
    my $prefix = $1;
    my $groups_block = $2;
    my $suffix = $3;
    if ($groups_block !~ /\bi2c\b/) {
        my $new_groups = $groups_block;
        $new_groups =~ s/\s+$//;
        $new_groups .= ' "i2c" ';
        $content =~ s/\Q$prefix$groups_block$suffix\E/$prefix$new_groups$suffix/;
    }
}

# 8. Check imports for ./zenith.nix
if (-f "/etc/nixos/zenith.nix" || -f "./zenith.nix") {
    if ($content =~ /(imports\s*=\s*\[)([\s\S]*?)(\];)/) {
        my $prefix = $1;
        my $imp_block = $2;
        my $suffix = $3;
        if ($imp_block !~ /zenith\.nix/) {
            my $new_imp = $imp_block . "\n      ./zenith.nix\n    ";
            $content =~ s/\Q$prefix$imp_block$suffix\E/$prefix$new_imp$suffix/;
        }
    }
}

# Output modified content
print $content;
