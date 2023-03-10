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

our %argspec0plus_filenames = (
    filenames => {
        schema => ['array*', of=>'filename', 'x.perl.default_value_rules' => [['Path::filenames'=>{recursive=>1}]]],
        pos => 0,
        slurpy => 1,
    },
);

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
- type of file must be PDF or image (JPG), other types will generate warnings
- file's mime type and extension must match

_
    args => {
        %argspec0plus_filenames,
    },
};
sub bpom_rpo_check_files {
    require Cwd;
    require File::Basename;
    require File::MimeInfo::Magic;

    my %args = @_;

    my $i = 0;
    my @errors;
    my @warnings;
    my %symlinks; # key=abspath of symlink target, val=(first) link filename

  FILE:
    for my $file (@{ $args{files} }) {
        $i++;
        log_info "[%d/%d] Processing file %s ...", $i, scalar(@{ $args{files} }), $file
            unless $args{_no_log};
        unless (-f $file) {
            push @errors, {file=>$file, message=>"File not found or not a regular file"};
            next;
        }

      CHECK_FILENAME: {
            if ($file =~ /\.[^.]+\./) {
                push @errors, {file=>$file, message=>"Filename contains multiple dots, currently uploadable but not viewable in ereg-rba"};
            }
            if ($file =~ /[^A-Za-z0-9 _.-]/) {
                push @warnings, {file=>$file, message=>"Filename contains symbols, should be avoided to ensure viewable in ereg-rba"};
            }
        }

      CHECK_READABILITY: {
            if (!-r($file)) {
                push @errors, {file=>$file, message=>"File cannot be read"};
                next FILE;
            }
        }

      CHECK_SYMLINK_TARGET: {
            if (-l $file) {
                my $abs_target = Cwd::abs_path(readlink $file);
                log_trace "Symlink target: %s", $abs_target;
                unless ($abs_target) {
                    push @errors, {file=>$file, message=>"Symlink target cannot be made absolute"}; # should not happen if we already check -f $file
                    next FILE;
                }
                if (defined $symlinks{$abs_target}) {
                    push @warnings, {file=>$file, message=>"WARNING: Targets to the same file ($abs_target) as link $symlinks{$abs_target}, probably not what we want"}; # should not happen if we already check -f $file
                    next FILE;
                } else {
                    $symlinks{$abs_target} = $file;
                }
            }
        } # CHECK_SYMLINK_TARGET

      CHECK_SIZE: {
            my $filesize = -s $file;
            if ($filesize > 5*1024*1024) {
                push @errors, {file=>$file, message=>"File size too large (>5M)"};
            }
        } # CHECK_SIZE

      CHECK_TYPE_AND_EXTENSION: {
            # because File::MimeInfo::Magic will report mime='inode/symlink' for symlink
            my $realfile = -l $file ? readlink($file) : $file;
            my $mime_type = File::MimeInfo::Magic::mimetype($realfile);
            if ($mime_type eq 'image/jpeg') {
                push @errors, {file=>$file, message=>"File type is JPEG but extension is not jpg/jpeg"}
                    unless $file =~ /\.(jpe?g)$/i;
            } elsif ($mime_type eq 'application/pdf') {
                push @errors, {file=>$file, message=>"File type is PDF but extension is not pdf"}
                    unless $file =~ /\.(pdf)$/i;
            } else {
                push @errors, {file=>$file, message=>"File type is not JPEG or PDF"};
            }

        } # CHECK_TYPE_AND_EXTENSION

    }

    #use DD; dd \%symlinks;

    [200, "OK", [@errors, @warnings], {'cmdline.exit_code'=>@errors ? 1:0}];
}

$SPEC{bpom_rpo_check_files_label_design} = {
    v => 1.1,
    summary => 'Check label design files',
    description => <<'_',

By default will check all files in the current directory, recursively.

Here's what it checks:
- all the checks by bpom_rpo_check_files()
- file must be in JPEG format and has name ending in /\.jpe?g$/i
- image size must be smaller than 2300 x 2300 px
- (WARNING) image should not be smaller than 600 x 600px

_
    args => {
        %argspec0plus_filenames,
    },
};
sub bpom_rpo_check_files_label_design {
    require File::MimeInfo::Magic;
    require Image::Size;

    my %args = @_;

    my $i = 0;
    my @errors;
    my @warnings;

    my $checkf_res = bpom_rpo_check_files(files => $args{files}, _no_log=>1);
    return [500, "Can't check files with bpom_rpo_check_files(): $checkf_res->[0] - $checkf_res->[1]"]
        unless $checkf_res->[0] == 200;
    #use DD; dd $checkf_res;
    push @errors  , $_ for grep { !/^WARNING:/ } @{ $checkf_res->[2] };
    push @warnings, $_ for grep {  /^WARNING:/ } @{ $checkf_res->[2] };

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
        if ($file =~ /[^A-Za-z0-9 _.-]/) {
            push @warnings, {file=>$file, message=>"Filename contains symbols, should be avoided to ensure viewable in ereg-rba"};
        }
        next unless -r $file;

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
        if ($size_x >= 2300) { push @errors, {file=>$file, message=>"x too large ($size_x), xmax 2300 px"} }
        if ($size_y >= 2300) { push @errors, {file=>$file, message=>"y too large ($size_y), xmax 2300 px"} }
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
