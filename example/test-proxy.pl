use Mojo::Base -strict;
binmode(STDERR, ':utf8');
binmode(STDOUT, ':utf8');
use Mojo::UserAgent;

my $proxy = $ARGV[0]
  or die "usage $0 <proxy> # i.e. http://<ip>:<port> | socks://<ip>:<port>";

my $url = 'https://raw.githubusercontent.com/kraih/mojo/master/lib/Mojo/UserAgent.pm';
my $ua = Mojo::UserAgent->new;
$ua->proxy->http($proxy)->https($proxy); 

blocking();
nonblocking();


sub blocking {
  my $tx = $ua->get( $url);
  my $res = process_tx($tx);
  say "blocking: $res";
}

sub nonblocking {
  my $res;
  $ua->get( $url => sub {
    my ($ua, $tx) = @_;
    $res = process_tx($tx);
    });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  say "nonblocking: $res";
}

sub process_tx {
  my ($tx) = @_;
  my $res = $tx->res;
  
  if (my $err = $tx->error) {
    $res = $err->{code} || $err->{message} || 'unknown error';
    utf8::decode($res);
  }
  
  return $res;
  
}
