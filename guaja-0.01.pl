# ------------------------------------------------------------------------------------------------------------------------------------
# Copyright (c) 2011, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under the same terms as Perl itself. 
# Please see the LICENSE file included with this project for the terms of the Artistic License under which this project is licensed. 
# -------------------------------------------------------------------------------------------------------------------------------------

#!/usr/local/bin/perl -w

our $VERSION = '0.01';

use strict;

use Getopt::Long;

# variables declaration
#

my ($provider) = '';
my ($operation) = '';
my $ispfile;
my @ispcond;
my $ispmin;
my $megabit;
my $ispmprice;
my $ispxprice;
my $mrtgfile;
my @isptraf;
my $ispinc;
my $ispout;
my $value;
my $peer1;
my $peer2;
my $peer3;
my $mrtgloc;
my @tottraf;
my $tot;
my @peertraf; 
my @fpeertraf;
my $per;
my $peering;
my $tpeerinc;
my $paid;
my $totalprice;
my $extravalue;
my $totinc;
my $totout;
my $perinc;
my $tpeerout;
my $peeringperc;
my $paidperc;
my $megprice;

GetOptions('provider=s' => \$provider, 'operation=s' => \$operation);

# This program shows connectivity and downtime costs for the circuits we have
# as well as peering savigns for the peering circuits we have
# options: 
# providers: isp1 and isp2 
# operation: saving, percentage, total cost, downtime costs 
#


sub print_results {
  my($usd,$usdval);
  open(USD,"<$mrtgloc/usd.txt") || die "cannot read from usd.txt!";   # value of the dolar 
  while(<USD>) {  # open the mrtg file for reading the firt line
     $usd = $_;
  }
  $usdval = $_[0] / $usd; 
  printf ("%3.2f\n",$_[0]);
  printf ("%3.2f\n",$usdval);
  print "24h\n";
  print "Meg in BRL and USD for $provider\n";
  close (USD);
}


sub isp_calculation {
  my ($paidvalue);
  if ($ispfile) { 
    open(ISP,"<$ispfile") || die "cannot read from  $ispfile";  # file containing megabit price and min commitment
    while(<ISP>) { #  open the isp file for reading the isp conditions
      @ispcond = split(/ /);
      $ispmin = $ispcond[0];     # minimum commitment in Mbps
      $ispmin = $ispmin * $megabit;  # minimum commitments in real Mbps
      $ispmprice = $ispcond[1];    # price for the minimum commmitment
      $ispxprice = $ispcond[2];    # megabit price for the exceding bandwidth
    }
  }
  open(MRTG,"<$mrtgfile") || die "cannot read from the file $mrtgfile"; # mrtg file containing ISP data
  while(<MRTG>) {  # open the mrtg file for reading the firt line
     @isptraf = split(/ /);                                
     $ispinc = $isptraf[3];
     $ispout = $isptraf[4];
     if ($isptraf[4]) { 
      last;
     } 
  }
  if ($ispout > $ispinc) {
      $paidvalue = cal_bandwidth($ispout*8);  # call the function transforming bytes in bits
  } else {
     $paidvalue = cal_bandwidth($ispinc*8);   # the same here
  }
  return $paidvalue;
  close (ISP);
  close (MRTG);
}

sub default_transit_cost {
   my ($totalprice);   # local variable 
   $_[0] = $_[0] / $megabit;  # get the price per megabit
   $totalprice = $value * $ispxprice;  # multiply the peering traffic by the default provider
   return $totalprice;
}

sub cal_bandwidth {  # bandwidth calculation
   my($totalprice);
   $value = $_[0]; # value is the amount of bits  
   if (($provider =~ /isp1/i) || ($provider =~ /isp2/i) || ($provider =~ /isp3/i) || ($provider =~ /paid-peer1/i) ) {  # paid providers 
      if ($value >= $ispmin) {  # if we pushed beyond the minimum comitmment
        $extravalue = $value - $ispmin;   # how much beyond the minimum 
        $extravalue = $extravalue / $megabit; 
        $extravalue = $extravalue * $ispxprice;    # price for the extra megabit
        $totalprice = $extravalue + $ispmprice;    # total price
      }  
      else {
        $totalprice = $ispmprice;   # if we did not push beyond the minimum
      }    
   }
   elsif (($megprice) && (($provider =~ /all/i) || ($operation =~ /megabit/i))) { # to calculate megabit price  
        $totalprice = $megprice / ($value/$megabit); 
        return $totalprice;
   }
   elsif (($provider =~ /Peering/i) || ($provider =~/all/i) || ($provider =~/peer3/i) ||  ($provider =~/isp1/i) || ($operation =~ /saving/i)) { 
     open(TIP,"<$mrtgloc/peer3-br.txt") || die "cannot read from  peer3.txt";  # peer3  cost file this is for the metro ethernet cost
     open(IMP,"<$mrtgloc/peer3-br2.txt") || die "cannot read from peer32.txt!";   # metro ethernet cost for port 2 
     open(TEK,"<$mrtgloc/isp1-port.txt") || die "cannot read from isp1-port.txt!";  # isp1: switch port cost      o
     while(<TIP>) { # open the peer3-br cost1 file 
       $peer1 = $_;
     } 
     while(<IMP>) {  # open peer3-br2 cost2 file 
       $peer2 = $_;
     }   
     while(<TEK>) { # open isp1 cost file
       $peer3 = $_;                         
     } 
    if (($operation =~ /total/i) || ($operation =~ /megabit/i) ) {  # if the operation is to calculate the total cost of bandwidth
         $totalprice = $peer1+$peer2+$peer3;   # sum all the costs for peering 
     }
     elsif ($provider =~ /all/i)  { # if the operaition is to calculate the savings or outages of peering connections 
      $totalprice = default_transit_cost($value); 
      if ($operation =~ /saving/i) {   
         $totalprice = $totalprice -($peer1+$peer2+$peer3); # reduce the costs of pushing the bandwidth trough  
      }                                                     # a paid provider minus the costs of the peering connections
      if ($operation =~ /downtime/i) {  # if we want to calculate the costs for all peering circuits outage 
         $totalprice = $totalprice+$peer1+$peer2+$peer3;  # sum the pushed bandwidth plus the costs of peering circuits connections 
      }
    } 
     elsif ($provider =~ /peer3/i) {     #if we want to calculate the amount saved by peer3 peering connections
      $totalprice = default_transit_cost($value); #send the amount of bits to calculate transit trough isp1 
      if ($operation =~ /saving/i) { # this is if we want to know how much we are saving trough this circuit 
         $totalprice = $totalprice -$peer1;    # reduce the amount of paid bandwidth saved minus connection costs
      }
      if ($operation =~ /downtime/i) {  # if we want to calculate the costs for this circuit outage 
         $totalprice = $totalprice + $peer1; # sum the costs of default paid traffic plus the peering circuit cost  
      }
     }    
     elsif ($provider =~ /isp1/i) {  # if we want to calculate the amount saved by isp1 peering connections
      $totalprice = default_transit_cost($value);  # send the amount of bits to calculate paid transit trough isp1  
      if ($operation =~ /saving/i) {  # this is if we want to know how much we are saving trough this circuit
         $totalprice = $totalprice -($peer2+$peer3); # same here, bandiwtdth saved minus connection costs
      }
      if ($operation =~ /downtime/i) {
         $totalprice = $totalprice+$peer2+$peer3; # same here, bandiwtdth saved plus peering connection costs 
      } 
     }
     else {       # this is to calculate the megabit cost of the peering connections only 
         $totalprice = ($peer1+$peer2+$peer3)/($value/$megabit);  
     } 
   }
   return $totalprice;
   close (TIP);
   close (IMP);
   close (TEK); 
}


sub traffic_percent {
  my($freepeering);
  my($paidpeering); 
  my($ftpeerinc);
  my($ftpeerout);
 
  open(MRTG1,"<$mrtgloc/tot-trafi.log") || die "cannot read from file "; # mrtg file containing total traffic data
  while(<MRTG1>) {  # open the mrtg file for reading the firt line
     @tottraf = split(/ /);
     $totinc = $tottraf[3];
     $totout = $tottraf[4];
     if ($tottraf[4]) {
      last;
     }
  }
  open(MRTG2,"<$mrtgloc/tot-pe.log") || die "cannot read from file total-pe.log"; # mrtg file containing total peering data
  while(<MRTG2>) { # open the mrtg file for reading the firt line
     @peertraf = split(/ /);
     $tpeerinc = $peertraf[3];
     $tpeerout = $peertraf[4];
     if ($peertraf[4]) {
      last;
     }
  }   
  $peeringperc = ($tpeerout *100) / $totout;
  $paidperc = 100 - $peeringperc; 
  if ($operation =~ /percentagep/i) {  # if the option is to calculate the percentage of free versus paid peering 
     open(MRTG3,"<$mrtgloc/file1.log") || die "cannot read from file file1.log"; # mrtg file containing total free peering data  
     while(<MRTG3>) { # open the mrtg file for reading the firt line
        @fpeertraf = split(/ /);
         $ftpeerinc = $fpeertraf[3];
         $ftpeerout = $fpeertraf[4];
         if ($fpeertraf[4]) {
           last;
         }
      }
      $freepeering = ($ftpeerout *100) / $totout;
      $paidpeering = $peeringperc - $freepeering;
      printf ("%2.2f\n",$freepeering);
      printf ("%2.2f\n",$paidpeering);
      print "24h\n";
      print "Percentage of free peering versus paid peering\n";
      close (MRTG3);    
  } 
  else { 
     printf ("%2.2f\n",$peeringperc);
     printf ("%2.2f\n",$paidperc);
     print "24h\n";
     print "Percentage of peering and paid traffic\n";  
     close (MRTG1);
     close (MRTG2);
  }
}



$mrtgloc = "/home/mrtg/data/user/totals";
$megabit = 1024 * 1024;
     

if (($provider =~ /isp1/i) && ($operation =~ /price/i)) { # calculates costs for provider tivit and operation is price
   $ispfile = "$mrtgloc/isp1-t.txt";    # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/tot-isp1.log";   #file containing the total megabit for this ISP 
   $totalprice = isp_calculation();
   print_results($totalprice); 
} elsif (($provider =~ /isp2/i) && ($operation =~ /price/i))  { # is provider  isp2 and operation is cost 
   $ispfile = "$mrtgloc/isp2.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/isp2.log";    #file containing the total megabit for this ISP  
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif (($provider =~ /isp3/i) && ($operation =~ /price/i))  { # is provider  isp3 and operation is cost
   $ispfile = "$mrtgloc/isp3.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/router2_ge.log";    #file containing the total megabit for this ISP
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif (($provider =~ /paid-peer1/i) && ($operation =~ /price/i))  { # is provider  paid-peer and operation is cost
   $ispfile = "$mrtgloc/paid-peer1.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/router1_fe.log";    #file containing the total megabit for this ISP
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif ($provider =~ /Peering/i)  {   # this is for calculating cost per megabit of all peering connections 
   $mrtgfile = "$mrtgloc/tot-pe.log";  #  
   $ispfile = ""; 
   $totalprice = isp_calculation(); 
   print_results($totalprice);
} elsif (($provider =~ /isp1/i) && ($operation =~ /saving/i)) {  #calculation of savings due to peering connections trough peer1 
   $mrtgfile = "$mrtgloc/tot-peer1.log";   # file containing total megabit for this IX
   $ispfile = "$mrtgloc/isp1-t.txt";    # file containing costs for this ISP
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif (($provider =~ /peer3/i) && ($operation =~ /saving/i)) { # calculation of savings due to peering trough peer3 
   $mrtgfile = "$mrtgloc/router2_ge.log";  # file containing the total megabit for this IX
   $ispfile = "$mrtgloc/isp1-t.txt";      #file containing connection costs for this IX
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif ($operation =~ /total/i) {  # total cost of the bandwidth in the moment
   $ispfile = "$mrtgloc/isp1-t.txt";
   $mrtgfile = "$mrtgloc/isp1.log";
   $provider = "isp1";
   $totalprice = isp_calculation();
   $ispfile = "$mrtgloc/isp2.txt";   
   $mrtgfile = "$mrtgloc/isp2.log";
   $provider = "isp2";
   $totalprice = $totalprice + isp_calculation();
   $ispfile = "$mrtgloc/isp3.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/router2_ge.log";    #file containing the total megabit for this ISP
   $provider = "isp3";
   $totalprice = $totalprice + isp_calculation();
   $ispfile = "$mrtgloc/paid-peer1.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/router1.log";    #file containing the total megabit for this ISP
   $provider = "paid-peer1";
   $totalprice = $totalprice + isp_calculation(); 
   $mrtgfile = "$mrtgloc/tot-pe.log";
   $ispfile= "";
   $provider = "peering";
   $totalprice = $totalprice + isp_calculation();
   $provider = "all bandwidth";
   print_results($totalprice);
} elsif (($provider =~ /all/i) && ($operation =~ /megabit/i)) {  # megabit cost of all connections in the moment
   $ispfile = "$mrtgloc/isp1-t.txt";
   $mrtgfile = "$mrtgloc/isp1.log";
   $provider = "isp1";
   $totalprice = isp_calculation();
   $ispfile = "$mrtgloc/isp2.txt";
   $mrtgfile = "$mrtgloc/tot-isp2.log";
   $provider = "isp2";
   $totalprice = $totalprice + isp_calculation();
   $ispfile = "$mrtgloc/isp3.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/router2_ge.log";    #file containing the total megabit for this ISP
   $provider = "isp3";
   $totalprice = $totalprice + isp_calculation();
   $ispfile = "$mrtgloc/paid-peer1.txt";   # file containing connection costs for this ISP
   $mrtgfile = "$mrtgloc/router1_fe-log";    #file containing the total megabit for this ISP
   $provider = "paid-peer1";
   $totalprice = $totalprice + isp_calculation();
   $mrtgfile = "$mrtgloc/tot-pe.log";
   $ispfile= "";
   $provider = "peering";
   $megprice = $totalprice + isp_calculation(); 
   $mrtgfile = "$mrtgloc/tot-trafi.log"; 
   $totalprice = isp_calculation();
   $provider = "for all connections";
   print_results($totalprice);
} elsif ($operation =~ /percentage/i) {  # percentage of the paid traffic and peering 
   traffic_percent(); 
} elsif ($operation =~ /percentagep/i) {  # percentage of the paid traffic and free peering
   traffic_percent();
} elsif (($provider =~ /isp1/i) && ($operation =~/downtime/i)) {  # calculation of downtime cost of isp1 
   $mrtgfile = "$mrtgloc/isp1.log";
   $ispfile = "isp1-t.txt";
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif (($provider =~ /peer3/i) && ($operation =~/downtime/i))  {     # calculation of downtime cost of peer3 
   $mrtgfile = "$mrtgloc/peer3.log";
   $ispfile = "isp1-t.txt";
   $totalprice = isp_calculation();
   print_results($totalprice);
} elsif (($provider =~ /all/i) && ($operation =~ /saving/i))  {  # total saved on bandwidth cost in the moment
   $ispfile = "isp1-t.txt";
   $mrtgfile = "$mrtgloc/total-peering.log";
   $totalprice = isp_calculation(); 
   print_results($totalprice);
} elsif (($provider =~ /all/i) && ($operation =~ /downtime/i))  {  # total of costs due to all peering connections outage 
   $ispfile = "isp1-t.txt";
   $mrtgfile = "$mrtgloc/total-peering.log";
   $totalprice = isp_calculation();
   print_results($totalprice);
} else {
  print "wrong options\n"; 
  exit 0;
}

exit 0;

