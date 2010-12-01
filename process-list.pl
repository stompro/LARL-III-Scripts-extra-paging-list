#!/usr/bin/perl

#//Need to add to a data structure that starts with Bibs with a list of items,callnumbers and locations, a
#// and a list of holds with pickup location, Not needed by info, etc.  Leave out holds that cannot be filled.

#// Then go through and create a paging list for each location, don't be smart about it to start out with.

use Mail::Sendmail;
use MIME::Lite;
use Mail::Internet;
use Data::Dumper;
use Date::Parse;
use Date::Manip;
#use Date::Manip::Date;
use Template ();
use Template::Stash ();
use Getopt::Std;


#### Contants
use constant BOOST => 150; #How much to boost the weight of a location if they are not in the same agency as the request.
use constant DEBUG => 1; #Show Debug Output, 0 for no, 1 for yes
use constant DELAY => 7; # How long since hold placed, in days
####

####### Command Line Options
# -s sharon - Send SYSTEM1 locations data to Sharon
# -s helen - Send SYSTEM1 Rotation 8r to Helen
# -s SYSTEM2 - Send SYSTEM2 branches their lists
# -s SYSTEM1 - Send SYSTEM1 branches their lists
getopt('s');


my %paging;
my %data;
my %holdref; #Store item paging list information
my $pagecount = 0;

my $exclude = "^\"(s.|l.e|7|nk|c|nl|no|na|np|n.e|y|z)";
#Exclude LINK site items, and leased items,withdrawn items, express items

#Weight, Lowest score wins, Start with 10.  Seperate different levels by 10.  Choose randomly between locations of 
#the same weight.  Give other region a BOOST point boost so they are picked last
my %branch;
%branch = (
  "nn" => {
    branch => "HQ2 Collection",
    email => "hq\@system2.org",
    weight => "150",
  },
  "lr" => {
    branch => "1 RO Rotation",
    email => "goodinh\@system1.org",
    weight => "150",
  },
  "lq" => {
    branch => "1 RO Rotation",
    email => "goodinh\@system1.org",
    weight => "150",
  },
  "la" => {
    branch => "branch1 Library",
    email => "ada\@system1.org",
    weight => "60",
  },
  "lg" => {
    branch => "branch2 Library",
    email => "bagley\@system1.org",
    weight => "90"
  },
  "lb" => {
    branch => "branch3 Library",
    email => "breckenridge\@system1.org",
    weight => "40"
  },
  "lv" => {
    branch => "branch4 Library",
    email => "barnesville\@system1.org",
    weight => "80"
  },
  "lx" => {
    branch => "branch5 Library",
    email => "climax\@system1.org",
    weight => "130"
  },
  "lc" => {
    branch => "branch6 Library",
    email => "crookston\@system1.org",
    weight => "20"
  },
  "lm" => {
    branch => "Branch7 Library",
    email => "moorhead\@system1.org",
    weight => "10",
  },
  "nt" => {
    branch => "Region 2 Branch 1 Library",
    email => "trfcirc\@system2.org",
    weight => "10",
  },
  "nf" => {
    branch => "Region 2 Branch 2 Library",
    email => "redlake\@system2.org",
    weight => "70",
  },
  "nb" => {
    branch => "Region 2 Branch 3 Library",
    email => "greenbush\@system2.org",
    weight => "40",
  },
  "nr" => {
    branch => "Region 2 Branch 4 Library",
    email => "roseau\@system2.org",
    weight => "20",
  },
  "nw" => {
    branch => "Region 2 Branch 5 Library",
    email => "warroad\@system2.org, staff2\@system2.org",
    weight => "30",
  },
);

print Dumper(\%branch) if DEBUG;

print "Current datetime is ".time()."\n" if DEBUG;

while (<>){ #Read in STDIN
	chomp;
	my @items = split(/\~/);
	#0 = Bib, 1 = Item, 2 = call, 3 = location, 4 = title, 5 = author 6 = Holdinfo
	#Add Bib info to hash
	if(!defined $data{$items[0]}){
		$data{$items[0]} = {
			title => "$items[4]",
			author => "$items[5]",
			items => {},
			holds => {}
		};
	}
	if(!defined $data{$items[0]}->{items}->{$items[1]} && !($items[3] =~ $exclude)){
		$data{$items[0]}->{items}->{$items[1]} = {
			call => "$items[2]",
			location => "$items[3]"
		}
	}

  #process Holds - Split holds on ","
  my @holds = split(/\"\;\"/,$items[6]);
  foreach my $hold (@holds) {
    $hold =~ s/"//g;
    $hold =~ m/P#=(\d{7}), I#=(\d{7}), P=([0-9-]+), NNB=([0-9-]+) \((\d{1,3}) days\), RLA=(.+), NNA=([0-9-]+), ST=0, TP=., PU=(.{2,5})/;
    #print $hold."\n";
    #print $7."\n";
    #Convert placed date to a real date.
    #$placeddate = new Date::Manip::Date;
    ($itemnum,$bib,$placed,$NNB,$NNBdays,$RLA,$NNA,$Loc) = ($1,$2,$3,$4,$5,$6,$7,$8);
    $curdate = ParseDate("today");
    
    print "$itemnum,$bib,$placed,$NNB,$NNBdays,$RLA,$NNA,$Loc";
    #$placeddate->parse_format("%m-%d-%y",$3);
    $foo = $placed;
    $foo =~ s/\-/\//g;
    $placeddate = ParseDate($foo);
    #$curdate = ParseDate(time());
    $delta = DateCalc($placeddate,$curdate);
    #$placedtime = str2time($3);
    print "Date placed -> ".UnixDate($placeddate,"%Y")." - $foo\n";
    #print UnixDate($placeddate,"%y");
    #$daysold = DateCalc(time(),$3);
    print Delta_Format($delta,1,"%dh")."\n";
    $daysold = Delta_Format($delta,1,"%dh")."\n";
    
    if(!defined $data{$items[0]}->{holds}->{$itemnum} && ($NNBdays==0) && ($daysold > DELAY) && ($RLA==0)){
      $data{$items[0]}->{holds}->{$itemnum} = {
        bibnumber => "$bib",
        placed => "$placed",
        NNB => "$NNB",
        NNBdays => "$NNBdays",
	      RLA => "$RLA",
        NNA => "$NNA",
        location => "$Loc"
      };
    }
  } 
  
  }

print Dumper(\%data) if DEBUG;

#Cycle through every bib data element, and process them to come up with a paging list.
foreach my $bib (keys %data){
  #We only care about bibs that have at least 1 hold and item.
  if(keys( %{ $data{$bib}->{holds} })>0 && keys( %{ $data{$bib}->{items} })>0 ){
    print $bib."\n";
    foreach my $hold (sort { 
      substr($data{$bib}->{holds}->{$a}->{placed},6,2) cmp substr($data{$bib}->{holds}->{$b}->{placed},6,2) ||
      substr($data{$bib}->{holds}->{$a}->{placed},0,2) cmp substr($data{$bib}->{holds}->{$b}->{placed},0,2) ||
      substr($data{$bib}->{holds}->{$a}->{placed},3,2) cmp substr($data{$bib}->{holds}->{$b}->{placed},3,2)
      } keys %{ $data{$bib}->{holds}}){
      print "  Hold->$hold ".$data{$bib}->{holds}->{$hold}->{location}." ";
      print $data{$bib}->{holds}->{$hold}->{placed}."\n";
    }
    foreach my $item (keys %{ $data{$bib}->{items}}){
      print "   Item->$item ".$data{$bib}->{items}->{$item}->{location}."\n";
    }
=begin GHOSTCODE
   #Commenting this out because the weighted logic can handle all the decisions - makes hold info availabe for every page
    #If There are greater than or equals number holds than items, just page them all
    #This is one of the big deficiencies with III paging, drives book clubs nuts
    if (keys( %{ $data{$bib}->{holds} }) >= keys( %{ $data{$bib}->{items} })){
      print "One page to rule them all\n";
      foreach my $item (keys %{ $data{$bib}->{items}}){
        my $loc = $data{$bib}->{items}->{$item}->{location};
        $loc =~ s/^\"[l783](.).*/l$1/;
        $loc =~ s/^\"[n](.).*/n$1/;
        print "----> Page to $loc\n";
        $holdref{$loc} .= $data{$bib}->{items}->{$item}->{call}.','.
          $data{$bib}->{items}->{$item}->{location}.','.
          $data{$bib}->{title}.','.
          $data{$bib}->{author}.','.
          $bib."\n";
        $paging{$loc}->{$item}->{call} = $data{$bib}->{items}->{$item}->{call};
        $paging{$loc}->{$item}->{location} = $data{$bib}->{items}->{$item}->{location};
        $paging{$loc}->{$item}->{title} = $data{$bib}->{title};
        $paging{$loc}->{$item}->{author} = $data{$bib}->{author};
        $paging{$loc}->{$item}->{bib} = $bib;
        #$paging{$loc}->{$item}->{placed} = $data{$bib}->{holds}->{$item}->{call}
        $pagecount +=1;  
      }
    }
=end GHOSTCODE

=cut

    #Since we use local holds priority, we can first just run through the holds and see if any items are local for that hold.
    #If there are more items than holds we actually have to do some work
    #and pick out items that are local to those holds. That is pass 1
    #Pass 2 involves sorting the holds that are left by date, earliest first
    #Then run through them and pick the best fit based on region and weight and 
    #randomness... The randomness means that each run will be slightly different
    #If this is just run once a day it shouldn't be a big deal.  keys( %{ $data{$bib}->{holds} }) < keys( %{ $data{$bib}->{items} })
    if (TRUE){
      print "Have to do more work :(\n" if DEBUG;
      #Pass1 - Page local holds first  - We don't have to care about specifics here, when the item is checked in, it will do the right thing.
      foreach my $hold (keys %{ $data{$bib}->{holds}}){
        foreach my $item (keys %{ $data{$bib}->{items}}){
          my $loc = $data{$bib}->{items}->{$item}->{location};
          #Normalize item location codes to match the branch hash codes
          $loc =~ s/^\"[l783](.).*/l$1/; #Normalize location code, get rid of extra starting codes that SYSTEM1 uses, and only keep the second code.  8xabf turns info lx
          $loc =~ s/^\"[n](.).*/n$1/; #Normalize SYSTEM2 codes
          #If the hold location equals the item location, then just page it and delete the hold and the item.
          if ($loc.'   ' eq $data{$bib}->{holds}->{$hold}->{location}){
            print "   $loc - ".$data{$bib}->{holds}->{$hold}->{location}." Hold is local to this item, Page it and ship it.\n" if DEBUG;
            $holdref{$loc} .= $data{$bib}->{items}->{$item}->{call}.','.
            $data{$bib}->{items}->{$item}->{location}.','.
            $data{$bib}->{title}.','.
            $data{$bib}->{author}.','.
            $bib."\n";
            
            $paging{$loc}->{$item}->{call} = $data{$bib}->{items}->{$item}->{call};
            $paging{$loc}->{$item}->{location} = $data{$bib}->{items}->{$item}->{location};
            $paging{$loc}->{$item}->{title} = $data{$bib}->{title};
            $paging{$loc}->{$item}->{author} = $data{$bib}->{author};
            $paging{$loc}->{$item}->{bib} = $bib;
            #This info will be incorrect at certain times since the first hold that matches will put its info here, and we are not sorting by oldest hold first.
            $paging{$loc}->{$item}->{placed} = $data{$bib}->{holds}->{$hold}->{placed};
            $paging{$loc}->{$item}->{pickuploc} = $data{$bib}->{holds}->{$hold}->{location};
            
            $pagecount +=1;
            delete $data{$bib}->{holds}->{$hold}; #Ged rid of hold
            delete $data{$bib}->{items}->{$item}; #get rid of item
            last;
          }
        }
      }
      #Pass 2 {$data{$bib}->{holds}->{$a}->{placed} cmp  $data{$bib}->{holds}->{$b}->{placed}}
      ## Sort holds by date, and look for the best match for the oldest hold first, then the next oldest, etc.
      #### This sorts based on the placed year, then month, then day, but cutting up the placed date string.
      foreach my $hold ( sort {
        substr($data{$bib}->{holds}->{$a}->{placed},6,2) cmp substr($data{$bib}->{holds}->{$b}->{placed},6,2) ||
        substr($data{$bib}->{holds}->{$a}->{placed},0,2) cmp substr($data{$bib}->{holds}->{$b}->{placed},0,2) ||
        substr($data{$bib}->{holds}->{$a}->{placed},3,2) cmp substr($data{$bib}->{holds}->{$b}->{placed},3,2)
        } keys %{ $data{$bib}->{holds}}){
        #What Region  is this hold for.
        my $region;
        $region="l" if $data{$bib}->{holds}->{$hold}->{location} =~ /^[l783s]/;
        $region="n" if $data{$bib}->{holds}->{$hold}->{location} =~ /^[nc]/;
        print "Region = $region\n -----HOLD-> ".$data{$bib}->{holds}->{$hold}->{placed}."\n";
        my %itempriority;
        foreach my $item (keys %{ $data{$bib}->{items}}){
          my $itemregion = "l" if  $data{$bib}->{items}->{$item}->{location} =~ /^\"[l783s]/;
          $itemregion="n" if $data{$bib}->{items}->{$item}->{location} =~ /^\"[nc]/;
          $data{$bib}->{items}->{$item}->{location} =~ /^\".(.)..../;
          my $itemloc = $itemregion.$1;
          $itempriority{$item} = $branch{$itemloc}->{weight}+int(rand(10));
          $itempriority{$item} += BOOST if !($itemregion eq $region); #if the item region is not equal to the hold region add BOOST to the weight
          print $itemloc." -> Item weight ".$itempriority{$item}."\n";
        }
        #sort items by priority, page the first item, delete that item.
        foreach my $item (sort {$itempriority{$a} <=> $itempriority{$b}} keys %itempriority){
          print "This item wins ".$item."\n";
          my $loc = $data{$bib}->{items}->{$item}->{location};
          $loc =~ s/^\"[l783](.).*/l$1/;
          $loc =~ s/^\"[n](.).*/n$1/;
          $holdref{$loc} .= $data{$bib}->{items}->{$item}->{call}.','.
            $data{$bib}->{items}->{$item}->{location}.','.
            $data{$bib}->{title}.','.
            $data{$bib}->{author}.','.
            $bib."\n";
          $paging{$loc}->{$item}->{call} = $data{$bib}->{items}->{$item}->{call};
          $paging{$loc}->{$item}->{location} = $data{$bib}->{items}->{$item}->{location};
          $paging{$loc}->{$item}->{title} = $data{$bib}->{title};
          $paging{$loc}->{$item}->{author} = $data{$bib}->{author};
          $paging{$loc}->{$item}->{bib} = $bib;
          $paging{$loc}->{$item}->{placed} = $data{$bib}->{holds}->{$hold}->{placed};
          $paging{$loc}->{$item}->{pickuploc} = $data{$bib}->{holds}->{$hold}->{location};
          $pagecount += 1;  
          delete $data{$bib}->{items}->{$item};
          last;
        }
      }
    }
  }
}


undef %holdref;

foreach my $loc (sort keys %paging){
  print $loc."\n";
  foreach my $item (sort {$paging{$loc}->{$a}->{call} cmp $paging{$loc}->{$b}->{call} || $paging{$loc}->{$a}->{author} cmp $paging{$loc}->{$b}->{author}} keys %{$paging{$loc}}){
    print $loc."-->".$paging{$loc}->{$item}->{call}."\n";
    $holdref{$loc} .= $paging{$loc}->{$item}->{call}.','.
            $paging{$loc}->{$item}->{location}.','.
            $paging{$loc}->{$item}->{title}.','.
            $paging{$loc}->{$item}->{author}.','.
            $paging{$loc}->{$item}->{bib}."\n";
  }

}

foreach my $list (keys %holdref){
  print "Paging list for $list\n";
  print $holdref{$list}."\n\n\n";
}

print "Number of pages $pagecount\n";

# subsort - sort the hash's keys by the values of a key in 
# subordinate hashes.  Takes two keys to sort by.  Used by template toolkit.
$Template::Stash::HASH_OPS->{ subsort } = sub { 
  my ($hash, $key1, $key2) = @_;
    [ sort { lc $hash->{$a}->{$key1} cmp lc $hash->{$b}->{$key1} || lc $hash->{$a}->{$key2} cmp lc $hash->{$b}->{$key2} } 
      (keys %$hash) 
    ]; 
};
my $output = '';
my $tt = Template->new({
  OUTPUT => \$output,
}) || die "$Template::ERROR\n";

foreach my $loc (sort keys %paging){
  print "Process template for ".$branch{$loc}->{branch}."\n";
  my $vars = {
	binfo => $branch{$loc},
	code => $loc,
	items => $paging{$loc},
  gendate => `date`,
  };

  #print Dumper(\$vars);
  $output = '';
  $tt->process('template.html', $vars) || die $tt->error(), "\n";
  $sendto = 'stomproj@system1.org';
  $extramsg = ''; #extra message sent with email.
  #if sharon option is picked and the location equals a SYSTEM1 location
  if($opt_s eq "sharon" && $loc =~ /^(l|s|8)/){
    $sendto = 'douglass@system1.org';
    $extramsg = "Copies of all SYSTEM1 extra paging lists getting sent to Sharon 1 day before being sent to staff";
  }
  elsif($opt_s eq "sharon"){
    #Skip the rest of the locations
    print "   ---> Skip sending this location\n";
    next;
  }
  #if helen option is picked and the location equals rotation send to helen
  if($opt_s eq "helen" && $loc =~ /^(8r|lr|lq)/){
    $sendto = 'goodinh@system1.org';
    $extramsg = "Rotation items with holds being sent to Helen for her to monitor.";
  }
  elsif($opt_s eq "helen"){
    #Skip the rest of the locations
    print "    --> Skip sending this location\n";
    next;
  }
  #If larl  or both selected, send to larl locations
  if($opt_s eq "SYSTEM1" && $loc =~ /^(l|s|8)/){
    $sendto = $branch{$loc}->{email};
  }
  elsif($opt_s eq "SYSTEM1"){
    #Skip the rest of the locations
    print "    --> Skip sending this location\n";
    next;
  }
  #If SYSTEM2 or both selected, send to SYSTEM2 locations
  if($opt_s eq "SYSTEM2" && $loc =~ /^(n|c)/){
    $sendto = $branch{$loc}->{email};
  }
  elsif($opt_s eq "SYSTEM2"){
    #Skip the rest of the locations
    print "    --> Skip sending this location\n";
    next;
  }
  
  my $msg = MIME::Lite->new(
                From    =>'root@system1.org',
                 To      =>$sendto.', extra-paging-list@system1.org',
                 Subject =>'Extra Paging List for '.$branch{$loc}->{branch}.' on '.`date +%m-%d-%Y`,
                 Type    =>'multipart/mixed'
);
    ### Add the text message part:
    #if there is an extra message, send that also.
    if($extramsg ne ''){
      $msg->attach(Type     =>'text/html',
                 Data     =>$extramsg,
                 );
    }
    ### (Note that "attach" has same arguments as "new"):
    $msg->attach(Type     =>'text/html',
                 Data     =>$output,
                 );
    
$msg->send;

  
 # foreach my $item (sort {$paging{$loc}->{$a}->{call} cmp $paging{$loc}->{$b}->{call} || $paging{$loc}->!
 #   print $loc."-->".$paging{$loc}->{$item}->{call}."\n";
 #   $holdref{$loc} .= $paging{$loc}->{$item}->{call}.','.
 #           $paging{$loc}->{$item}->{location}.','.
 #           $paging{$loc}->{$item}->{title}.','.
 #           $paging{$loc}->{$item}->{author}.','.
 #           $paging{$loc}->{$item}->{bib}."\n";
 # 

 }


#print Dumper(\%paging);
#print Dumper(\%branch);

sub iiidatesort {
  $data{$bib}->{holds}->{$a}->{placed} =~ /(\d{2})-(\d{2})-(\d{2})/;
  $c = $3.$1.$2;
  
  $data{$bib}->{holds}->{$b}->{placed} =~ /(\d{2})-(\d{2})-(\d{2})/;
  $d = $3.$1.$2;
  print $a."<->".$b."\n";
  print Dumper(\%data->{$bib});
  print $data{$bib}->{holds}->{$a}->{placed}."<=>".$data{$bib}->{holds}->{$b}->{placed}."\n";
  $c <=> $d;
  }
  
sub callnumsort {

  $paging{$loc}->{$a}->{call} cmp $paging{$loc}->{$b}->{call}
}
