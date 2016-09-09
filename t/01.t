use Mojo::Base -strict;

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new;

my @modules = qw(Mojolicious Mojo::Pg Mojo::Pg::Che DBI DBD::Pg DBIx::Mojo::Template AnyEvent);
my $base_url = 'https://metacpan.org/pod/';

=pod
my $cb = sub {
  my ($ua, $tx) = @_;
  my $success = $tx->success
    or die $tx->error->{message};
  my $code    = $tx->res->code;
  warn $ua, process_res($tx->res);
  Mojo::IOLoop->stop;
};

#~ my $res = $ua->request('get', $base_url . shift @modules);

#~ warn process_res($res);

$ua->request('get', $base_url . shift @modules, $cb) for 1..3;
Mojo::IOLoop->start;

done_testing();


=cut

my $delay = Mojo::IOLoop->delay;
my $async = 1;

start() for 1..3;

$delay->wait;

sub start {
  my $module = shift @modules
    or return;
  my $url = "$base_url$module";
  #<time datetime="2016-08-29" itemprop="dateModified" class="relatize" title="29 Aug 2016 16:44:18 GMT">Aug 29, 2016</time>
  my $ua = $ua->ua;
  my $end = $delay->begin
    if $async;
  #~ my $ua = $ua->ua;
  #~ push @{$delay->data->{ua}}, $ua;
  my $res = $ua->request('get'=> $url => $async ? sub {
    $end->();
    my ($ua, $tx) = @_;
    die $tx->error->{message}
      if $tx->error;
    #~ say "$module version: ", $version->text;
    warn "$module modified: ", process_res($tx->res), $ua;
    #~ $end->();
    start();
    } : ());
  warn "$module modified: ", process_res($res), $ua
    and start()
    unless $async;
  
}

sub process_res {
  shift->dom->at('ul.slidepanel > li time[itemprop="dateModified"]')->text;
  
}