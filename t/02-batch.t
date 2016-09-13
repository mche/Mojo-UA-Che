use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;

my $base_url = 'https://metacpan.org/pod/';
my @modules = qw(Scalar::Util Mojolicious Mojo::Pg Test::More DBI DBD::Pg DBIx::Mojo::Template AnyEvent);
my $limit = 3;
my $total = @modules;

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at('ul.slidepanel > li time[itemprop="dateModified"]')->text;
  
}

sub test {
  my ($che, @modules) = @_;
  my @done = ();

  while (@modules) {
    my @mod = splice @modules, 0, $limit;
    say STDERR "BATCH: @mod";
    my @res = $che->batch(map [get => $base_url.$_], @mod);
    for my $res (@res) {
      my $mod = shift @mod;
      unshift @modules, $mod
        and next
        unless  ref $res;
      push @done, "$mod modified: ".process_res($res);
    }
  }

  say STDERR 'Module ', $_ for @done;

  is scalar @done, $total;
  
}

subtest 'Proxying' => \&test, Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', proxy_module_has=>{max_try=>5, debug=>1,}, debug=>1, cookie_ignore=>1), @modules;

subtest 'Normal' => \&test, Mojo::UA::Che->new(debug=>1, cookie_ignore=>1), @modules;

done_testing();