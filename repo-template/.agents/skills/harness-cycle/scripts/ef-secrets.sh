#!/usr/bin/env bash
# Shared secret masking, scanning, and runner-block helpers for Engineering Flow harness scripts.

if ! command -v perl >/dev/null 2>&1; then
  echo "Error: perl is required for secret masking and scanning." >&2
  exit 2
fi

_EF_SECRET_VALS_HEX=""
_EF_SECRET_NAMES_HEX=""
_EF_LAST_MASK_COUNT=0
_EF_SCAN_STATUS="clean"
_EF_SCAN_FINDINGS=()
_EF_SCAN_UNSCANNED=()

ef_load_secrets() {
  local repo_root="${1:?repo_root required}"
  local harness_log_dir="${2:-$repo_root/.agent-pack/logs}"
  local secret_file="${EF_SECRET_VALUES_FILE:-}"
  local secret_names="${EF_SECRET_NAMES:-}"

  if [ -n "$secret_file" ]; then
    if [ ! -f "$secret_file" ]; then
      echo "Error: EF_SECRET_VALUES_FILE does not exist or is not a regular file." >&2
      return 2
    fi
    if ! perl -MCwd=abs_path -MFile::Spec -e '
      use strict; use warnings;
      my ($file, $repo, $logdir) = @ARGV;
      sub canon {
        my ($p) = @_;
        $p = File::Spec->rel2abs($p);
        my $abs = abs_path($p);
        return $abs if defined $abs;
        my ($vol, $dir, $base) = File::Spec->splitpath($p);
        my @parts;
        while (!defined abs_path($p) && length($p) > 1) {
          $p =~ s/[\/\\]+$//;
          my $parent = File::Spec->catpath($vol, (File::Spec->splitpath($p))[1], "");
          my $leaf = (File::Spec->splitpath($p))[2];
          unshift @parts, $leaf if length($leaf);
          last if $parent eq $p;
          $p = $parent;
          $p =~ s/[\/\\]+$// unless $p eq "/";
          $abs = abs_path($p);
          return File::Spec->catfile($abs, @parts) if defined $abs;
        }
        return File::Spec->canonpath($p);
      }
      my $cf = canon($file);
      my @forbidden = (
        canon($repo),
        canon($logdir),
        canon(File::Spec->catdir($repo, ".agent-pack", "evidencias")),
        canon(File::Spec->catdir($repo, ".agent-pack", ".runtime"))
      );
      for my $dir (@forbidden) {
        $dir =~ s/\/+$//;
        if ($cf eq $dir || index($cf, "$dir/") == 0) {
          die "forbidden";
        }
      }
    ' "$secret_file" "$repo_root" "$harness_log_dir" 2>/dev/null; then
      echo "Error: EF_SECRET_VALUES_FILE cannot reside inside the repository, EF_HARNESS_LOG_DIR, evidencias/, or .runtime/." >&2
      return 2
    fi
  fi

  local loaded
  loaded="$(EF_INT_SECRET_FILE="$secret_file" EF_INT_SECRET_NAMES="$secret_names" EF_INT_REPO_ROOT="$repo_root" perl -e '
    use strict; use warnings;
    my %vals;
    my $add_val = sub {
      my ($v) = @_;
      return unless defined $v && length($v) >= 6;
      $vals{$v} = 1;
      my $j1 = $v;
      $j1 =~ s/\\/\\\\/g;
      $j1 =~ s/"/\\"/g;
      $vals{$j1} = 1 if length($j1) >= 6;
      my $j2 = $j1;
      $j2 =~ s/\//\\\//g;
      $vals{$j2} = 1 if length($j2) >= 6;
    };

    for my $k (keys %ENV) {
      if ($k =~ /(?:TOKEN|PAT|KEY|SECRET|PASSWORD)$/i) {
        $add_val->($ENV{$k});
      }
    }

    my $sf = $ENV{EF_INT_SECRET_FILE} // "";
    if (length($sf)) {
      open my $fh, "<:raw", $sf or exit 2;
      while (my $line = <$fh>) {
        $line =~ s/\r?\n$//;
        next unless length($line);
        $add_val->($line);
      }
      close $fh;
    }

    my %names;
    my $add_names = sub {
      my ($raw) = @_;
      return unless defined $raw && length($raw);
      for my $item (split /,/, $raw) {
        $item =~ s/^\s+|\s+$//g;
        $item =~ s/^\[|\]$//g;
        $item =~ s/^`|`$//g;
        $item =~ s/^\s+|\s+$//g;
        next unless length($item);
        next if $item eq "..." || $item eq "não" || $item eq "nao";
        $names{$item} = 1;
      }
    };

    $add_names->($ENV{EF_INT_SECRET_NAMES} // "");
    my $agents_md = ($ENV{EF_INT_REPO_ROOT} // ".") . "/AGENTS.md";
    if (-f $agents_md) {
      if (open my $afh, "<:raw", $agents_md) {
        while (my $line = <$afh>) {
          $line =~ s/\r?\n$//;
          if ($line =~ /^\s*-\s*Nomes\s+sens(?:\x{c3}\x{ad}|i)veis\s+\(mascaramento\)\s*:\s*(.+)$/i) {
            $add_names->($1);
          }
        }
        close $afh;
      }
    }

    my @sorted_vals = sort { length($b) <=> length($a) || $a cmp $b } keys %vals;
    my @sorted_names = sort { length($b) <=> length($a) || $a cmp $b } keys %names;
    print join(":", map { unpack("H*", $_) } @sorted_vals), "\n";
    print join(":", map { unpack("H*", $_) } @sorted_names), "\n";
  ')" || {
    echo "Error: Failed to load secret definitions." >&2
    return 2
  }

  _EF_SECRET_VALS_HEX="$(printf '%s\n' "$loaded" | sed -n '1p')"
  _EF_SECRET_NAMES_HEX="$(printf '%s\n' "$loaded" | sed -n '2p')"
  return 0
}

read -r -d '' _EF_PERL_MASK_HELPERS <<'EF_PERL_EOF' || true
sub ef_decode_with_map {
  my ($orig) = @_;
  my $dec = "";
  my @ostart;
  my @oend;
  my $len = length($orig);
  my $i = 0;
  while ($i < $len) {
    my $ch = substr($orig, $i, 1);
    if ($ch eq "\\" && ($i + 1) < $len) {
      my $nxt = substr($orig, $i + 1, 1);
      if ($nxt eq "\"" || $nxt eq "\\" || $nxt eq "/") {
        $dec .= $nxt;
        push @ostart, $i;
        push @oend, $i + 2;
        $i += 2;
        next;
      }
      if ($nxt eq "u" && ($i + 5) < $len) {
        my $hex = substr($orig, $i + 2, 4);
        if ($hex =~ /^[0-9a-fA-F]{4}$/) {
          my $code = hex($hex);
          if ($code != 0 && !($code >= 0xD800 && $code <= 0xDFFF)) {
            my $u = chr($code);
            utf8::encode($u) if $code >= 0x80;
            for my $b (split //, $u) {
              $dec .= $b;
              push @ostart, $i;
              push @oend, $i + 6;
            }
            $i += 6;
            next;
          }
        }
      }
    }
    $dec .= $ch;
    push @ostart, $i;
    push @oend, $i + 1;
    $i += 1;
  }
  return ($dec, \@ostart, \@oend);
}

sub ef_replace_spans {
  my ($orig, $ostart, $oend, $spans) = @_;
  return $orig unless @$spans;
  my $out = $orig;
  for my $sp (reverse @$spans) {
    my ($ds, $de) = @$sp;
    next unless $de > $ds;
    my $os = $ostart->[$ds];
    my $oe = $oend->[$de - 1];
    substr($out, $os, $oe - $os, "[EF-MASKED]");
  }
  return $out;
}

sub ef_mask_line {
  my ($orig, $vals_ref, $key_re) = @_;
  my $line = $orig;
  my $cnt = 0;
  my ($dec, $ostart, $oend) = ef_decode_with_map($line);

  for my $v (@$vals_ref) {
    my @spans;
    my $pos = 0;
    my $vlen = length($v);
    while ((my $idx = index($dec, $v, $pos)) >= 0) {
      push @spans, [$idx, $idx + $vlen];
      $pos = $idx + $vlen;
    }
    if (@spans) {
      $line = ef_replace_spans($line, $ostart, $oend, \@spans);
      $cnt += scalar(@spans);
      ($dec, $ostart, $oend) = ef_decode_with_map($line);
    }
  }

  {
    my @spans;
    while ($dec =~ /\b(Bearer\s+)([A-Za-z0-9._~+\/=-]+)/gi) {
      push @spans, [$-[2], $+[2]];
    }
    if (@spans) {
      $line = ef_replace_spans($line, $ostart, $oend, \@spans);
      $cnt += scalar(@spans);
      ($dec, $ostart, $oend) = ef_decode_with_map($line);
    }
  }

  {
    my @spans;
    while ($dec =~ /(?i)(?:gho_|ghp_|github_pat_)[A-Za-z0-9_]{10,}|AKIA[0-9A-Z]{16}/g) {
      push @spans, [$-[0], $+[0]];
    }
    if (@spans) {
      $line = ef_replace_spans($line, $ostart, $oend, \@spans);
      $cnt += scalar(@spans);
      ($dec, $ostart, $oend) = ef_decode_with_map($line);
    }
  }

  {
    my @spans;
    while ($dec =~ /(?i)(\b(?:Password|User\s+ID)\s*=\s*["']?)([^;"'\r\n]+)(?=["']?\s*;)/g) {
      next if $2 eq "[EF-MASKED]";
      push @spans, [$-[2], $+[2]];
    }
    if (@spans) {
      $line = ef_replace_spans($line, $ostart, $oend, \@spans);
      $cnt += scalar(@spans);
      ($dec, $ostart, $oend) = ef_decode_with_map($line);
    }
  }

  {
    my @spans;
    while ($dec =~ /$key_re/g) {
      next if $2 eq "[EF-MASKED]";
      push @spans, [$-[2], $+[2]];
    }
    if (@spans) {
      $line = ef_replace_spans($line, $ostart, $oend, \@spans);
      $cnt += scalar(@spans);
    }
  }

  return ($line, $cnt);
}
EF_PERL_EOF

ef_mask() {
  local count_file=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --count-file) count_file="${2:?--count-file requires a value}"; shift 2 ;;
      *) echo "Unknown ef_mask argument: $1" >&2; return 2 ;;
    esac
  done

  local tmp_cnt=""
  if [ -n "$count_file" ]; then
    tmp_cnt="$count_file"
  else
    tmp_cnt="$(mktemp "${TMPDIR:-/tmp}/ef-mask-cnt.XXXXXX")"
  fi

  EF_INT_VALS_HEX="${_EF_SECRET_VALS_HEX}" \
  EF_INT_NAMES_HEX="${_EF_SECRET_NAMES_HEX}" \
  EF_INT_CNT_FILE="$tmp_cnt" \
  perl -e "$_EF_PERL_MASK_HELPERS"'
    use strict; use warnings;
    $| = 1;
    my @vals = map { pack("H*", $_) } grep { length($_) } split(/:/, $ENV{EF_INT_VALS_HEX} // "");
    my @names = map { pack("H*", $_) } grep { length($_) } split(/:/, $ENV{EF_INT_NAMES_HEX} // "");
    my $custom_alt = @names ? "|" . join("|", map { quotemeta($_) } @names) : "";
    my $key_re = qr/(?i)((?:[A-Za-z0-9_.-]*(?:password|pwd|key|token|secret)$custom_alt)(?:\\?["'\''])?\s*[=:]\s*(?:\\?["'\''])?)((?:(?!\\["'\''])[^\s;"'\''&,])+)/;

    my $total = 0;
    while (my $line = <STDIN>) {
      my ($masked, $n) = ef_mask_line($line, \@vals, $key_re);
      $total += $n;
      print $masked;
    }

    if (open my $cfh, ">", $ENV{EF_INT_CNT_FILE}) {
      print $cfh "$total\n";
      close $cfh;
    }
  '
  local rc=$?
  if [ -f "$tmp_cnt" ]; then
    _EF_LAST_MASK_COUNT="$(tr -d '[:space:]' < "$tmp_cnt")"
    [ -n "$_EF_LAST_MASK_COUNT" ] || _EF_LAST_MASK_COUNT=0
    if [ -z "$count_file" ]; then
      rm -f -- "$tmp_cnt"
    fi
  fi
  return $rc
}

ef_mask_string() {
  local input="$1"
  local ext_cnt_file="${2:-}"
  local tmp_out tmp_cnt
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/ef-mask-str.XXXXXX")"
  tmp_cnt="$(mktemp "${TMPDIR:-/tmp}/ef-mask-cnt.XXXXXX")"
  printf '%s' "$input" | ef_mask --count-file "$tmp_cnt" > "$tmp_out"
  _EF_LAST_MASK_COUNT="$(tr -d '[:space:]' < "$tmp_cnt")"
  [ -n "$_EF_LAST_MASK_COUNT" ] || _EF_LAST_MASK_COUNT=0
  if [ -n "$ext_cnt_file" ]; then
    printf '%s\n' "$_EF_LAST_MASK_COUNT" > "$ext_cnt_file"
  fi
  cat "$tmp_out"
  rm -f -- "$tmp_out" "$tmp_cnt"
}

ef_scan() {
  local repo_root="${1:?repo_root required}"
  local card_id="${2:?card_id required}"
  local harness_log_dir="${3:-$repo_root/.agent-pack/logs/$card_id}"

  _EF_SCAN_STATUS="clean"
  _EF_SCAN_FINDINGS=()
  _EF_SCAN_UNSCANNED=()

  local report
  report="$(EF_INT_VALS_HEX="${_EF_SECRET_VALS_HEX}" \
    EF_INT_NAMES_HEX="${_EF_SECRET_NAMES_HEX}" \
    perl -MFile::Find -MFile::Spec -MCwd=abs_path -e "$_EF_PERL_MASK_HELPERS"'
      use strict; use warnings;
      my ($repo, $card, $logdir) = @ARGV;
      my $repo_abs = abs_path($repo) // File::Spec->rel2abs($repo);
      $repo_abs =~ s/\/+$//;

      my @vals = map { pack("H*", $_) } grep { length($_) } split(/:/, $ENV{EF_INT_VALS_HEX} // "");
      my @names = map { pack("H*", $_) } grep { length($_) } split(/:/, $ENV{EF_INT_NAMES_HEX} // "");
      my $custom_alt = @names ? "|" . join("|", map { quotemeta($_) } @names) : "";
      my $key_re = qr/(?i)((?:[A-Za-z0-9_.-]*(?:password|pwd|key|token|secret)$custom_alt)(?:\\?["'\''])?\s*[=:]\s*(?:\\?["'\''])?)((?:(?!\\["'\''])[^\s;"'\''&,])+)/;

      my @roots = (
        $logdir,
        File::Spec->catdir($repo, ".agent-pack", "evidencias", $card),
        File::Spec->catdir($repo, ".agent-pack", ".runtime")
      );
      my %seen;
      my @files;
      for my $r (@roots) {
        next unless -d $r;
        find({
          wanted => sub {
            return unless -f $_;
            my $p = abs_path($_) // File::Spec->rel2abs($_);
            return if $seen{$p}++;
            push @files, $p;
          },
          no_chdir => 1
        }, $r);
      }

      @files = sort @files;
      for my $file (@files) {
        my $rel = $file;
        if (index($file, "$repo_abs/") == 0) {
          $rel = substr($file, length($repo_abs) + 1);
        }
        open my $fh, "<:raw", $file or next;
        local $/ = undef;
        my $raw = <$fh>;
        close $fh;
        $raw = "" unless defined $raw;

        if (index($raw, "\0") >= 0) {
          print "UNSCANNED\t$rel\n";
          next;
        }

        my $count = 0;
        my $out = "";
        my @lines = split(/(?<=\n)/, $raw, -1);
        for my $line (@lines) {
          next unless length($line);
          my ($masked, $n) = ef_mask_line($line, \@vals, $key_re);
          $count += $n;
          $out .= $masked;
        }

        if ($count > 0) {
          my ($vol, $dir, $base) = File::Spec->splitpath($file);
          my $tmp = File::Spec->catpath($vol, $dir, ".ef-scan-tmp.$$." . $base);
          my $mode = (stat($file))[2];
          open my $wfh, ">:raw", $tmp or die "Cannot write temp file $tmp: $!";
          print $wfh $out;
          close $wfh;
          chmod($mode & 07777, $tmp) if defined $mode;
          rename($tmp, $file) or die "Cannot replace $file: $!";
          print "FINDING\t$rel\t$count\n";
        }
      }
    ' "$repo_root" "$card_id" "$harness_log_dir")" || return 2

  local tag rest file_rel cnt
  while IFS=$'\t' read -r tag rest cnt; do
    [ -n "$tag" ] || continue
    case "$tag" in
      UNSCANNED) _EF_SCAN_UNSCANNED+=("$rest") ;;
      FINDING)
        _EF_SCAN_STATUS="SECRET_IN_LOG"
        _EF_SCAN_FINDINGS+=("$rest"$'\t'"$cnt")
        ;;
    esac
  done <<< "$report"

  if [ "$_EF_SCAN_STATUS" = "SECRET_IN_LOG" ]; then
    return 6
  fi
  return 0
}

ef_validate_evidence_markers() {
  local evidence_file="$1"
  [ -f "$evidence_file" ] || return 0
  perl -e '
    use strict; use warnings;
    my ($file) = @ARGV;
    open my $fh, "<:raw", $file or exit 2;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    $data = "" unless defined $data;
    my $b = "<!-- runner:begin -->";
    my $e = "<!-- runner:end -->";
    my @bpos;
    my $idx = 0;
    while ((my $p = index($data, $b, $idx)) >= 0) {
      push @bpos, $p;
      $idx = $p + length($b);
    }
    my @epos;
    $idx = 0;
    while ((my $p = index($data, $e, $idx)) >= 0) {
      push @epos, $p;
      $idx = $p + length($e);
    }
    if (@bpos >= 2 || @epos >= 2) {
      print STDERR "Error: EVIDENCIA.md contains multiple runner markers.\n";
      exit 2;
    }
    if (@bpos != @epos) {
      print STDERR "Error: EVIDENCIA.md contains an unmatched runner marker.\n";
      exit 2;
    }
    if (@bpos == 1 && $epos[0] < $bpos[0]) {
      print STDERR "Error: EVIDENCIA.md has runner:end before runner:begin.\n";
      exit 2;
    }
  ' "$evidence_file"
}

ef_update_evidence_block() {
  local evidence_file="${1:?evidence_file required}"
  local card_id="${2:?card_id required}"
  local mode="${3:?mode required}"
  local body_content="${4:-}"

  ef_validate_evidence_markers "$evidence_file" || return 2
  mkdir -p "$(dirname "$evidence_file")"

  EF_INT_BODY="$body_content" perl -MFile::Spec -e '
    use strict; use warnings;
    my ($file, $card, $mode) = @ARGV;
    my $body = $ENV{EF_INT_BODY} // "";
    $body =~ s/\r?\n$//;
    my $b = "<!-- runner:begin -->";
    my $e = "<!-- runner:end -->";

    if (!-f $file) {
      my $out = "# Evidencia de Testes — Card $card\n\n$b\n$body\n$e\n";
      my ($vol, $dir, $base) = File::Spec->splitpath($file);
      my $tmp = File::Spec->catpath($vol, $dir, ".ef-ev-tmp.$$." . $base);
      open my $wfh, ">:raw", $tmp or exit 2;
      print $wfh $out;
      close $wfh;
      rename($tmp, $file) or exit 2;
      exit 0;
    }

    open my $fh, "<:raw", $file or exit 2;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    $data = "" unless defined $data;

    my $eol = ($data =~ /\r\n/) ? "\r\n" : "\n";
    $body =~ s/\r?\n/$eol/g;

    my $bp = index($data, $b);
    my $ep = index($data, $e);
    my $new_data;

    if ($bp >= 0 && $ep >= 0) {
      my $prefix = substr($data, 0, $bp + length($b));
      my $suffix = substr($data, $ep);
      my $inner = substr($data, $bp + length($b), $ep - ($bp + length($b)));
      if ($mode eq "append_line") {
        $inner =~ s/^(\r?\n)+//;
        $inner =~ s/(\r?\n)+$//;
        my $combined = length($inner) ? "$inner$eol$body" : $body;
        $new_data = "$prefix$eol$combined$eol$suffix";
      } else {
        $new_data = "$prefix$eol$body$eol$suffix";
      }
    } else {
      my $sep = "";
      if (length($data)) {
        if ($data =~ /\r?\n$/) {
          $sep = ($data =~ /\r?\n\r?\n$/) ? "" : $eol;
        } else {
          $sep = "$eol$eol";
        }
      }
      $new_data = "$data$sep$b$eol$body$eol$e$eol";
    }

    my ($vol, $dir, $base) = File::Spec->splitpath($file);
    my $tmp = File::Spec->catpath($vol, $dir, ".ef-ev-tmp.$$." . $base);
    open my $wfh, ">:raw", $tmp or exit 2;
    print $wfh $new_data;
    close $wfh;
    rename($tmp, $file) or exit 2;
  ' "$evidence_file" "$card_id" "$mode"
}

ef_extract_evidence_runner_block() {
  local evidence_file="$1"
  [ -f "$evidence_file" ] || return 0
  perl -e '
    use strict; use warnings;
    my ($file) = @ARGV;
    open my $fh, "<:raw", $file or exit 0;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    $data = "" unless defined $data;
    my $b = "<!-- runner:begin -->";
    my $e = "<!-- runner:end -->";
    my $bp = index($data, $b);
    my $ep = index($data, $e);
    if ($bp >= 0 && $ep > $bp) {
      print substr($data, $bp, $ep - $bp + length($e)), "\n";
    }
  ' "$evidence_file"
}

ef_write_test_status() {
  local status_file="${1:?status_file required}"
  local mode="${2:?mode required}" # tester | scan_fail | allow_unvalidated
  shift 2

  mkdir -p "$(dirname "$status_file")"
  local findings_str=""
  if [ "${#_EF_SCAN_FINDINGS[@]}" -gt 0 ]; then
    findings_str="$(printf '%s\n' "${_EF_SCAN_FINDINGS[@]}")"
  fi
  local unscanned_str=""
  if [ "${#_EF_SCAN_UNSCANNED[@]}" -gt 0 ]; then
    unscanned_str="$(printf '%s\n' "${_EF_SCAN_UNSCANNED[@]}")"
  fi

  EF_INT_FINDINGS="$findings_str" \
  EF_INT_UNSCANNED="$unscanned_str" \
  perl -MJSON::PP -MFile::Spec -e '
    use strict; use warnings;
    my ($file, $mode, @kv) = @ARGV;
    my %args;
    while (@kv >= 2) {
      my $k = shift @kv;
      my $v = shift @kv;
      $args{$k} = $v;
    }

    my $obj = {};
    if ($mode ne "tester" && -f $file) {
      if (open my $rfh, "<:raw", $file) {
        local $/ = undef;
        my $raw = <$rfh>;
        close $rfh;
        eval { $obj = JSON::PP->new->utf8->decode($raw); };
        $obj = {} unless ref($obj) eq "HASH";
      }
    }

    my @findings;
    for my $line (split /\n/, $ENV{EF_INT_FINDINGS} // "") {
      next unless length($line);
      my ($f, $c) = split /\t/, $line, 2;
      push @findings, { file => $f, count => int($c // 0) };
    }
    my @unscanned = grep { length($_) } split /\n/, $ENV{EF_INT_UNSCANNED} // "";

    if ($mode eq "tester") {
      $obj->{cardId} = $args{cardId} // "";
      $obj->{demandType} = $args{demandType} // "Feature";
      $obj->{phase} = $args{phase} // "validate";
      $obj->{passed} = ($args{passed} // "false") eq "true" ? JSON::PP::true : JSON::PP::false;
      $obj->{exitCode} = int($args{exitCode} // 1);
      $obj->{evidencePath} = $args{evidencePath} // "";
      $obj->{timestamp} = $args{timestamp} // "";
      $obj->{reason} = (defined $args{reason} && length($args{reason})) ? $args{reason} : undef;
      $obj->{secretScan} = {
        status => $args{scanStatus} // "clean",
        findings => \@findings,
        unscanned => \@unscanned
      };
    } elsif ($mode eq "scan_fail") {
      $obj->{cardId} = $args{cardId} // ($obj->{cardId} // "");
      $obj->{passed} = JSON::PP::false;
      $obj->{reason} = "SECRET_IN_LOG";
      $obj->{evidencePath} //= $args{evidencePath} // "";
      $obj->{timestamp} = $args{timestamp} // ($obj->{timestamp} // "");
      $obj->{secretScan} = {
        status => "SECRET_IN_LOG",
        findings => \@findings,
        unscanned => \@unscanned
      };
    } elsif ($mode eq "allow_unvalidated") {
      $obj->{cardId} = $args{cardId} // ($obj->{cardId} // "");
      $obj->{passed} = exists($obj->{passed}) ? $obj->{passed} : undef;
      $obj->{allowUnvalidated} = JSON::PP::true;
      $obj->{allowUnvalidatedReason} = $args{allowUnvalidatedReason} // "";
      $obj->{allowUnvalidatedAt} = $args{allowUnvalidatedAt} // "";
      $obj->{timestamp} = $args{allowUnvalidatedAt} // ($obj->{timestamp} // "");
    }

    my $json = JSON::PP->new->utf8->canonical->pretty->encode($obj);
    my ($vol, $dir, $base) = File::Spec->splitpath($file);
    my $tmp = File::Spec->catpath($vol, $dir, ".ef-status-tmp.$$." . $base);
    open my $wfh, ">:raw", $tmp or exit 2;
    print $wfh $json;
    close $wfh;
    rename($tmp, $file) or exit 2;
  ' "$status_file" "$mode" "$@"
}

ef_split_args() {
  local raw="$1"
  perl -MText::ParseWords=shellwords -e '
    use strict; use warnings;
    my $s = $ARGV[0] // "";
    my @words = shellwords($s);
    for my $w (@words) {
      $w =~ s/\n/ /g;
      print "$w\n";
    }
  ' -- "$raw"
}

ef_extract_flag_names() {
  local flags=()
  local tok
  for tok in "$@"; do
    case "$tok" in
      -*)
        flags+=("${tok%%=*}")
        ;;
    esac
  done
  if [ "${#flags[@]}" -gt 0 ]; then
    local IFS=,
    printf '%s' "${flags[*]}"
  fi
}

ef_check_agy_effort() {
  local args=("$@")
  local i=0
  local n="${#args[@]}"
  while [ "$i" -lt "$n" ]; do
    local tok="${args[$i]}"
    case "$tok" in
      --effort)
        if [ $((i + 1)) -ge "$n" ] || [ "${args[$((i + 1))]}" != "high" ]; then
          echo "Error: agy harness requires --effort high." >&2
          return 2
        fi
        i=$((i + 2))
        ;;
      --effort=*)
        if [ "${tok#--effort=}" != "high" ]; then
          echo "Error: agy harness requires --effort high." >&2
          return 2
        fi
        i=$((i + 1))
        ;;
      *)
        i=$((i + 1))
        ;;
    esac
  done
  return 0
}
