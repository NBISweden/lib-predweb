#!/usr/bin/perl -w
# Filename:  check_web_server.pl

# Description: check whether the web server is accessable and also check the status
#              of the qd_fe.pl

# Created 2015-04-10, 2017-02-28, Nanjiang Shu

use File::Temp;

use Cwd 'abs_path';
use File::Basename;
use POSIX qw(strftime);
use Data::Dump qw(dump);

use LWP::Simple qw($ua head);
$ua->timeout(10);

my $usage = "
USAGE: $0 SERVER-NAME SERVER-ROOT-DIR

Examples:
    $0 TOPCONS2 /var/www/html/topcons2
";

sub PrintHelp {
    print $usage;
}

$numArgs = $#ARGV+1;
if($numArgs < 2)
{
    &PrintHelp;
    exit(1);
}

my $servername = $ARGV[0];
my $server_root_dir = $ARGV[1];
my $basedir = abs_path("$server_root_dir/proj/pred/");
print("basedir=$basedir\n");
print("server_root_dir=$server_root_dir\n");

my $path_nanjianglib = `which nanjianglib.pl`;
chomp($path_nanjianglib);
require "$path_nanjianglib";
my $FORMAT_DATETIME = '%Y-%m-%d %H:%M:%S %Z';

my $date = strftime "$FORMAT_DATETIME", localtime;
print "\n#=======================\nDate: $date\n";
my $url = "";
my $target_qd_script_name = "qd_fe.py";
my $computenodelistfile = "$basedir/config/computenode.txt";
my $alert_emaillist_file = "$basedir/config/alert_email.txt";
my $base_www_url_file = "$basedir/static/log/base_www_url.txt";
my $from_email = "nanjiang.shu\@scilifelab.se";
my $title = "";
my $output = "";

my @to_email_list = ReadList($alert_emaillist_file);
my @urllist = ReadList($base_www_url_file);

my %computenodelist ;
open(IN, "<", $computenodelistfile) or die;
while(<IN>) {
    chomp;
    if ($_ && substr($_, 0, 1) ne '#'){
        my @items = split(' ', $_);
        $computenodelist{$items[0]}{"numprocess"} = $items[1];
        $computenodelist{$items[0]}{"queue_method"} = $items[2];
    }
}
close IN;

print(dump( %computenodelist)."\n");

foreach $url (@urllist){ 
# First: check if the $url is accessable
    if (!head($url)){
        $title = "[$servername] $url un-accessible";
        $output = "$url un-accessible";
        foreach my $to_email(@to_email_list) {
            sendmail($to_email, $from_email, $title, $output);
        }
    }

# Second: check if qd is running at the front-end
    my $num_running=`curl $url/cgi-bin/check_qd_fe.cgi 2> /dev/null | html2text | grep  "$target_qd_script_name" | wc -l`;
    chomp($num_running);

    if ($num_running < 1){
        $output=`curl $url/cgi-bin/restart_qd_fe.cgi 2>&1 | html2text`;
        $title = "[$servername] $target_qd_script_name restarted for $url";
        foreach my $to_email(@to_email_list) {
            sendmail($to_email, $from_email, $title, $output);
        }
    }
}

# Third, check if the suq queue is blocked at the compute node and try to clean
# it if blocked
foreach (sort keys %computenodelist){
    my $computenode = $_;
    my $max_parallel_job= $computenodelist{$_}{"numprocess"};
    my $queue_method=  $computenodelist{$_}{"queue_method"};
    if ($queue_method eq 'suq'){
        print "curl http://$computenode/cgi-bin/clean_blocked_suq.cgi 2>&1 | html2text\n";
        $output=`curl http://$computenode/cgi-bin/clean_blocked_suq.cgi 2>&1 | html2text`;
        `curl http://$computenode/cgi-bin/set_suqntask.cgi?ntask=$max_parallel_job `;
        if ($output =~ /Try to clean the queue/){
            $title = "[$servername] Cleaning the queue at $computenode";
            foreach my $to_email(@to_email_list) {
                sendmail($to_email, $from_email, $title, $output);
            }
        }
    }else{
        print("$computenode has slurm queue, no need to clean.\n");
    }
}
