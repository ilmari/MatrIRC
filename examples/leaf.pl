#!/usr/bin/perl

use strict;
use warnings;

use Devel::Dwarn;
use Data::Dump 'pp';
use Getopt::Long;

BEGIN { $ENV{$_} = 1 for qw(PERL_FUTURE_DEBUG IO_ASYNC_DEBUG) };

use Future::Utils qw( repeat );
use IO::Async::Loop;
use Net::Async::IRC::TS6;

GetOptions(
   'server|s=s' => \my $SERVER,
   'name|n=s'   => \my $NAME,
   'pass|P=s'   => \my $PASS,
   'port|p=i'   => \my $PORT,
   'SSL|S'      => \my $SSL,
) or exit 1;

require IO::Async::SSL if $SSL;

my $loop = IO::Async::Loop->new;

my $SID  //= '1NA';
$NAME //= 'nairc.local';

my $irc = Net::Async::IRC::TS6->new(
   name    => $NAME,
   pass    => $PASS,
   sid     => $SID,
   on_message => sub {
      my ( $self, $command, $message, $hints ) = @_;

      printf "<<%s>>: %s\n", $command, join( " ", $message->args );
      print "| $_\n" for split m/\n/, pp( $hints );

      return 1;
   },
   on_closed => sub { print "Connection closed\n"; $loop->stop; },
);
$loop->add( $irc );

$PORT //= ( $SSL ? 6697 : 6667 );

$irc->login(
   host    => $SERVER,
   service => $PORT,
   ( $SSL ?
      ( extensions => ['SSL'],
        SSL_verify_mode => 0 ) :
      () ),
)->get;

my $UID = 'A' x 6;

my %user = (
    uid => $SID . $UID++,
    nick => 'nairc', gecos => 'NaIRC test',
    username => 'NaIRC', hostname => 'localhost', ip => '127.0.0.1',
    umodes => '+w', hopcount => 1
);

print "Now logged in...\n";

my $stdin = IO::Async::Stream->new_for_stdin( on_read => sub {} );
$loop->add( $stdin );

my $eof;
( repeat {
   $stdin->read_until( "\n" )->on_done( sub {
      ( my $line, $eof ) = @_;
      return if $eof;

      chomp $line;

      if ($line eq 'uid') {
          $irc->send_message(UID => { %user });
      }
      elsif ($line eq 'join') {
          $irc->send_message(JOIN => { uid => $user{uid}, target_name => '#test' });
      }
      else {
          my $message = Protocol::IRC::Message::TS6->new_from_line( $line );
          $irc->send_message( $message );
      }
   });
} while => sub {  !$_[0]->failure and !$eof } )->get;
