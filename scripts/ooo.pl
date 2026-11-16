#!/usr/bin/perl
# Land of Ooo stage: half-block pixel art (each cell = 2 stacked pixels, 24-bit colour)
# of Finn, Jake and BMO walking over the hills, redrawn at 8 fps until the pane closes.
# Sized for a 9-row pane (18 px). Run by `ooo.sh pane`; toggled with <prefix> A.
use strict;
use warnings;
use utf8;
use Time::HiRes qw(time sleep);
binmode STDOUT, ':encoding(UTF-8)';

my %pal = (
	W => 'ffffff', s => 'fcd2b0', k => '1d1d1d', r => 'e0464f', b => '5ab4f0', B => '2c4f9e',
	g => '3fa34d', y => 'f7b32b', Y => 'd98e1a', e => 'ffffff', o => 'ffd98a', t => '4fc3a1',
	S => 'c9f5df', R => 'e8505b', L => '4fa3e0', u => 'fff36b',
);

# sprites are left halves mirrored into full rows ('.' is transparent), so they stay symmetric
sub sym { map { $_ . reverse $_ } @_ }

# Finn: bear hat with ears, grin, blue shirt, green backpack straps
my @finn_body = sym(
	'.W...', 'WWW..', 'WWWWW', 'WWsss', 'WWsks', 'WWsss', 'WWskk', 'WWWsr',
	'.WWWW', '.gbbb', 'sgbbb', 's.bbb', '..BBB',
);
my @finn_legs = ([sym('..s..', '.kk..')], [sym('...s.', '..kk.')]);

# Jake: floppy ears, big eyes looking inward, muzzle with nose, smile, jowls
my @jake_head  = sym('...yyy', '.Yyyyy', 'Yyeeyy', 'Yyekyy', '.yyyok', '.yyooo', '.Yyokk', '..Yyoo', '..yyyy');
my @jake_blink = sym('Yyyyyy', 'Yykkyy');
my @jake_legs  = ([sym('..y.y.', '..Y.Y.')], [sym('...y.y', '...Y.Y')]);

# BMO: teal console with a screen face and yellow, red and blue buttons
my @bmo = ('tttttttt', 'tSSSSSSt', 'tSkSSkSt', 'tSSkkSSt', 'tSSSSSSt', 'tttttttt', 'tuttRtLt', 'tttttttt', '.t....t.', 'kk....kk');

my ($w, $h) = (80, 18);
my @px;

sub clear_px { @px = map { [('') x $w] } 1 .. $h }
sub dot {
	my ($x, $y, $c) = @_;
	$px[$y][$x] = $c if $x >= 0 && $x < $w && $y >= 0 && $y < $h;
}
# draw sprite rows with their bottom row on pixel line $base; mirror when facing left
sub sprite {
	my ($x, $base, $flip, @rows) = @_;
	my $top = $base - @rows + 1;
	for my $r (0 .. $#rows) {
		my $line = $flip ? reverse $rows[$r] : $rows[$r];
		my @p = split //, $line;
		for my $i (0 .. $#p) { dot($x + $i, $top + $r, $pal{$p[$i]}) if $p[$i] ne '.' }
	}
}

sub scenery {
	my $s      = shift;
	my $ground = $h - 2;
	# far hills
	for my $x (0 .. $w - 1) {
		my $top = $ground - int(3 + 2 * sin(($x + 7) / 11) + sin($x / 5.3));
		dot($x, $_, '2f6b2a') for $top .. $ground - 1;
	}
	# grass with tufts swaying in the wind
	my $gust = int($s * 10) % ($w + 20) - 10;
	for my $x (0 .. $w - 1) {
		dot($x, $ground, '8ad04f');
		dot($x, $ground + 1, '5aa02c');
		dot($x, $ground - 1, abs($x - $gust) < 3 ? 'c6f68d' : '8ad04f') if ($x * 13) % 7 == 0;
	}
	# twinkling stars
	for my $x (0 .. $w - 1) {
		next if ($x * 37 + 11) % 23;
		my $tw = (int($s * 3) + $x) % 4;
		dot($x, ($x * 7) % 4, $tw == 0 ? 'fff5d6' : $tw == 1 ? '8f84b8' : '4a3f6b');
	}
	# Lady Rainicorn: a wavy rainbow body with a white head and horn, crossing every 25 s
	my $head = $w - int(($s - 25 * int($s / 25)) * 14);
	if ($head > -30) {
		my @rb = qw(ff5f5f f7b32b fff36b 8ad04f 4fa3e0 b48ee8);
		for my $i (0 .. 21) {
			my $yy = int(1 + sin(($head + $i) / 4));
			dot($head + $i, $yy + $_, $rb[$_]) for 0 .. 5;
		}
		sprite($head - 4, int(1 + sin($head / 4)) + 4, 0, '..u.', '.WW.', 'WkWW', 'WWWW', '.WW.');
	}
}

# Finn leads with a two-frame walk and a bounce; Jake trails him, blinks, and every
# 8 s stretches his legs tall; BMO stands to the right
sub party {
	my $s      = shift;
	my $ground = $h - 2;
	my $span   = $w - 40;    # party is 24 px wide and must stay left of BMO
	$span = 1 if $span < 1;
	my $pos  = int($s * 5) % (2 * $span);
	my $flip = $pos >= $span;
	$pos = 2 * $span - $pos if $flip;
	my $left = 2 + $pos;
	my $step = int($s * 5) % 2;

	my ($fx, $jx) = $flip ? ($left, $left + 12) : ($left + 14, $left);
	sprite($fx, $ground - $step, $flip, @finn_body, @{ $finn_legs[$step] });

	my $ph      = $s - 8 * int($s / 8);
	my $stretch = $ph < 4 ? int(4 * sin($ph / 4 * 3.14159)) : 0;
	my @legs    = @{ $jake_legs[$step] };
	my @body    = (@jake_head, ($legs[0]) x ($stretch + 1), $legs[1]);
	@body[2 .. 3] = @jake_blink if int($s * 8) % 24 < 2;
	sprite($jx, $ground - ($stretch ? 0 : $step), $flip, @body);

	sprite($w - 12, $ground, 0, @bmo);
}

sub render {
	my ($out, $fg, $bg) = ("\e[H", '', '');
	for (my $y = 0; $y < $h; $y += 2) {
		for my $x (0 .. $w - 1) {
			my ($t, $b) = ($px[$y][$x], $px[$y + 1][$x]);
			my ($glyph, $f, $k) =
			    $t eq '' && $b eq '' ? (' ', '', '')
			  : $t eq ''             ? ('▄', $b, '')
			  :                        ('▀', $t, $b);
			if ($f ne $fg) { $out .= $f eq '' ? "\e[39m" : sprintf("\e[38;2;%d;%d;%dm", map { hex } unpack '(A2)3', $f); $fg = $f }
			if ($k ne $bg) { $out .= $k eq '' ? "\e[49m" : sprintf("\e[48;2;%d;%d;%dm", map { hex } unpack '(A2)3', $k); $bg = $k }
			$out .= $glyph;
		}
		($fg, $bg) = ('', '');
		$out .= "\e[0m\e[K" . ($y + 2 < $h ? "\n" : '');
	}
	print $out;
}

$| = 1;
print "\e[?25l\e[2J";
my $t0 = time;
for (my $f = 0; ; $f++) {
	if ($f % 16 == 0) {
		my ($rows, $cols) = split ' ', `stty size < /dev/tty`;
		($w, $h) = (($cols || 80), 2 * ($rows || 9));
	}
	my $s = time - $t0;
	clear_px();
	scenery($s);
	party($s);
	render();
	sleep 0.125;
}
