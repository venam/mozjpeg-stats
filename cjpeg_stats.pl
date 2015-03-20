use warnings;
use strict;


=head1
Program to gather statistics about images size and compression ration of the
mozjpeg library.

It tries to find the best compresssion by doing iterations and asking the user
if he is satisfied of the result.

Deps: feh, wmctrl, ImageMagick
=cut


use Time::HiRes qw( usleep );
use File::Basename;


#Nice Colours
my $HEADER      = "\033[95m";
my $OKBLUE      = "\033[94m";
my $OKGREEN     = "\033[92m";
my $WARNING     = "\033[93m";
my $FAIL        = "\033[91m";
my $ENDC        = "\033[0m";
my $INFO        = $HEADER . "[". $OKBLUE ."*" . $HEADER ."] ". $ENDC;
my $ARROW       = " ". $OKGREEN . ">> ". $ENDC;
my $PLUS        = $HEADER ."[" . $OKGREEN ."+" . $HEADER ."] ". $ENDC;
my $MINUS       = $HEADER ."[". $FAIL ."-". $HEADER ."] ". $ENDC;


my @children;


sub open_pic {
	my ($pic) = @_;
	my $child = fork;
	defined $child or die "$MINUS can't fork: $!\n";
	unless ($child) {
		#print "$^X\n";
		exec "feh $pic";
	}
	else {
		push @children, $child;
	}
}


sub clean_children {
	while (@children) {
		my $child = pop @children;
		kill "KILL", $child;
	}
}


sub align_pic {
	my ($pic, $position) = @_;
	usleep(50000); #nasty hack
	system( "wmctrl -R '$pic' -e '0,$position,-1,-1,-1'" );
}


sub ask {
	print "$INFO Is it a satisfying compression? [Y/N]\n";
	print "$ARROW";
	my $answer = <STDIN>;
	if ($answer =~ /Y/i) {
		print "$PLUS Your answer was positive. Trying with higher value\n";
	}
	else {
		print "$MINUS Your answer was negative. Using last best compression\n";
	}
	clean_children;
}


sub compress {
	my ($original, $ratio) = @_;
	my $compressed_image_name = get_compressed_file_name($original, $ratio);
	if (-f $compressed_image_name) {
		print "$MINUS file name for compressed image already exist\n";
		return;
	}
	my $command = qq# cjpeg -quality $ratio $original > $compressed_image_name  #;
	print "$command\n";
	system($command);
}


sub get_info_about_file { return fileparse($_[0], qr/\.[^.]*/); }


sub get_compressed_file_name {
	my ($original, $ratio) = @_;
	my ($file, $dir, $ext) = get_info_about_file($original);
	return $dir.$file.'_'.$ratio.'.jpg';
}


sub check_change_extension {
	#targa, bmp, ppm, and jpg/jpeg
	my ($original) = @_;
	my $new_file = $original;
	my @allexts = qw( .targa .bmp .ppm .jpg .jpeg .gif .jpx .jb2 .ico .png .psd .pspimage .thm .tif .yuv );
	my @exts = @allexts[0..4];
	my ($dir, $file, $ext) = get_info_about_file($original);
	if (!grep (/$ext/i, @exts)){
		if (! grep (/$ext/i, @allexts)) {
			print "$MINUS Unsuported image extension\n";
			exit 1;
		}
		else {
			#TODO convert it to jpg with imagemagick `convert`
		}
	}
	return $new_file;
}


exit unless (defined $ARGV[0] && -f -r -B $ARGV[0]);
my $pic = "$ARGV[0]";
check_change_extension($pic);
compress($pic, 30);
open_pic($pic);
open_pic(get_compressed_file_name($pic,30));
align_pic($pic, 500);
ask;
