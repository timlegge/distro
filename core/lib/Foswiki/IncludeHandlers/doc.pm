# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::IncludeHandlers::doc

This package is designed to be lazy-loaded when Foswiki sees
an INCLUDE macro with the doc: protocol. It implements a single
method INCLUDE which generates perl documentation for a Foswiki class.

=cut

package Foswiki::IncludeHandlers::doc;
use v5.14;

use strict;
use warnings;

use File::Spec ();
use Foswiki    ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

use constant PUBLISHED_API_TOPIC => 'PublishedAPI';

# Include embedded doc in a core module
sub INCLUDE {
    my ( $includeMacro, $control, $params ) = @_;

    my $app           = $includeMacro->app;
    my %removedblocks = ();
    my $class         = $control->{_DEFAULT} || 'doc:Foswiki';
    my $publicOnly    = ( $params->{publicOnly} || '' ) eq 'on';
    $app->prefs->setSessionPreferences( 'SMELLS', '' );

    # SMELL This is no longer being used in PerlDoc ...
    #    $app->prefs->setSessionPreferences( 'DOC_PARENT', '' );
    $app->prefs->setSessionPreferences( 'DOC_CHILDREN', '' );
    $app->prefs->setSessionPreferences( 'DOC_TITLE',    '---++ !! !%TOPIC%' );
    $class =~ s/[a-z]+://;    # remove protocol
    $class ||= 'Foswiki';     # provide a reasonable default

    #    return '' unless $class && $class =~ m/^Foswiki/;
    $class =~ s/[^\w:]//g;

    my %publicPackages = map { $_ => 1 } _loadPublishedAPI($app);
    my $visibility = exists $publicPackages{$class} ? 'public' : 'internal';
    _setNavigation( $app, $class, $publicOnly, \%publicPackages );
    $app->prefs->setSessionPreferences( 'DOC_TITLE',
        "---++ !! =$visibility package= " . _renderTitle( $app, $class ) );

    my $pmfile = _getPmFile( $app, $class );
    return '' unless $pmfile;

    my $PMFILE;
    open( $PMFILE, '<', $pmfile ) || return '';
    my $inPod      = 0;
    my $pod        = '';
    my $howSmelly  = 0;
    my $showSmells = !$app->isGuest();
    local $/ = undef;
    my $perl = <$PMFILE>;
    my $isa;
    my $inSuppressedMethod;

    if (   $perl =~ m/our\s+\@ISA\s*=\s*\(\s*['"](.*?)['"]\s*\)/
        || $perl =~ m/extends\s+(?:qw\(|'|")(.+?)(?:\)|'|");/ )
    {
        $isa = " ==is a== $1";
        $isa =~ s#\s(\w+?(?:::[A-Z]\w+)+)#' ' . _doclink($app, $1)#ge;
    }
    $perl = Foswiki::takeOutBlocks( $perl, 'verbatim', \%removedblocks );
    foreach my $line ( split( /\r?\n/, $perl ) ) {
        if ( $line =~ m/^=(begin (twiki|TML|html)|pod)/ ) {
            $inPod              = 1;
            $inSuppressedMethod = 0;
        }
        elsif ( $line =~ m/^=cut/ ) {
            $inPod = 0;
        }
        elsif ($inPod) {
            if ( $line =~ m/^---\+(!!)?\s+(?i:package|class)\s+\S+\s*$/ ) {
                if ($isa) {
                    $line .= $isa;
                    $isa = undef;
                }
                $line =~
s/^---\+(?:!!)?\s+((?i)package|class)\s*(.*)/---+ =$visibility $1= $2/;
                $app->prefs->setSessionPreferences( 'DOC_TITLE',
                    "---++ !! =$visibility $1= "
                      . _renderTitle( $app, $class ) );
            }
            else {
                # Check for module names not prefixed with colon or left square
                # bracket.
                $line =~
                  s#(?<![\[:])\b(\w+?(?:::[A-Z]\w+)+)#_doclink($app, $1)#ge;
            }
            if ( $line =~ s/^(---\++\s+)(\w+(?:Method|Attribute))\s+/$1=$2= / )
            {
                $line =~ s/\s+[-=]>\s+/ &rarr; /;
                if ( $publicOnly && $line =~ m/Method=\s+_/ ) {
                    $inSuppressedMethod = 1;
                }
            }
            elsif ( $line =~ m/^---/ ) {
                $inSuppressedMethod = 0;
            }
            $pod .= "$line\n"
              unless $inSuppressedMethod;
        }
        if (  !$inSuppressedMethod
            && $line =~ m/(SMELL|FIXME|TODO)/
            && $showSmells )
        {
            $howSmelly++;
            $pod .=
                "<blockquote class=\"foswikiAlert\">"
              . Foswiki::entityEncode($line)
              . "</blockquote>";
        }
    }
    close($PMFILE);
    Foswiki::putBackBlocks( \$pod, \%removedblocks, 'verbatim', 'verbatim' );

    $pod =~ s/.*?%STARTINCLUDE%//s;
    $pod =~ s/%(?:END|STOP)INCLUDE%.*//s;
    if ($howSmelly) {
        my $podSmell =
            '<blockquote class="foswikiAlert">'
          . " *SMELL / FIX / TODO count: $howSmelly*\n"
          . '</blockquote>';
        $pod .= $podSmell;
        $app->prefs->setSessionPreferences( 'SMELLS', $podSmell );
    }

    $pod =
      $includeMacro->applyPatternToIncludedText( $pod, $control->{pattern} )
      if ( $control->{pattern} );

    # Adjust the root heading level
    if ( $params->{level} ) {
        my $minhead = '+' x 100;
        $pod =~ s/^---(\++)/
          $minhead = $1 if length($1) < length($minhead); "---$1"/gem;
        return $pod if length($minhead) == 100;
        my $newroot = '+' x $params->{level};
        $minhead =~ s/\+/\\+/g;
        $pod     =~ s/^---$minhead/---$newroot/gm;
    }
    return $pod;
}

sub _getPmFile {
    my ( $app, $class ) = @_;
    state %cachedPMs;
    state $fwPath;

    unless ( defined $fwPath ) {
        $fwPath = ( File::Spec->splitpath( $INC{'Foswiki.pm'} ) )[1];
    }

    return $cachedPMs{$class} if $cachedPMs{$class};

    my $pmfile = '';
    ( my $classFile = $class ) =~ s#::#/#g;
    $classFile = File::Spec->catfile( $fwPath, "$classFile.pm" );
    $pmfile = $classFile if ( -f $classFile );
    $cachedPMs{$class} = $pmfile;
    return $pmfile;
}

# set DOC_CHILDREN preference value to a list of sub-packages.
sub _setNavigation {
    my ( $app, $class, $publicOnly, $publicPackages ) = @_;
    my @children;
    my %childrenDesc;
    my $classPrefix = $class . '::';

#    my $classParent = $class;
#    $classParent =~ s/::[^:]+$//;
#    $app->prefs->setSessionPreferences( 'DOC_PARENT', _doclink($app, $classParent) );
    $class =~ s#::#/#g;

    foreach my $inc (@INC) {
        if ( -d "$inc/$class" and opendir my $dh, "$inc/$class" ) {
            my @dir = grep { !/^\./ } readdir($dh);
            push @children,
              map { -d "$inc/$class/$_" ? "$classPrefix$_" : () } @dir;
            for my $d (@dir) {
                if ( $d =~ s/\.pm$// ) {
                    push @children, "$classPrefix$d";
                    $childrenDesc{"$classPrefix$d"} =
                      _getPackSummary("$inc/$class/$d.pm");
                }
            }
            closedir $dh;
        }
    }
    if ($publicOnly) {
        @children = grep { exists $publicPackages->{$_} } @children;
    }
    my $children = '<ul>';
    if (@children) {
        my %children = map { $_ => 1 } @children;
        @children = sort keys %children;
        foreach my $child (@children) {
            my $desc =
              $childrenDesc{$child} ? ' - ' . $childrenDesc{$child} : '';
            $children .= '<li>' . _doclink( $app, $child ) . "$desc</li>\n";
        }
    }
    $children .= '</ul>';
    $app->prefs->setSessionPreferences( 'DOC_CHILDREN', $children );
}

# get a summary of the pod documentation by looking directly after the ---+ package TML.
sub _getPackSummary ($) {
    my $pmfile = $_[0];
    my @summary;

    my $PMFILE;
    open( $PMFILE, '<', $pmfile ) || return '';
    my $inPod     = 0;
    my $inPackage = 0;
    while ( my $line = <$PMFILE> ) {
        if ( $line =~ m/^=(begin (twiki|TML|html)|pod)/ ) {
            $inPod = 1;
        }
        elsif ( $line =~ m/^=cut/ ) {
            @summary
              and last;
            $inPod = 0;
        }
        elsif ($inPod) {
            if ($inPackage) {
                chomp($line);
                push @summary, $line;
            }
            if ( $line =~ m/^---\+(!!)?\s+(?i:package|class)\s+\S+\s*$/ ) {
                $inPackage = 1;
            }
        }
    }
    close($PMFILE);

    while (@summary) {
        if ( $summary[0] =~ m/^\s*$/ ) {
            shift @summary;
        }
        else {
            last;
        }
    }
    if ( !@summary ) {
        return '';
    }
    my $emptyLine = 0;
    while ( $emptyLine < @summary && $summary[$emptyLine] !~ /^\s*$/ ) {
        $emptyLine++;
    }
    return join ' ', @summary[ 0 .. $emptyLine - 1 ];
}

sub _loadPublishedAPI {
    my $app = shift;
    my ( $meta, $text ) =
      $app->readTopic( $app->cfg->data->{SystemWebName}, PUBLISHED_API_TOPIC );
    my @ret;
    for my $line ( split /\r?\n/, $text ) {

#| [[%SYSTEMWEB%.PerlDoc?module=Foswiki::Func][Foswiki::Func]] | 1.1.5 | Main API. |
        $line =~ m/^\|\s*\[\[.*?PerlDoc.*?\]\[(.*?)\]\]/
          and push @ret, $1;
    }
    return @ret;
}

# Make each intermediate package into a doc link.
sub _renderTitle {
    my $app       = shift;
    my $pack      = $_[0];
    my @packComps = split '::', $pack;
    my @packLinks =
      map {
        _doclink( $app, ( join '::', @packComps[ 0 .. $_ ] ), $packComps[$_] )
      } 0 .. $#packComps - 1;
    my $packageTitle = join '::', @packLinks, $packComps[$#packComps];
    return $packageTitle;
}

sub _doclink ($) {
    my $app    = shift;
    my $module = $_[0];
    $module =~ /^/; # Do it to reset $n match variables.
    $module =~ s/^_(.+)(_)$/$1/;
    my $formatChar = $2 // '';
    my $title = $_[1] || $module;

    my $pmfile = _getPmFile( $app, $module );

    # SMELL relying on TML to set publicOnly
    return $formatChar
      . (
        $pmfile
        ? ( "[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module="
              . $module
              . "%IF{\"\$publicOnly = 'on'\" then=\";publicOnly=on\"}%]["
              . $title
              . "]]" )
        : "[[CPAN:$module][$title]]"
      ) . $formatChar;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
