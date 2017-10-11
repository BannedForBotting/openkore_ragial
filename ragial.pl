#Openkore ragial by Naozumi2k
package ragial;

use strict;
use Globals;
use Plugins;
use Utils;
use Log qw(message warning error debug);
use IO::Socket;
use URI;
use URI::Escape;

my ($AID, $url, $host, $path, $content, $item_url, $item_price, $check_time);

$check_time = 0;

Plugins::register('ragial', 'check ragial prices', \&on_unload, \&on_unload);

my $hooks = Plugins::addHooks(
		['open_shop', \&shop_open, undef],
		['mainLoop_pre', \&check_timeout, undef]
	);

sub on_unload {
	Plugins::delHook('shop_open', $hooks);
}

sub check_timeout {
	return unless $config{'ragial'} || $check_time;

	if($net->getState == Network::IN_GAME && $shopstarted && timeOut($check_time, $config{'ragial_timeout'})){
		warning "checking ragial prices...\n";
		$check_time = time;
		main::closeShop();
	}
}

sub shop_open {
	my (undef, $items) = @_;

	return unless $config{'ragial'};

	my $sock = new IO::Socket::INET(
		PeerAddr => 'ragi.al',
		PeerPort => 'http(80)',
		Proto => 'tcp');

	$sock->autoflush(1);

	$AID = unpack("V1", $accountID);
	foreach my $item (@{$items}){
		if($item->{name} =~ /\[\d\]/){
			$url = URI->new('http://ragi.al/search/iRO-Odin/'.uri_escape($item->{name}));	
		}else{
			$url = URI->new('http://ragi.al/search/iRO-Odin/"'.uri_escape($item->{name}).'"');
		}
		$host = $url->host;
		$path = $url->path;

		$sock->send(join "\r\n", (
			"GET $path HTTP/1.1",
			"User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
			"Host: $host",
			"Connection: Keep-Alive",
			"Referer: $host",
			"Cache-Control: no-cache",
			"", ""
		));

		sleep(1);

		$sock->recv($content, 1024*1028);
		
		if($content =~ /<a href="(.*)" class="activate_tr"> \Q$item->{name}\E<\/a> <\/td><td class="cnt">\d+<\/td><td class="price (ch|ex)"><a href="(.*)">(.*)z<\/a><\/td>/g){
			$item_url = $3;
			$url = URI->new($item_url);
			$host = $url->host;
			$path = $url->path;

			$sock->send(join "\r\n", (
				"GET $path HTTP/1.1",
				"User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
				"Host: $host",
				"Connection: Keep-Alive",
				"Referer: $host",
				"Cache-Control: no-cache",
				"", ""
			));

			sleep(1);

			$sock->recv($content, 1024*1028);
		
			if($content =~ /<td id="date" class="nm"><a href="http:\/\/ragi\.al\/shop\/iRO-Odin\/(?!$AID)\d+">Vending Now<\/a><\/td><td id="amt">\d+x<\/td><td id="pc" class="nm"><a href="http:\/\/ragi.al\/shop\/iRO-Odin\/(?!$AID)\d+" class="notip">(\d{1,3}(,\d{3})*(\.\d+)?)z<\/a><\/td>/g){
				$item_price = $1;
				warning "[ragial] ".$item->{name}." is found on price: ".$item_price."z\n";
				$item_price =~ tr/,//d;
				$item->{price} = $item_price - 10;
			}else{
				warning "[ragial] ".$item->{name}." is not found on ragial\n";
			}
		}else{
			warning "[ragial] ".$item->{name}." is not found on ragial\n";
		}
	}
	$check_time = time;
}

return 1;
