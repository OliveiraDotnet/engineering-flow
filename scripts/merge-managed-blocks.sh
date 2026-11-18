#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: bash ./scripts/merge-managed-blocks.sh --template PATH --target PATH [--check] [--quiet]" >&2
}

template_path=""
target_path=""
check_only=false
quiet=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --template)
      [ "$#" -ge 2 ] || { echo "Missing value for --template" >&2; exit 2; }
      template_path="$2"
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || { echo "Missing value for --target" >&2; exit 2; }
      target_path="$2"
      shift 2
      ;;
    --check) check_only=true; shift ;;
    --quiet) quiet=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$template_path" ] && [ -n "$target_path" ] || { usage; exit 2; }
[ -f "$template_path" ] || { echo "ERROR: Template file not found: $template_path" >&2; exit 2; }
[ -f "$target_path" ] || { echo "ERROR: Target file not found: $target_path" >&2; exit 2; }

if ! command -v perl >/dev/null 2>&1; then
  echo "ERROR: perl is required for merge-managed-blocks.sh" >&2
  exit 2
fi

check_flag=0
[ "$check_only" = true ] && check_flag=1
quiet_flag=0
[ "$quiet" = true ] && quiet_flag=1

perl -e '
use strict;
use warnings;
use File::Basename qw(basename);

my ($tmpl_path, $target_path, $check_only, $quiet) = @ARGV;

sub read_raw {
    my ($p) = @_;
    open my $fh, "<:raw", $p or die "Cannot read $p: $!\n";
    local $/;
    my $data = <$fh>;
    close $fh;
    $data = "" unless defined $data;
    return $data;
}

sub parse_blocks {
    my ($text) = @_;
    my @blocks;
    my %seen;
    my $open_id;
    my $open_inner_start;
    my $marker_count = 0;

    while ($text =~ /<!--\s*ef:managed:([^\r\n]*?)-->/g) {
        $marker_count++;
        my $m_start = $-[0];
        my $m_end   = $+[0];
        my $payload = $1;
        $payload =~ s/^\s+|\s+$//g;

        if ($payload !~ /^(begin|end):([A-Za-z0-9_-]+)$/) {
            return ("MALFORMED", []);
        }
        my ($kind, $id) = ($1, $2);

        if ($kind eq "begin") {
            return ("MALFORMED", []) if defined $open_id;
            return ("MALFORMED", []) if exists $seen{$id};
            $open_id = $id;
            $open_inner_start = $m_end;
            if (substr($text, $m_end) =~ /^([ \t]*\r?\n)/) {
                $open_inner_start += length($1);
            }
        } else {
            return ("MALFORMED", []) unless defined $open_id;
            return ("MALFORMED", []) if $open_id ne $id;
            push @blocks, {
                id          => $id,
                inner_start => $open_inner_start,
                inner_end   => $m_start,
            };
            $seen{$id} = 1;
            $open_id = undef;
            $open_inner_start = undef;
        }
    }

    return ("MALFORMED", []) if defined $open_id;
    return ("NO_MARKERS", []) if $marker_count == 0;
    return ("VALID", \@blocks);
}

my $tmpl_raw = read_raw($tmpl_path);
$tmpl_raw =~ s/^\xEF\xBB\xBF//;

my ($tmpl_status, $tmpl_blocks) = parse_blocks($tmpl_raw);
if ($tmpl_status ne "VALID") {
    print STDERR "ERROR: Template $tmpl_path has invalid ef:managed markers ($tmpl_status).\n";
    exit 2;
}

my %tmpl_inner;
my @tmpl_order;
for my $b (@$tmpl_blocks) {
    $tmpl_inner{$b->{id}} = substr($tmpl_raw, $b->{inner_start}, $b->{inner_end} - $b->{inner_start});
    push @tmpl_order, $b->{id};
}

my $target_raw = read_raw($target_path);
my $has_bom = ($target_raw =~ s/^\xEF\xBB\xBF//) ? 1 : 0;
my $target_name = basename($target_path);

my ($target_status, $target_blocks) = parse_blocks($target_raw);
if ($target_status eq "NO_MARKERS") {
    if (!$quiet) {
        print STDERR "WARNING: $target_name has no ef:managed markers; kept as is. Review $target_name.agent-pack.new and add markers to enable merge.\n";
    }
    exit 7;
}
if ($target_status eq "MALFORMED") {
    if (!$quiet) {
        print STDERR "WARNING: $target_name has malformed ef:managed markers; kept as is. Review $target_name.agent-pack.new and add markers to enable merge.\n";
    }
    exit 7;
}

my $target_eol = ($target_raw =~ /\r\n/) ? "\r\n" : "\n";

my $out = "";
my $pos = 0;
my %target_seen;

for my $b (@$target_blocks) {
    my $id = $b->{id};
    $target_seen{$id} = 1;
    $out .= substr($target_raw, $pos, $b->{inner_start} - $pos);
    if (exists $tmpl_inner{$id}) {
        my $adapted = $tmpl_inner{$id};
        $adapted =~ s/\r?\n/$target_eol/g;
        $out .= $adapted;
    } else {
        if (!$quiet) {
            print STDERR "WARNING: $target_name contains unknown ef:managed block \x27$id\x27; kept intact.\n";
        }
        $out .= substr($target_raw, $b->{inner_start}, $b->{inner_end} - $b->{inner_start});
    }
    $pos = $b->{inner_end};
}
$out .= substr($target_raw, $pos);

for my $id (@tmpl_order) {
    next if exists $target_seen{$id};
    if (length($out) > 0) {
        if ($out !~ /\n\z/) {
            $out .= $target_eol;
        }
        if ($out !~ /(?:\r?\n){2}\z/) {
            $out .= $target_eol;
        }
    }
    my $adapted = $tmpl_inner{$id};
    $adapted =~ s/\r?\n/$target_eol/g;
    if (length($adapted) > 0 && $adapted !~ /\n\z/) {
        $adapted .= $target_eol;
    }
    $out .= "<!-- ef:managed:begin:$id -->$target_eol";
    $out .= $adapted;
    $out .= "<!-- ef:managed:end:$id -->$target_eol";
}

my $blocks_csv = join(",", @tmpl_order);

if ($check_only) {
    print "$blocks_csv\n";
    exit 0;
}

my $final_bytes = ($has_bom ? "\xEF\xBB\xBF" : "") . $out;
my $tmp_path = "$target_path.agent-pack.tmp.$$";
open my $out_fh, ">:raw", $tmp_path or die "Cannot write temp file $tmp_path: $!\n";
print {$out_fh} $final_bytes or die "Cannot write to $tmp_path: $!\n";
close $out_fh or die "Cannot close $tmp_path: $!\n";
rename($tmp_path, $target_path) or die "Cannot replace $target_path: $!\n";

print "$blocks_csv\n";
exit 0;
' "$template_path" "$target_path" "$check_flag" "$quiet_flag"
