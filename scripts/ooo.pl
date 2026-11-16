#!/usr/bin/perl
# Finn & Jake in the Land of Ooo (perl: macOS awk mangles multibyte sprites).
#   ooo.pl status <width>   one row (grass + party) for the tmux status line, 1 fps
#   ooo.pl pane             3 rows (sky, party, grass) redrawn at 8 fps until the pane closes
use strict;
use warnings;
use utf8;
use Time::HiRes qw(time sleep);
binmode STDOUT, ':encoding(UTF-8)';

my $mode = shift // 'pane';
my $w    = 48;
my (@ch, @co);

sub code {
	my $c = shift;
	return "#[fg=#$c]" if $mode eq 'status';
	return sprintf "\e[38;2;%d;%d;%dm", map { hex } unpack '(A2)3', $c;
}
sub blank { @ch = (' ') x $w; @co = ('') x $w }
sub put {
	my ($x, $s, $c) = @_;
	my @a = split //, $s;
	for my $i (0 .. $#a) {
		my $p = $x + $i;
		next if $p < 0 || $p >= $w;
		($ch[$p], $co[$p]) = ($a[$i], $c);
	}
	return scalar @a;
}
sub tint { my ($p, $c) = @_; $co[$p] = $c if $p >= 0 && $p < $w }
sub row {
	my ($out, $last) = ('', '');
	for my $x (0 .. $w - 1) {
		if ($co[$x] ne '' && $co[$x] ne $last) { $out .= code($co[$x]); $last = $co[$x] }
		$out .= $ch[$x];
	}
	return $out;
}

# grass with a gust of wind rippling through it
sub grass {
	my $s    = shift;
	my $gust = int($s * 6) % ($w + 12) - 6;
	my @gp   = split //, 'ʷ ʷ‿ ʷ  ';
	for my $x (0 .. $w - 1) {
		my $g = $gp[$x % @gp];
		if ($g eq 'ʷ' && abs($x - $gust) <= 1) { put($x, 'w', 'c6f68d') }
		else { put($x, $g, $g eq 'ʷ' ? '8ad04f' : '4f7a2e') }
	}
}

# Finn walks with a two-step gait; Jake trails him and shapeshifts every 6 seconds:
# stretchy body, punching arm, tiny Jake, big Jake
sub party {
	my ($s, $speed) = @_;
	my $span = $w - 24;
	$span = 2 if $span < 2;
	my $pos = int($s * $speed) % (2 * $span);
	my $d   = $pos < $span ? 1 : -1;
	$pos = 2 * $span - $pos if $d < 0;
	my $x     = $pos + 3;
	my $step  = int($s * ($mode eq 'pane' ? 4 : 1)) % 2;
	my $finn  = $step ? 'ᕕ( ᐛ )ᕗ' : 'ᕙ( ᐛ )ᕗ';
	my $k     = int(2.5 + 2.5 * sin($s * 2.5));
	my $shape = int($s / 6) % 4;
	my $jake =
	    $shape == 0 ? ($d > 0 ? '∽' . '═' x $k . 'ʕ◕ᴥ◕ʔ' : 'ʕ◕ᴥ◕ʔ' . '═' x $k . '∽')
	  : $shape == 1 ? ($d > 0 ? 'ʕ◕ᴥ◕ʔ' . '━' x $k . '☞' : '☜' . '━' x $k . 'ʕ◕ᴥ◕ʔ')
	  : $shape == 2 ? 'ᵔᴥᵔ'
	  :               'ʕ ◕ ᴥ ◕ ʔ';
	my $draw_finn = sub { my $p = shift; put($p, $finn, 'fff5d6'); tint($p + 1, '4fa3e0'); tint($p + 5, '4fa3e0'); 7 };

	if ($d > 0) {
		put($x - 3, $step ? '·⋆✧' : '⋆·✧', 'b48ee8');
		$x += put($x, $jake, 'f7b32b');
		$x += put($x, ' ', '');
		$draw_finn->($x);
	} else {
		$x += put($x, '✧', 'b48ee8');
		$x += $draw_finn->($x);
		$x += put($x, ' ', '');
		$x += put($x, $jake, 'f7b32b');
		put($x, $step ? '⋆·' : '·⋆', 'b48ee8');
	}
}

# twinkling stars, BMO in the corner, and Lady Rainicorn flying through every 20 s
sub sky {
	my $s = shift;
	for my $x (0 .. $w - 1) {
		next if ($x * 37 + 11) % 23;
		my $tw = (int($s * 3) + $x) % 4;
		put($x, (qw(✦ ⋆ · ·))[$tw], $tw ? '8f84b8' : 'fff5d6');
	}
	my $head = $w - int(($s - 20 * int($s / 20)) * 10);
	if ($head > -10) {
		my @rb = qw(ff5f5f f7b32b fff36b 8ad04f 4fa3e0 b48ee8);
		put($head, '≺', 'fff5d6');
		put($head + $_, '≋', $rb[($_ + int($s * 8)) % 6]) for 1 .. 8;
	}
	put($w - 6, int($s * 8) % 32 < 2 ? '[-‿-]' : '[◕‿◕]', '5fd3b3');
}

if ($mode eq 'status') {
	$w = shift // 48;
	my $t = int time;
	blank(); grass($t); party($t, 1);
	print row(), "\n";
	exit;
}

$| = 1;
print "\e[?25l\e[2J";
my $t0 = time;
for (my $f = 0; ; $f++) {
	if ($f % 16 == 0) { my (undef, $cols) = split ' ', `stty size < /dev/tty`; $w = $cols || 80 }
	my $s = time - $t0;
	blank(); sky($s);        my $r1 = row();
	blank(); party($s, 3);   my $r2 = row();
	blank(); grass($s);      my $r3 = row();
	print "\e[H$r1\e[K\n$r2\e[K\n$r3\e[K\e[0m";
	sleep 0.125;
}
