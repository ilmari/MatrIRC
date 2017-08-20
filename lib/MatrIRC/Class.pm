package MatrIRC::Class;
use strictures 2;
use Import::Into;
use experimental qw(signatures);
use feature ':all';
use Syntax::Keyword::Try;
use MooX::HandlesVia ();
use true;
use mro ();

sub import ($class) {
    my $target = caller;
    feature->import::into($target, ':all');
    Moo->import::into($target);
    MooX::HandlesVia->import::into($target);
    strictures->import::into({ package => $target, version => 2 });
    experimental->import::into($target, qw(signatures));
    true->import::into($target);
    Syntax::Keyword::Try->import::into($target);
    mro->import::into($target, 'c3');
}

