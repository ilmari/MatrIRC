package Net::Async::IRC::TS6;

use strict;
use warnings;
use 5.010; # //

use Carp;

# We need to use C3 MRO to make the ->isupport etc.. methods work properly
use mro 'c3';
use base qw( Net::Async::IRC::Protocol Protocol::IRC::TS6 );

sub new {
    my $class = shift;
    my %args = @_;

    my $on_closed = delete $args{on_closed};

    return $class->next::method(
        %args,

        on_closed => sub {
            my $self = shift;

            foreach my $f (@{delete($self->{on_login_f}) // []}) {
                $f->fail( "Closed" );
            }

            $on_closed->( $self ) if $on_closed;
        },
    );
}

sub configure {
    my $self = shift;
    my %args = @_;

    for (qw( name sid pass servername serverpass )) {
        $self->{$_} = delete $args{$_} if exists $args{$_};
    }

    $self->next::method( %args );
}

sub login {
    my $self = shift;
    my %args = @_;

    my $sid  = delete $args{sid}  || $self->{sid}  or croak "Need a server ID";
    my $name = delete $args{name} || $self->{name} or croak "Need a server name";
    my $pass = delete $args{pass} || $self->{pass} or croak "Need a server password";

    my $on_login = delete $args{on_login};
    !defined $on_login or ref $on_login eq "CODE" or
        croak "Expected 'on_login' to be a CODE reference";

    return $self->{login_f} ||= $self->connect( %args )->then( sub {
        $self->send_message(PASS   => undef, $pass, 'TS', 6, $sid);
        $self->send_message(SERVER => undef, $name, 1, ':NaIRC server');
        $self->send_message(SVINFO => undef, 6, 6, 0, time);

        my $f = $self->loop->new_future;

        push @{ $self->{on_login_f} }, $f;
        $f->on_done( $on_login ) if $on_login;

        return $f;
    })->on_fail( sub { undef $self->{login_f} } );
}

sub _set_server_info {
    my ($self, $hints, @keys) = @_;

    @{$self->{server}}{@keys} = @{$hints}{@keys};
}

sub _server_info {
    my ($self, $key) = @_;

    return $self->{server}{$key};
}

sub on_message_PASS {
    my ($self, $message, $hints) = @_;

    $self->_set_server_info($hints, qw(sid password));

    return 0;
}

sub _fatal {
    my ($self, $message) = @_;

    warn "Fatal error: $message\n";
    $self->send_message(ERROR => undef, "Closing Link: ($message)");
    $self->close_now;
}

sub on_message_CAPAB {
    my ($self, $message, $hints) = @_;

    $self->_set_server_info($hints, qw(caps));

    return 0;
}

sub on_message_SERVER {
    my ($self, $message, $hints) = @_;

    $self->_set_server_info($hints, qw(name description));

    if (defined $self->{servername} and $self->_server_info('name') ne $self->{servername}) {
        $self->_fatal("Invalid server name");
    }

    if (defined $self->{serverpass} and $self->_server_info('password') ne $self->{serverpass}) {
        $self->_fatal("Invalid password");
    }

    return 0;
}

sub on_message_SVINFO {
    my ($self, $message, $hints) = @_;

    $self->_set_server_info($hints, qw(version min_version ts));

    foreach my $f (@{delete($self->{on_login_f}) // []}) {
        $f->done( $self );
    }

    return 0;
}

1;
