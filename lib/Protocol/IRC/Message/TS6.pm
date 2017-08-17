package Protocol::IRC::Message::TS6;

use strict;
use warnings;
use 5.010; # //

use base qw( Protocol::IRC::Message );

my %ARG_NAMES = (
    JOIN => { ts => 0 , target_name => 1 },
    PASS => { password => 0, version => 2, sid => 3 },
    CAPAB => { caps => '0@' },
    SERVER => { name => 0, hopcount => 1, description => 2 },
    SVINFO => { version => 0, min_version => 1, ts => 3 },
    SID => { name => 0, hopcount => 1, sid => 2, gecos => 3 },
    UID => {
        nick => 0, hopcount => 1, ts => 2, umodes => 3,
        username => 4, hostname => 5, ip => 6, uid => 7, gecos => 9,
    },
    SJOIN => { ts => 0, target_name => 1, modes => 2, uids => '3@' },
    BMASK => { ts => 0, target_name => 1, type => 2, masks => '3@' },
    TMODE => { ts => 0, target_name => 1, mode => '2..' },
    PING => { text => 0, source => 0, dest => 1 },
    PONG => { text => 0, source => 0, dest => 1 },
    NICK => { old_nick => "pn",  new_nick => 0, ts => 1 },
    KILL => { target_name => 0, path => 1 },
);

sub _arg_names {
    my ($self) = shift;
    return (
        $self->SUPER::_arg_names,
        %ARG_NAMES,
    );
}

sub new_from_named_args {
    my ($class, $command, %args) = @_;

    my $argnames = $class->arg_names($command);

    $args{ts} //= time if exists $argnames->{ts};

    return $class->next::method($command, %args);
}

=head2 prefix_split

   ( $nick, $ident, $host ) = $message->prefix_split

Splits the prefix into its nick, ident and host components. If the prefix
contains only a hostname (such as the server name), the first two components
will be returned as C<undef>.

=cut

sub prefix_split {
    my $self = shift;
    my $prefix = $self->prefix;

    if ($prefix =~ /(([0-9][A-Z0-9]{2})[A-Z][A-Z0-9]{5})/) {
        return ($1, undef, $2);
    }
    else {
        return (undef, undef, $prefix);
    }
}

1;
