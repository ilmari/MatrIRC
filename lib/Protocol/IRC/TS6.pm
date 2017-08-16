package Protocol::IRC::TS6;

use strict;
use warnings;
use 5.010; # //
use base qw( Protocol::IRC::Client ); # XXX

sub message_class {
    require Protocol::IRC::Message::TS6;
    return 'Protocol::IRC::Message::TS6';
}

sub is_nick_me { !!0 }

1;
