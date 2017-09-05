package MatrIRC::Server;
use List::Util qw(uniq);
use Scalar::Util qw(weaken);
use MatrIRC::Class;

extends 'Net::Async::IRC::TS6';

has peers => (
    is => 'ro',
    default => sub { +{} },
    handles_via => 'Hash',
    handles => {
        peer => 'get',
        add_peer => 'set',
    },
);

has channels => (
    is => 'ro',
    default => sub { +{} },
    handles_via => 'Hash',
    handles => {
        channel => 'get',
        add_channel => 'set',
    },
);

has users => (
    is => 'ro',
    default => sub { +{} },
    handles_via => 'Hash',
    handles => {
        user => 'get',
        add_user => 'set',
    },
);

has nicks => (
    is => 'ro',
    default => sub { +{} },
    handles_via => 'Hash',
    handles => {
        nick => 'get',
        add_nick => 'set',
        del_nick => 'delete',
    },
);

after add_nick => sub ($self, $nick, $user) {
    my $nicks = $self->nicks;
    weaken $nicks->{$nick};
    defined $nicks->{$_} or delete $nicks->{$_} for keys %{$nicks};
};

after add_user => sub ($self, $uid, $user) {
    $self->add_nick($user->{nick}, $user);
};

sub on_message_UID ($self, $message, $hints) {
    if (my $user = $self->user($hints->{uid})) {
        # TODO: TS checking and update
    }
    else {
        $self->add_user($hints->{uid}, $hints);
    }

    return 1;
}

=head2 JOIN

1.

source: user

parameters: '0' (one ASCII zero)

propagation: broadcast

Parts the source user from all channels.

2.

source: user

parameters: channelTS, channel, '+' (a plus sign)

propagation: broadcast

Joins the source user to the given channel. If the channel does not exist yet,
it is created with the given channelTS and no modes. If the channel already
exists and has a greater (newer) TS, wipe all simple modes and statuses and
change the TS, notifying local users of this but not servers (note that
ban-like modes remain intact; invites may or may not be cleared).

=cut

sub on_message_JOIN ($self, $message, $hints) {
    my $name = $hints->{target_name_folded};
    if (my $channel = $self->channel($name)) {
        if ($channel->{ts} > $hints->{ts}) {
            $channel->{modes} = '';
            s/^[^A-Z]+// for @{$channel}{uids};
        }
        $channel->{ts} = $hints->{ts};
        $channel->{uids} = [ uniq @{$channel->{uids}}, $hints->{uid} ];
    }
    else {
        $self->add_channel($name, {
            $hints->%{qw(ts target_name_folded)},
            uids => [ $hints->{uid} ],
        });
    }

    say $self->user($hints->{uid})->{nick}." joined $name";

    return 1;
}

=head2 SJOIN

source: server

propagation: broadcast

parameters: channelTS, simple modes, opt. mode parameters..., nicklist

Broadcasts a channel creation or bursts a channel.

The nicklist consists of users joining the channel, with status prefixes for
their status ('@+', '@', '+' or ''), for example:
'@+1JJAAAAAB +2JJAAAA4C 1JJAAAADS'. All users must be behind the source server
so it is not possible to use this message to force users to join a channel.

The interpretation depends on the channelTS and the current TS of the channel.
If either is 0, set the channel's TS to 0 and accept all modes. Otherwise, if
the incoming channelTS is greater (newer), ignore the incoming simple modes
and statuses and join and propagate just the users. If the incoming channelTS
is lower (older), wipe all modes and change the TS, notifying local users of
this but not servers (invites may be cleared). In the latter case, kick on
split riding may happen: if the key (+k) differs or the incoming simple modes
include +i, kick all local users, sending KICK messages to servers.

=cut

sub on_message_SJOIN ($self, $message, $hints) {

    my $name = $hints->{target_name_folded};
    if (my $channel = $self->channel($name)) {
        # TODO: handle update
    }
    else {
        $self->add_channel($name, $hints);
    }

    local $, = ", ";
    say "@{$hints->{uids}} joined $name";

    return 1;
}

sub on_message_NICK ($self, $message, $hints) {
    if (my $user = $self->user($hints->{uid})) {
        $self->del_nick($user->{nick});
        $user->@{qw(ts nick)} = $hints->@{qw(ts new_nick)};
        $self->add_user($user); # updates nick
    }

    return 1;
}

=head2 SID

source: server

propagation: broadcast

parameters: server name, hopcount, sid, server description

Introduces a new server, directly connected to the source of this command.

=cut

sub on_message_SID ($self, $message, $hints) {
    $self->add_peer($hints->{sid}, $hints);

    return 1;
}

