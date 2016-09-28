use Mojo::Base -strict;
use MIME::Base64;

=pod

curl -vv -A 'Mozilla/5.0 (X11; Linux x86_64; rv:45.7) Gecko/20100101 Firefox/45.7' -H 'Accept-Language: ru-RU,ru;q=0.8,en-US;q=0.5,en;q=0.3' 'http://free-proxy.cz/ru/proxylist/country/US/socks5/uptime/all/1' | less

recapcha на листание, но первую страницу дает

<tr>
<td class = "left"><div class="glass_space"><img class="glass" sr
c="/images/1px.png" width="16" height="16" /> </div> <script type="text/javascript">document.write(Base64.decode("MTIuOC44NC4xNzg="))</script></td>
<td style=""><span class="fport" style=''><script type="text/javascript">document.write(Base64.decode("MjI3MTQ="))</script></span></td>
<td><small>SOCKS5</small></td>
<td class="left"><img src="/flags/blank.gif" class="flag flag-us" alt="США" /> <a href="/ru/proxylist/country/US/all/ping/all">США</a></td>
<td class="small"><small>Michigan</small></td>
<td class="small"><small>Irons</small></td>
<td class="small"><small>Высокая анонимно</small></td>
<td> <i class="icon-black icon-question-sign"></i></td>

<td><small>4.5%</small><div class="progress"><div class="fill" style="width:4%;background-color:red;"></div></div></td>
<td><div style="padding-left:5px"><small>12466 ms</small> <div class="progress"><div class="fill" style="width:2%;background-color:red;;"></div></div></div></td>
<td><small>48 минут назад</small></td>
</tr>

=cut

my @sub_url = qw(speed uptime ping date);# первые страницы разных сортировок
my $re_base64 = qr/Base64\.decode\("(.+)"\)/;
my $headers = {'Accept-Language'=>'ru-RU,ru;q=0.8,en-US;q=0.5,en;q=0.3'}; # !!!!

{
  proxy_handler_has => {
    ua_name => 'Mozilla/5.0 (X11; Linux x86_64; rv:45.7) Gecko/20100101 Firefox/45.7',
    proxy_url => 'http://free-proxy.cz/ru/proxylist/country/US/socks5/',
    list_time_fresh => 3*60*60,
    parse_proxy_url => sub {
      my $self = shift;
      # Concurrent non-blocking requests (synchronized with a delay)
      my %proxy =();
      for my $sub_url (@sub_url) {
        my $tx = $self->ua->get($self->proxy_url."$sub_url/all" => $headers);
        my $err = $tx->error;
        $self->debug_stderr('Повтор ', $tx->req->url)
          and redo
          if $err && $err->{code} eq '401';
        die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $tx->req->url, $err->{code}, $err->{message})
          if $err;
        my $tr = $tx->res->dom->find('#proxy_list tbody tr')
          or die "Не нашел таблицы #proxy_list";
        @proxy{ $tr->map(sub {
          $_->child_nodes # td
            ->slice(0..1)
            ->grep(sub {defined $_})
            ->map( sub { decode_base64(($_->content =~ $re_base64)[0]); })
            ->join(':')
            ->to_string; #$self->debug_stderr($_->tag, "===\n");
            #~ or die "не нашел ячейки строк";
          #~ $self->debug_stderr(@td);
          #~ join ':', map , @td[0..1];
        })->each }++;
      }
      return keys %proxy;
    },
    #~ debug => $ENV{DEBUG},
  },
  #~ debug => $ENV{DEBUG},
  
};

__END__

{
  proxy_handler_has => {
    ua_name => 'Mozilla/5.0 (X11; Linux x86_64; rv:45.7) Gecko/20100101 Firefox/45.7',
    proxy_url => 'http://free-proxy.cz/ru/proxylist/country/US/socks5/',
    list_time_fresh => 3*60*60,
    parse_proxy_url => sub {
      my $self = shift;
      # Concurrent non-blocking requests (synchronized with a delay)
      my %proxy =();
      my $delay = Mojo::IOLoop->delay;
      $delay->steps(
        sub {
          my $delay = shift;
          $self->ua->get($self->proxy_url."$_/all" => $headers => $delay->begin) for @sub_url;
        },
        sub {
          my ($delay, @tx) = @_;
          for my $tx (@tx) {
            my $err = $tx->error;
            die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $tx->req->url, $err->{code}, $err->{message})
              if $err;
            my $tr = $tx->res->dom->find('#proxy_list tbody tr')
              or die "Не нашел таблицы #proxy_list";
            @proxy{ $tr->map(sub {
              $_->children->slice(0,1)->map( sub {$self->debug_stderr($_); decode_base64(($_->content =~ $re_base64)[0])})->join(':')->to_string;
                #~ or die "не нашел ячейки строк";
              #~ $self->debug_stderr(@td);
              #~ join ':', map , @td[0..1];
            })->each }++;
          }
        }
      )->catch(
        sub {
          my ($delay, $err) = @_;
          warn $err; # ошибка логина, выкачки или парсинга
          $delay->emit(finish => 'finish: '. $err);
        }
      )->on(finish =>
        sub {
          my ($delay, @err) = @_;
          die @err if @err;
        }
      );
      $delay->wait;
      die keys %proxy;
    },
    #~ debug => $ENV{DEBUG},
  },
  #~ debug => $ENV{DEBUG},
  
};
