# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Checker;

Base class of all checkers. Checkers give checking and guessing support
for configuration values. Most of the methods of this class are intended
to be protected i.e. only available to subclasses.

=cut

package Foswiki::Configure::Checker;

use strict;
use warnings;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

use Assert;
use File::Spec               ();
use CGI                      ();
use Foswiki::Configure::Load ();

=begin TML

---++ ObjectMethod check($value) -> $html
   * $value - Value object for the thing being checked

Entry point for the value check. Overridden by subclasses.

Returns html formatted by $this->ERROR(), WARN(), NOTE(), or
hand made _OR_ an empty string. The output of a checker will normally
be included in an HTML table, so don't get too carried away.

=cut

sub check {
    my ( $this, $value ) = @_;

    # default behaviour; see no evil, hear no evil, speak no evil
    return $this->showExpandedValue($value);
}

=begin TML

---++ ObjectMethod parseOptions()
Gets the checker options from the spec file, and returns a
list of hashes for easier access.

Spec file options are: CHECK="option option:value option:value,value option:'value'", where

   * each option has a value (the default when just the keyword is present is 1)
   * options are separated by whitespace
   * values are introduced by : and delimited by , (Unless quoted, in which case
there is just one value.  N.B. If quoted, double \.)
   * The returned hash provides an arrayref containing all values for each option

Multiple CHECK clauses allow default checkers to do several checks for an item.
For example, DataDir wants one set of options for .txt files, and another for ,v files.

=cut

sub parseOptions {
    my $this = shift;

    return $this->{item}->{CHECK} ? @{ $this->{item}->{CHECK} } : ();
}

=begin TML

---++ PROTECTED ObjectMethod guessed($status) -> $html

A checker can either check the sanity of the previously saved value,
or guess a one if none exists. If the checker guesses, it should call
=$this->guessed(0)= (passing 1 if the guess was an error).

=cut

sub guessed {
    my ( $this, $error ) = @_;

    my $mess = <<'HERE';
I guessed this setting. You are advised to confirm this setting (and any
other guessed settings) and hit 'Save changes' to save before changing any other
settings.
HERE

    if ($error) {
        return $this->ERROR($mess);
    }
    else {
        return $this->WARN($mess);
    }
}

=begin TML

---++ ObjectMethod getCfg($name) -> $expanded_val
Get the value of the named configuration var. The name is in the form
getCfg("{Validation}{ExpireKeyOnUse}"), and defaults to the current
item.

Any embedded references to other Foswiki::cfg vars will be expanded.

Use getCfgUndefOK if you want a real undef for undefined values rather
than the string 'undef'.

=cut

sub getCfg {
    my ( $this, $name ) = @_;
    $name ||= $this->{item}->{keys};

    my $item = '$Foswiki::cfg' . $name;
    Foswiki::Configure::Load::expandValue($item);
    return $item;
}

# $undef: 1 => embedded undef forces undef result
#         2 => embedded undef replaced by 'undef'
sub getCfgUndefOk {
    my ( $this, $name, $undef ) = @_;
    $name ||= $this->{item}->{keys};

    my $item = '$Foswiki::cfg' . $name;
    Foswiki::Configure::Load::expandValue( $item, ( $undef || 1 ) );
    return $item;
}

# Checker methods to get/set their (unexpanded) item values.
# (Existing evals should be replaced.)

=begin TML

---++ ObjectMethod setItemValue($value, $keys)
Set the value of the checked configuration var.
$keys are optional.

=cut

sub setItemValue {
    my $this  = shift;
    my $value = shift;
    my $keys  = shift || $this->{item}->{keys};

    eval "\$Foswiki::cfg$keys = \$value;";
    if ($@) {
        die "Unable to set value $value for $keys\n";
    }
    return wantarray ? ( $keys, $value ) : $keys;
}

=begin TML

---++ ObjectMethod getItemCurrentValue($keys)
Get the current value of the checked configuration var.
$keys are optional.

=cut

sub getItemCurrentValue {
    my $this = shift;
    my $keys = shift || $this->{item}->{keys};

    my $value = eval "\$Foswiki::cfg$keys";
    if ($@) {
        die "Unable to get value for $keys\n";
    }
    return $value;
}

=begin TML

---++ ObjectMethod getItemDefaultValue($keys)
Get the default value of the checked configuration var.
$keys is optional

=cut

sub getItemDefaultValue {
    my $this = shift;
    my $keys = shift || $this->{item}->{keys};

    no warnings 'once';
    my $value = eval "\$$Foswiki::defaultCfg->$keys";
    if ($@) {
        die "Unable to get default $value for $keys\n";
    }
    return $value;
}

=begin TML

---++ PROTECTED ObjectMethod warnAboutWindowsBackSlashes($path) -> $html

Generate a warning if the supplied pathname includes windows-style
path separators.

=cut

sub warnAboutWindowsBackSlashes {
    my ( $this, $path ) = @_;
    if ( $path =~ /\\/ ) {
        return $this->WARN(
                'You should use c:/path style slashes, not c:\path in "'
              . $path
              . '"' );
    }
}

=begin TML

---++ PROTECTED ObjectMethod guessMajorDir($cfg, $dir, $silent) -> $html

Try and guess the path of one of the major directories, by looking relative
to the absolute pathname of the dir where configure is being run.

=cut

sub guessMajorDir {
    my $this = shift;
    my $cfg  = shift;

    return $this->guessDirectory( "{$cfg}", undef, @_ );
}

=begin TML

---++ PROTECTED ObjectMethod guessDirectory($keys, $dir, $root, $silent) -> $html

Guesses the location of any directory, not just a major key.

   * $keys - the full {key}{spec} to be guessed
   * $dir - the default subdirectory name
   * $root - {key}{spec} of default parent.  undef to use install root.
   * $silent - No error if the directory does not exist.

Requires that root directory is valid (or guessed before its subdirectories)
Special case for {ScriptDir}, as that's where the guessing starts for a
brand new install.

=cut

sub guessDirectory {
    my ( $this, $keys, $root, $dir, $silent ) = @_;

    my $msg = '';
    my $val = $this->getCfg($keys);
    if ( !$val || $val eq 'NOT SET' || $val eq 'undef' ) {
        my $guess;
        if ( $keys eq '{ScriptDir}' ) {
            require FindBin;
            $FindBin::Bin =~ /^(.*)$/;
            $guess = $1;
        }
        else {
            my @root =
              File::Spec->splitdir( $this->getCfg( $root || '{ScriptDir}' ) );
            pop @root unless ($root);
            $guess = File::Spec->catfile( @root, $dir );
        }
        $guess =~ s|\\|/|g;
        $this->setItemValue($guess);
        $msg = $this->guessed();
        $val = $this->getCfg($keys);
    }
    unless ( $silent || -d $val ) {
        my $fwcval = $this->getItemCurrentValue();
        $msg .=
          $this->ERROR( "Directory '$fwcval'"
              . ( $val eq $fwcval ? '' : " ($val)" )
              . "  does not exist" );
    }
    return $msg;
}

=begin TML

---++ PROTECTED ObjectMethod showExpandedValue($field) -> $html

Return the expanded value of a parameter as a note for display.
$field is the value of the field (not it's keys)

=cut

sub showExpandedValue {
    my ( $this, $field ) = @_;
    my $msg = '';

    if ( defined $field && $field =~ m/\$Foswiki::cfg/ ) {
        Foswiki::Configure::Load::expandValue( $field, 1 );
        $msg = $this->NOTE(
            '<b>Note:</b> Expands to: '
              . (
                defined $field
                ? $field
                : '<span class="configureUndefinedValue">undefined</span>'
              )
        );
    }
    $msg = $this->WARN('The value of this field is undefined')
      if ( !defined $field
        && !$this->{item}{MUST_ENABLE}
        && !$this->{item}{UNDEFINEDOK} );

    return $msg;
}

=begin TML

---++ PROTECTED ObjectMethod checkTreePerms($path, $perms, $filter) -> $html

Perform a recursive check of the specified path.  The recursive check 
is limited to the configured "PathCheckLimit".  This prevents excessive
delay on installations with large data or pub directories.  The
count of files checked is available in the class method $this->{filecount}

$perms is a string of permissions to check:

Basic checks:
   * r - File or directory is readable 
   * w - File or directory is writable
   * x - File is executable.

All failures of the basic checks are reported back to the caller.

Enhanced checks:
   * d - Directory permission matches the permissions in {Store}{dirPermission}
   * f - File permission matches the permission in {Store}{filePermission}  (FUTURE)
   * p - Verify that a WebPreferences exists for each web

If > 20 enhanced errors are encountered, reporting is stopped to avoid excessive
errors to the administrator.   The count of enhanced errors is reported back 
to the caller by the object variable:  $this->{fileErrors}

In addition to the basic and enhanced checks specified in the $perms string, 
Directories are always checked to determine if they have the 'x' permission.

$filter is a regular expression.  Files matching the supplied regex if present
will not be checked.  This is used to skip rcs,v  or .txt files because they
have different permission requirements.

Note that the enhanced checks are important especially on hosted sites. In some
environments, the Foswiki perl scripts run under a different user/group than 
the web server.  Basic checks will pass, but the server may still be unable
to access the file.  The enhanced checks will detect this condition.

Callers of this checker should reset $this->{filecount} and $this->{fileErrors}
to zero before calling this routine.

=cut

sub checkTreePerms {
    my ( $this, $path, $perms, $filter ) = @_;

    return '' if ( defined($filter) && $path =~ $filter && !-d $path );

    $this->{fileErrors}  = 0 unless ( defined $this->{fileErrors} );
    $this->{missingFile} = 0 unless ( defined $this->{missingFile} );
    $this->{excessPerms} = 0 unless ( defined $this->{excessPerms} );

    #let's ignore Subversion directories
    return '' if ( $path eq '_svn' );
    return '' if ( $path eq '.svn' );

    # Okay to increment count once filtered files are ignored.
    $this->{filecount}++;

    my $errs      = '';
    my $permErrs  = '';
    my $rwxString = buildRWXMessageString( $perms, $path );

    return $path . ' cannot be found' . CGI::br()
      unless ( -e $path || -l $path );

    if ( $perms =~ /d/ && -d $path ) {
        my $mode = ( stat($path) )[2] & oct(7777);
        if ( $mode != $Foswiki::cfg{Store}{dirPermission} ) {
            my $omode = sprintf( '%04o', $mode );
            my $operm = sprintf( '%04o', $Foswiki::cfg{Store}{dirPermission} );
            if (
                (
                    ( $mode | $Foswiki::cfg{Store}{dirPermission} )
                    ^ $Foswiki::cfg{Store}{dirPermission}
                )
              )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'excessPerms',
"$path - directory permission $omode differs from requested $operm - check directory for possible excess permissions"
                );
            }
            if ( ( $mode & $Foswiki::cfg{Store}{dirPermission} ) !=
                $Foswiki::cfg{Store}{dirPermission} )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'fileErrors',
"$path - directory permission $omode differs from requested $operm - check directory for possible insufficient permissions"
                );
            }
        }
    }

    if ( $perms =~ /f/ && -f $path ) {
        my $mode = ( stat($path) )[2] & oct(7777);
        if ( $mode != $Foswiki::cfg{Store}{filePermission} ) {
            my $omode = sprintf( '%04o', $mode );
            my $operm = sprintf( '%04o', $Foswiki::cfg{Store}{filePermission} );
            if (
                (
                    ( $mode | $Foswiki::cfg{Store}{filePermission} )
                    ^ $Foswiki::cfg{Store}{filePermission}
                )
              )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'excessPerms',
"$path - file permission $omode differs from requested $operm - check file for possible excess permissions"
                );
            }
            if ( ( $mode & $Foswiki::cfg{Store}{filePermission} ) !=
                $Foswiki::cfg{Store}{filePermission} )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'fileErrors',
"$path - file permission $omode differs from requested $operm - check file for possible insufficient permissions"
                );
            }
        }
    }

    if (   $perms =~ /p/
        && $path =~ /\Q$Foswiki::cfg{DataDir}\E\/(.+)$/
        && -d $path )
    {
        unless ( -e "$path/$Foswiki::cfg{WebPrefsTopicName}.txt" ) {
            $permErrs .= " $path missing $Foswiki::cfg{WebPrefsTopicName} topic"
              . CGI::br();
            $this->{missingFile}++;
        }
    }

    if ($rwxString) {
        $errs .=
          $this->getEmptyStringUnlessUnderLimit( 'fileErrors', $rwxString );
    }

    return $permErrs . $path . $errs . CGI::br() if $errs;

    return $permErrs unless -d $path;

    return
        $permErrs
      . $path
      . ' directory is missing \'x\' permission - not readable'
      . CGI::br()
      if ( -d $path && !-x $path );

    opendir( my $Dfh, $path )
      or return 'Directory ' . $path . ' is not readable.' . CGI::br();

    foreach my $e ( grep { !/^\./ } readdir($Dfh) ) {
        my $p = $path . '/' . $e;
        $errs .= checkTreePerms( $this, $p, $perms, $filter );
        last if ( $this->{filecount} >= $Foswiki::cfg{PathCheckLimit} );

    }
    closedir($Dfh);

    return $permErrs . $errs;
}

sub getEmptyStringUnlessUnderLimit {
    my ( $this, $type, $message ) = @_;
    my $errs = '';

    $this->{$type}++;
    if ( $this->{$type} < 10 ) {
        if ($message) {
            $errs = $message . CGI::br();
        }
    }

    return $errs;
}

sub buildRWXMessageString {
    my ( $perms, $path ) = @_;
    my $message = '';

    if ( $perms =~ /r/ && !-r $path ) {
        $message .= ' not readable';
    }

    if ( $perms =~ /w/ && !-d $path && !-w $path ) {
        $message .= ' not writable';
    }

    if ( $perms =~ /x/ && !-x $path ) {
        $message .= ' not executable';
    }

    return $message;
}

=begin TML

---++ PROTECTED ObjectMethod checkCanCreateFile($path) -> $html

Check that the given path can be created (or, if it already exists,
can be written). If the existing path is a directory, recursively
check for rw permissions using =checkTreePerms=.

Returns a message or the empty string if the check passed.

=cut

sub checkCanCreateFile {
    my ( $this, $name ) = @_;

    if ( -e $name ) {

        # if the file exists just check perms and return
        return $this->checkTreePerms( $name, 'rw' );
    }

    # check the containing dir
    my @path = File::Spec->splitdir($name);
    pop(@path);
    unless ( -w File::Spec->catfile( @path, '' ) ) {
        return File::Spec->catfile( @path, '' ) . ' is not writable';
    }
    my $txt1 = "test 1 2 3";
    open( my $fh, '>', $name )
      or return 'Could not create test file ' . $name . ':' . $!;
    print $fh $txt1;
    close($fh);
    open( my $in_file, '<', $name )
      or return 'Could not read test file ' . $name . ':' . $!;
    my $txt2 = <$in_file>;
    close($in_file);
    unlink $name if ( -e $name );

    unless ( $txt2 eq $txt1 ) {
        return 'Could not write and then read ' . $name;
    }
    return '';
}

=begin TML

---++ PROTECTED ObjectMethod checkGnuProgram($prog) -> $html

Check for the availability of a GNU program.

Since Windows (without Cygwin) makes it hard to capture stderr
('2>&1' works only on Win2000 or higher), and Windows will usually have
GNU tools in any case (installed for Foswiki since there's no built-in
diff, grep, patch, etc), we only check for these tools on Unix/Linux
and Cygwin.

=cut

sub checkGnuProgram {
    my ( $this, $prog ) = @_;
    my $mess = '';

    if (   $Foswiki::cfg{OS} eq 'UNIX'
        || $Foswiki::cfg{OS} eq 'WINDOWS'
        && $Foswiki::cfg{DetailedOS} eq 'cygwin' )
    {

        # SMELL: assumes no spaces in program pathnames
        $prog =~ /^\s*(\S+)/;
        $prog = $1;
        my $diffOut = ( `$prog --version 2>&1` || "" );
        my $notFound = ( $? != 0 );
        if ($notFound) {
            $mess = $this->ERROR("'$prog' was not found on the current PATH");
        }
        elsif ( $diffOut !~ /\bGNU\b/ ) {

            # Program found on path, complain if no GNU in version output
            $mess = $this->WARN(
                "'$prog' program was found on the PATH ",
                "but is not GNU $prog - this may cause ",
                "problems. $diffOut"
            );

            #} else {
            #$diffOut =~ /(\d+(\.\d+)+)/;
            #$mess = "($prog is version $1).";
        }
    }
    elsif ( $Foswiki::cfg{OS} eq 'WINDOWS' ) {

        #real windows - using GnuWin32 tools
    }

    return $mess;
}

# Strip traceback from die and carp for a user message

sub stripTraceback {
    my ( $this, $message ) = @_;

    return '' unless ( length $message );

    return $message if ( $Foswiki::cfg::{DebugTracebacks} );

    $message = ( split( /\n/, $message ) )[0];
    $message =~ s/ at .*? line \d+\.$//;
    return $message;
}

=begin TML

---++ PROTECTED ObjectMethod checkRE($keys) -> $html
Check that the configuration item identified by the given keys represents
a compilable perl regular expression.

=cut

sub checkRE {
    my ( $this, $keys ) = @_;
    my $str;
    eval "\$str = \$Foswiki::cfg$keys;";
    return '' unless defined $str;
    eval { qr/$str/ };
    if ($@) {
        my $msg = $this->stripTraceback($@);
        return $this->ERROR(<<"MESS");
Invalid regular expression: $msg <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
    }
    return '';
}

sub getValueObject { return; }

sub getSectionObject { return; }

sub visit { return 1; }

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.