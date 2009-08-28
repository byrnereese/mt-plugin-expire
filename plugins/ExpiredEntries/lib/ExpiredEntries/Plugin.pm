# Expired Entries Plugin for Movable Type and Melody
# Copyright (C) 2009 Endevver, LLC.

package ExpiredEntries::Plugin;

use strict;
use warnings;

use Carp qw( croak longmess confess );
use MT::Util qw( relative_date    offset_time format_ts days_in 
                 offset_time_list epoch2ts    ts2epoch  );

sub MT::Entry::EXPIRED () { 6 }

# use MT::Log::Log4perl qw( l4mtdump );
# use Log::Log4perl::Resurrector;
# my $logger ||= MT::Log::Log4perl->new();

sub frequency {
    my $mt = MT->instance;
    my $cfg = $mt->{config};
    return $cfg->ExpirePostFrequency * 60;
}

sub xfrm_edit_param {
    my ($cb, $app, $param, $tmpl) = @_;
    my $entry_id = $app->param('id') or return;
    my $blog = $app->blog;
    my $obj = MT->model('entry')->load( $entry_id )
        or return $cb->error('failed to load entry');

    $param->{ "status_expired" } = 1 if ($obj->status == MT::Entry::EXPIRED());

    $param->{'expire_on_date'} = $app->{query}->param('expire_on_date')
	|| format_ts( "%Y-%m-%d", $obj->expire_on, $blog, $app->user ? $app->user->preferred_language : undef );
    $param->{'expire_on_time'} = $app->{query}->param('expire_on_time')
	|| format_ts( "%H:%M:%S", $obj->expire_on, $blog, $app->user ? $app->user->preferred_language : undef );    
}

sub xfrm_list {
    my ($cb, $app, $tmpl) = @_;
    my $slug;
    $slug = <<END_TMPL;
<link rel="stylesheet" type="text/css" href="<mt:StaticWebPath>plugins/ExpiredEntries/app.css" />
END_TMPL
    $$tmpl =~ s{(<mt:setvarblock name="html_head" append="1">)}{$1 $slug}msgi;

}

sub xfrm_table {
    my ($cb, $app, $tmpl) = @_;
    my $slug;
    $slug = <<END_TMPL;
<mt:if name="status" eq="6"> status-expired</mt:if>
END_TMPL
    $$tmpl =~ s{(<td class="status si<mt:if name="status_draft">.*?</mt:if>)}{$1 $slug}msgi;

    $slug = <<END_TMPL;
            <mt:if name="status" eq="6">
                    <a href="<mt:var name="script_url">?__mode=list_<mt:var name="object_type"><mt:if name="blog_id">&amp;blog_id=<mt:var name="blog_id"></mt:if>&amp;filter=status&amp;filter_val=6" title="<mt:if name="object_type" eq="entry"><__trans phrase="Only show expired entries"><mt:else><__trans phrase="Only show expired pages"></mt:if>"><img src="<mt:var name="static_uri">images/spacer.gif" alt="<__trans phrase="Unpublished (Expired)">" width="9" height="9" /></a>
            </mt:if>
END_TMPL
    $$tmpl =~ s{(<mt:if name="status_draft">\s*<a href)}{$slug $1}msgi;

}

sub xfrm_edit {
    my ($cb, $app, $tmpl) = @_;
    my $slug;
    $slug = <<END_TMPL;
        <mt:setvarblock name="label"><mt:if name="status_expired">Expired On<mt:else>Expire On</mt:if></mt:setvarblock>
        <mtapp:setting
            id="expire_on"
            label="\$label">
            <span class="date-time-fields">
                <input id="ExpireOn" class="entry-date" name="expire_on_date" value="<mt:var name="expire_on_date" escape="html">" />
                <a href="javascript:void(0);" mt:command="open-calendar-expire-on" class="date-picker" title="<__trans phrase="Select expiration date">"><span>Choose Date</span></a>
                <input class="entry-time" name="expire_on_time" value="<mt:var name="expire_on_time" escape="html">" />
            </span>
        </mtapp:setting>
END_TMPL
    $$tmpl =~ s{(<mtapp:setting\s+id="authored_on"[^>]*>.*?</mtapp:setting>)}{$1 $slug}msgi;

    $slug = <<END_TMPL;
                    <mt:if name="new_object">
                                    <option value="6"<mt:if name="status_expired"> selected="selected"</mt:if>><__trans phrase="Unpublished (Expired)"></option>
                    <mt:else>
                        <mt:unless name="status_publish">
                                <option value="6"<mt:if name="status_expired"> selected="selected"</mt:if>><__trans phrase="Unpublished (Expired)"></option>
                        </mt:unless>
                    </mt:if>
END_TMPL
    $$tmpl =~ s{(<select name="status"[^>]*>.*?)</select>}{$1 $slug</select>}msgi;

    $slug = <<END_TMPL;
                        <mt:else name="status_expired">
                            <span class="icon-left-wide icon-draft"><__trans phrase="Unpublished (Expired)"></span>
END_TMPL
    $$tmpl =~ s{(<mt:else name="status_review">)}{$slug $1}msgi;
}

sub pre_save {
    my ($cb, $app, $obj, $orig) = @_;

    my $date = $app->param('expire_on_date');
    my $time = $app->param('expire_on_time');
    return 1 unless ($date ne '' && $time ne '');

    my $eod  = $date ." ". $time;
    my $error;

    unless ( $eod =~ m!^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$! ) {
	$error = $app->translate(
	    "Invalid date '[_1]'; authored on dates must be in the format YYYY-MM-DD HH:MM:SS.",
	    $eod
	    );
    }

    my $s = $6 || 0;
    if ($s > 59	|| $s < 0 || 
	$5 > 59 || $5 < 0 || 
	$4 > 23	|| $4 < 0 || 
	$2 > 12	|| $2 < 1 || 
	$3 < 1  || 
	( days_in( $2, $1 ) < $3 && !MT::Util::leap_day( $0, $1, $2 ) ) ) {
	$error = $app->translate(
	    "Invalid date '[_1]'; expired on dates should be real dates.",
	    $eod
	    );
    }

    return $app->error( $error ) if $error;

    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
    MT->log( { blog_id => $app->blog->id, message => "Setting expire date to $ts" });
    $obj->expire_on($ts);

    1;
}

sub task_expire {
    my $this = shift;

    require MT::Blog;
    require MT::Entry;
    require MT::Util;
    my $mt            = MT->instance;
    my $total_changed = 0;
    my @blogs = MT::Blog->load(undef, {
        join => MT::Entry->join_on('blog_id', {
            status => MT::Entry::RELEASE(),
            expire_on => { not_null => 1 },
				   }, { unique => 1 })
			       });
    foreach my $blog (@blogs) {
	print "The blog ".($blog->name)." has expired entries.\n";
        my @ts = MT::Util::offset_time_list( time, $blog );
        my $now = sprintf "%04d%02d%02d%02d%02d%02d", $ts[5] + 1900, $ts[4] + 1,
	@ts[ 3, 2, 1, 0 ];
	print "  Searching for entries expired before $now\n";
        my $iter = MT::Entry->load_iter(
            {
                blog_id => $blog->id,
                status  => MT::Entry::RELEASE(),
		expire_on => [ undef, $now ],
                class   => '*'
            },
            {
		'range'     => { 'expire_on' => 1 },
                'direction' => 'descend'
            }
	    );
        my @queue;
        while ( my $entry = $iter->() ) {
	    print "  Queuing ".($entry->title). " for expiration.\n";
            push @queue, $entry->id if $entry->expire_on le $now;
        }

        my $changed = 0;
        my @results;
        my %rebuild_queue;
        foreach my $entry_id (@queue) {
            my $entry = MT::Entry->load($entry_id)
                or next;
            $entry->status( MT::Entry::EXPIRED() );
            $entry->save
		or die $entry->errstr;

            MT->run_callbacks( 'post_expired', $mt, $entry );

            $rebuild_queue{ $entry->id } = $entry;
            my $n = $entry->next(1);
            $rebuild_queue{ $n->id } = $n if $n;
            my $p = $entry->previous(1);
            $rebuild_queue{ $p->id } = $p if $p;
            $changed++;
            $total_changed++;
        }
        if ($changed) {
            my %rebuilt_okay;
            my $rebuilt;
            eval {
                foreach my $id ( keys %rebuild_queue )
                {
                    my $entry = $rebuild_queue{$id};
                    $mt->rebuild_entry( Entry => $entry, Blog => $blog )
			or die $mt->errstr;
                    $rebuilt_okay{$id} = 1;
                    $rebuilt++;
                }
                $mt->rebuild_indexes( Blog => $blog )
		    or die $mt->errstr;
            };
            if ( my $err = $@ ) {
                # a fatal error occured while processing the rebuild                                                                    
                # step. LOG the error and revert the entry/entries:                                                                     
                require MT::Log;
                $mt->log(
                    {
                        message => $mt->translate(
"An error occurred while publishing expired entries: [_1]",
                            $err
                        ),
                        class   => "system",
                        blog_id => $blog->id,
                        level   => MT::Log::ERROR()
                    }
		    );
                foreach my $id (@queue) {
                    next if exists $rebuilt_okay{$id};
                    my $e = $rebuild_queue{$id};
                    next unless $e;
                    $e->status( MT::Entry::RELEASE() );
                    $e->save or die $e->errstr;
                }
            }
        }
    }
    $total_changed > 0 ? 1 : 0;
}

1;

__END__