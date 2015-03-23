use warnings;
use strict;


=head1
Program to gather statistics about images size and compression ration of the
mozjpeg library.

It tries to find the best compresssion by doing iterations and asking the user
if he is satisfied of the result.

Deps: feh, wmctrl, rdjpgcom, ImageMagick
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
	clean_children;
	if ($answer =~ /Y/i) {
		print "$PLUS Your answer was positive. Trying with higher value\n";
		return 1;
	}
	else {
		print "$MINUS Your answer was negative. Using last best compression\n";
		return 0;
	}
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
			$new_file = "$dir$file.jpg";
			system("convert $original $new_file");
		}
	}
	return $new_file;
}


sub get_width_heigth {
	my ($image_location) = @_;
	my $output = qx#rdjpgcom -v $image_location#;
	$output =~ m/(\d+)w \* (\d+)h/;
	my $width = $1+0;
	my $height = $2+0;
	return ($width, $height);
}


sub iterate {
	my ($original, $start, $end, $jump) = @_;
	$original = check_change_extension($original);
	my $should_quit = 0;
	my $counter = $start;
	my $before_last;
	my $compressed;
	until ($should_quit) {
		last if($counter < $end);
		compress($original, $counter);
		open_pic($original);
		align_pic($original,0);
		$compressed = get_compressed_file_name($original, $counter);
		open_pic($compressed);
		align_pic($compressed,900);
		my $answer = ask;
		unless($answer) {
			if(defined $before_last) {
				system("rm $compressed"); 
			}
			else {
				$before_last = $compressed;
			}
			last;
		}
		else {
			system("rm $before_last") if (defined $before_last);
		}
		$counter -= $jump;
		$before_last = $compressed;
	}
	my ($width, $height) = get_width_heigth($before_last);
	#TODO: here save some information about the file in a very readable format
	print "$INFO WIDTH: $width, HEIGHT:$height\n";
}


exit unless (defined $ARGV[0] && -f -r -B $ARGV[0]);
#TODO: take the parameter as command line args
iterate($ARGV[0], 95, 10, 5);
