package App::BPOMUtils::RPO::Checker;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter 'import';

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       bpom_rpo_check_label_files_design
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Various checker utilities to help with Processed Food Registration (RPO - Registrasi Pangan Olahan) at BPOM',
};

$SPEC{bpom_rpo_check_files} = {
    v => 1.1,
    summary => 'Check document files',
    description => <<'_',

By default will check all files in the current directory, recursively.

Here's what it checks:
- filename should not contain unsafe symbols
- file must not be larger than 5MB
- file must be readable

_
    args => {
        files => {
            schema => ['array*', of=>'filename', 'x.perl.default_value_rules' => [['Path::filenames']]],
            pos => 0,
            slurpy => 1,
        },
    },
};
sub bpom_rpo_check_files {
    my %args = @_;

    my $i = 0;
    my @errors;
    my @warnings;
    for my $file (@{ $args{files} }) {
        $i++;
        log_info "[%d/%d] Processing file %s ...", $i, scalar(@{ $args{files} }), $file;
        unless (-f $file) {
            push @errors, {file=>$file, message=>"File not found or not a regular file"};
            next;
        }

        if ($file =~ /\.[^.]+\./) {
            push @errors, {file=>$file, message=>"Filename contains multiple dots, currently uploadable but not viewable in ereg-rba"};
        }
        if ($file =~ /[^A-Za-z0-9_.-]/) {
            push @warnings, {file=>$file, message=>"Filename contains symbols, should be avoided to ensure viewable in ereg-rba"};
        }

        if (!-r($file)) {
            push @errors, {file=>$file, message=>"File cannot be read"};
            next;
        }

        my $filesize = -s $file;
        if ($filesize > 5*1024*1024) {
            push @errors, {file=>$file, message=>"File size too large (>5M)"};
        }
    }

    [200, "OK", [@errors, @warnings], {'cmdline.exit_code'=>@errors ? 1:0}];
}

$SPEC{bpom_rpo_check_files_label_design} = {
    v => 1.1,
    summary => 'Check label design files',
    description => <<'_',

By default will check all files in the current directory, recursively.

Here's what it checks:
- file must be in JPEG format and has name ending in /\.jpe?g$/i
- filename should not contain unsafe symbols
- file must not be larger than 5MB
- file must be readable
- image size must not be larger than 2300 x 2300 px
- (WARNING) image should not be smaller than 600 x 600 px

_
    args => {
        files => {
            schema => ['array*', of=>'filename', 'x.perl.default_value_rules' => [['Path::filenames']]],
            pos => 0,
            slurpy => 1,
        },
    },
};
sub bpom_rpo_check_files_label_design {
    require File::MimeInfo::Magic;
    require Image::Size;

    my %args = @_;

    my $i = 0;
    my @errors;
    my @warnings;
    for my $file (@{ $args{files} }) {
        $i++;
        log_info "[%d/%d] Processing file %s ...", $i, scalar(@{ $args{files} }), $file;
        unless (-f $file) {
            push @errors, {file=>$file, message=>"File not found or not a regular file"};
            next;
        }

        unless ($file =~ /\.jpe?g\z/i) {
            push @errors, {file=>$file, message=>"Filename does not end in .JPG or .JPEG"};
        }
        if ($file =~ /\.[^.]+\./) {
            push @errors, {file=>$file, message=>"Filename contains multiple dots, currently uploadable but not viewable in ereg-rba"};
        }
        if ($file =~ /[^A-Za-z0-9_.-]/) {
            push @warnings, {file=>$file, message=>"Filename contains symbols, should be avoided to ensure viewable in ereg-rba"};
        }

        if (!-r($file)) {
            push @errors, {file=>$file, message=>"File cannot be read"};
            next;
        }

        my $filesize = -s $file;
        if ($filesize < 100*1024) {
            push @warnings, {file=>$file, message=>"File size very small (<100k), perhaps increase quality?"};
        } elsif ($filesize > 5*1024*1024) {
            push @errors, {file=>$file, message=>"File size too large (>5M)"};
        }

        # because File::MimeInfo::Magic will report mime='inode/symlink' for symlink
        my $realfile = -l $file ? readlink($file) : $file;
        my $mime_type = File::MimeInfo::Magic::mimetype($realfile);
        unless ($mime_type eq 'image/jpeg') {
            push @errors, {file=>$file, message=>"File not in JPEG format (MIME=$mime_type)"};
        }

        my ($size_x, $size_y) = Image::Size::imgsize($file);
        if ($size_x > 2300) { push @errors, {file=>$file, message=>"x too large ($size_x), max 2300 px"} }
        if ($size_y > 2300) { push @errors, {file=>$file, message=>"y too large ($size_y), max 2300 px"} }
        if ($size_x < 600) { push @warnings, {file=>$file, message=>"WARNING: x too small ($size_x), should be 600+ px"} }
        if ($size_y < 600) { push @warnings, {file=>$file, message=>"WARNING: y too small ($size_y), should be 600+ px"} }
    }

    [200, "OK", [@errors, @warnings], {'cmdline.exit_code'=>@errors ? 1:0}];
}

1;
#ABSTRACT:

=head1 SYNOPSIS


=head1 DESCRIPTION

This distribution includes CLI utilities related to helping with Processed Food
Registration (RPO - Registrasi Pangan Olahan).

# INSERT_EXECS_LIST


=head1 SEE ALSO

L<https://registrasipangan.pom.go.id>

=cut
