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
                       bpom_rpo_check_label_design
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Various checker utilities to help with Processed Food Registration (RPO - Registrasi Pangan Olahan) at BPOM',
};

$SPEC{bpom_bpo_check_label_design} = {
    v => 1.1,
    summary => 'Check label design files',
    description => <<'_',

By default will check all files in the current directory, recursively.

Here's what it checks:
- file must be in JPEG format and has name ending in /\.jpe?g$/i
- file must not be larger than 5MB
- image size must not be larger than 2300 x 2300 px
- (WARNING) image should not be smaller than 600 x 600 px

_
    args => {
        files => [
            schema => ['array*', of=>'filename', 'x.perl.default_value_rules' => [['Path::filienames']]],
            req => 1,
        ],
    },
};
sub bpom_bpo_check_label_design {
    require File::MimeInfo::Magic;

    my %args = @_;

    my $i = 0;
    my @errors;
    for my $file (@{ $args{files} }) {
        $i++;
        log_info "[%d/%d] Processing file %s ...", $i, scalar(@{ $args{files} }), $file;
        if ($file =~ /\.jpe?g\z/i) {
            push @errors, {file=>$file, message=>"Filename does not end in .JPG or .JPEG"};
        }
        if (!-r($file)) {
            push @errors, {file=>$file, message=>"File cannot be read"};
            next;
        }
        my $mime_type = File::MimeInfo::Magic::mimetype($file);
        unless ($mime_type eq 'image/jpeg') {
            push @errors, {file=>$file, message=>"File not in JPEG format"};
        }
    }

    [200, "OK", \@errors, {'cmdline.exit_code'=>@errors ? 1:0}];
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
