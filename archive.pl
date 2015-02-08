#!/usr/bin/env perl
package Templates;
use strict;
use warnings;
use Template::Declare::Tags; # defaults to 'HTML'
use base 'Template::Declare';

template content_list => sub {
    my ($self, $title, $url, $articles) = @_;
    p { 
        outs "Mail content was generated from";
        a { 
            attr { href is $url };
            $url;
        }
    };

    h1 { $title };

    for my $article (@$articles) {
        h2 { $article->{title} }
        a { attr { href is $article->{uri} }; $article->{uri} }
        p {
            em { "Date" };
            i { $article->{date} };
        }
        pre {
            outs_raw $article->{intro};
        };
    }
};

template journal => sub {
    my ($self, $original_title, $url, $mails) = @_;
    html {
        head {
            title { $original_title };
            # <meta charset="UTF-8" />
            meta { attr { charset => "UTF-8" } }
        }
        body {
            show 'content_list', $original_title, $url, $mails;
        }
    }
};

package main;
use utf8;
use strict;
use warnings;
use WWW::Mechanize;
use Mojo::DOM;
use HTML::Entities;
use Getopt::Long;
use Template::Declare;
use LWP::Simple 'get';
use 5.18.0;
use File::Basename;

my $max_entries = 0;
my $output_file = "journal.html";
my $template_name = 'journal';
my $verbose = 0;
my $reverse = 0;

GetOptions("max=i" => \$max_entries,
            "output=s"   => \$output_file,
            "reverse" => \$reverse,
            "verbose" => \$verbose,
            "template=s"  => \$template_name);

my $mech = WWW::Mechanize->new();
my $url = shift;

my @articles = ();

$mech->get($url);

my $main_title = $mech->title();

my $content = $mech->content();
my $dom = Mojo::DOM->new($content);

die 'It is not an index page' unless $dom->find('.generalbody tr')->first;


if ($output_file eq 'journal.html') {
    my $username = $dom->find('.generaltitle h3 a')->[1]->all_text;
    $output_file = $username . '.html' if $username;
}

for my $tr ($dom->find('.generalbody tr')->each) {
    next unless $tr;

    my $first_td = $tr->find('td')->first;
    next unless $first_td;
    
    my $a = $first_td->find('a')->first;
    next unless $a;

    my $link = $mech->find_link( text => $a->all_text);

    say "Fetching ", $link->url_abs() if $verbose;
    my $article_dom = Mojo::DOM->new(get $link->url_abs);
    my $intro = $article_dom->find('#journalslashdot .intro')->first;
    my $title = $article_dom->find('#journalslashdot .title')->first;
    my $date = $article_dom->find('#journalslashdot .journaldate')->first;
    unless($intro && $title) {
        say "Skipping..." if $verbose;
        next;
    }
    printf "% 12s : %s\n", ('(' . (scalar(@articles) + 1) . ')'), $title->all_text;
    push @articles, { 
        date  => $date->all_text,
        url   => $link->url_abs,
        title => $title->all_text,
        intro => $intro->content,
    };
}

reverse @articles if $reverse;


Template::Declare->init( dispatch_to => ['Templates'] );

my $html = Template::Declare->show($template_name, $main_title, $url, \@articles);
say "Writing generated HTML to $output_file..." if $verbose;
open FH, ">", $output_file;
binmode FH, ":utf8";
print FH $html;
close FH;
say "Done!";
