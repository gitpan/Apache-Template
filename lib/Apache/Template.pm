#============================================================= -*-perl-*-
#
# Apache::Template
#
# DESCRIPTION
#   Apache/mod_perl handler for the Template Toolkit.
#
# AUTHOR
#   Andy Wardley <abw@kfs.org>
#
# COPYRIGHT
#   Copyright (C) 1996-2001 Andy Wardley.  All Rights Reserved.
#   Copyright (C) 1998-2001 Canon Research Centre Europe Ltd.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
# REVISION
#   $Id$
#
#========================================================================

package Apache::Template;

use strict;
use vars qw( $VERSION $DEBUG $ERROR $SERVICE $SERVICE_MODULE );

use DynaLoader ();
use Apache::ModuleConfig ();
use Apache::Constants qw( :common );
use Template::Service::Apache;

$VERSION = '0.02';
$ERROR   = '';
$DEBUG   = 0 unless defined $DEBUG;
$SERVICE_MODULE = 'Template::Service::Apache' unless defined $SERVICE_MODULE;

if ($ENV{ MOD_PERL }) {
    no strict;
    @ISA = qw( DynaLoader );
    __PACKAGE__->bootstrap($VERSION);
}


#------------------------------------------------------------------------
# handler($request)
#
# Main Apache/mod_perl content handler which delegates to an
# underlying Template::Service::Apache object.  This is created and 
# stored in the $SERVICE package variable and then reused across
# requests.  This allows compiled templates to be cached and re-used
# without requiring re-compilation.  The service implements 4 methods 
# for different phases of the request:
#
#   template($request)		  # fetch a compiled template
#   params($request)		  # build parameter set (template vars)
#   process($template, $params)	  # process template
#   headers($request, $template, \$content)
#				  # set and send http headers
#------------------------------------------------------------------------

sub handler {
    my $r = shift;

    $SERVICE ||= do {
	my $cfg = Apache::ModuleConfig->get($r);

	# hack to work around minor bug in Template::Parser from 
	# TT v 2.00 which doesn't recognise a blessed hash as
	# being valid configuration params.  Fixed in TT 2.01.
	$cfg = { %$cfg };

	# instantiate new service module
	my $module = $cfg->{ SERVICE_MODULE } || $SERVICE_MODULE;
	$module->new($cfg) || do {
	    $r->log_reason($Template::Service::Apache::ERROR,
			   $r->filename());
	    return SERVER_ERROR;
	};
    };

    my $template = $SERVICE->template($r);
    return $template unless ref $template;

    my $params = $SERVICE->params($r);
    return $params unless ref $params;

    my $content = $SERVICE->process($template, $params);
    unless (defined $content) {
	$r->log_reason($SERVICE->error(), $r->filename());
	return SERVER_ERROR;
    }

    $SERVICE->headers($r, $template, \$content);

    $r->print($content);

    return OK;
}


#========================================================================
# Configuration Handlers
#========================================================================

#------------------------------------------------------------------------
# TT2Tags html			# specify TAG_STYLE
# TT2Tags [* *]			# specify START_TAG and END_TAG
#------------------------------------------------------------------------

sub TT2Tags($$$$) {
    my ($cfg, $parms, $start, $end) = @_;
    if (defined $end and length $end) {
	$cfg->{ START_TAG } = quotemeta($start);
	$cfg->{ END_TAG   } = quotemeta($end);
    }
    else {
	$cfg->{ TAG_STYLE } = $start;
    }
}

#------------------------------------------------------------------------
# TT2PreChomp On		# enable PRE_CHOMP
#------------------------------------------------------------------------

sub TT2PreChomp($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ PRE_CHOMP } = $on;
}

#------------------------------------------------------------------------
# TT2PostChomp On		# enable POST_CHOMP
#------------------------------------------------------------------------

sub TT2PostChomp($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ POST_CHOMP } = $on;
}

#------------------------------------------------------------------------
# TT2Trim On			# enable TRIM
#------------------------------------------------------------------------

sub TT2Trim($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ TRIM } = $on;
}

#------------------------------------------------------------------------
# TT2AnyCase On			# enable ANYCASE
#------------------------------------------------------------------------

sub TT2AnyCase($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ ANYCASE } = $on;
}

#------------------------------------------------------------------------
# TT2Interpolate On		# enable INTERPOLATE
#------------------------------------------------------------------------

sub TT2Interpolate($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ INTERPOLATE } = $on;
}

#------------------------------------------------------------------------
# TT2IncludePath /here /there	# define INCLUDE_PATH directories
# TT2IncludePath /elsewhere	# additional INCLUDE_PATH directories
#------------------------------------------------------------------------

sub TT2IncludePath($$@) {
    my ($cfg, $parms, $path) = @_;
    my $incpath = $cfg->{ INCLUDE_PATH } ||= [ ];
    push(@$incpath, $path);
}

#------------------------------------------------------------------------
# TT2Absolute On		# enable ABSOLUTE file paths
#------------------------------------------------------------------------

sub TT2Absolute($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ ABSOLUTE } = $on;
}

#------------------------------------------------------------------------
# TT2Relative On		# enable RELATIVE file paths
#------------------------------------------------------------------------

sub TT2Relative($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ RELATIVE } = $on;
}

#------------------------------------------------------------------------
# TT2Delimiter ,		# set alternate directory delimiter
#------------------------------------------------------------------------

sub TT2Delimiter($$$) {
    my ($cfg, $parms, $delim) = @_;
    $cfg->{ DELIMITER } = $delim;
}

#------------------------------------------------------------------------
# TT2PreProcess config header	# define PRE_PROCESS templates
# TT2PreProcess menu		# additional PRE_PROCESS templates
#------------------------------------------------------------------------

sub TT2PreProcess($$@) {
    my ($cfg, $parms, $file) = @_;
    my $preproc = $cfg->{ PRE_PROCESS } ||= [ ];
    push(@$preproc, $file);
}

#------------------------------------------------------------------------
# TT2Process main1 main2	# define PROCESS templates
# TT2Process main3		# additional PROCESS template
#------------------------------------------------------------------------

sub TT2Process($$@) {
    my ($cfg, $parms, $file) = @_;
    my $process = $cfg->{ PROCESS } ||= [ ];
    push(@$process, $file);
}

#------------------------------------------------------------------------
# TT2PostProcess menu copyright	# define POST_PROCESS templates
# TT2PostProcess footer		# additional POST_PROCESS templates
#------------------------------------------------------------------------

sub TT2PostProcess($$@) {
    my ($cfg, $parms, $file) = @_;
    my $postproc = $cfg->{ POST_PROCESS } ||= [ ];
    push(@$postproc, $file);
}

#------------------------------------------------------------------------
# TT2Default notfound		# define DEFAULT template
#------------------------------------------------------------------------

sub TT2Default($$$) {
    my ($cfg, $parms, $file) = @_;
    $cfg->{ DEFAULT } = $file;
}

#------------------------------------------------------------------------
# TT2Error error		# define ERROR template
#------------------------------------------------------------------------

sub TT2Error($$$) {
    my ($cfg, $parms, $file) = @_;
    $cfg->{ ERROR } = $file;
}

#------------------------------------------------------------------------
# TT2EvalPerl On		# enable EVAL_PERL
#------------------------------------------------------------------------

sub TT2EvalPerl($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ EVAL_PERL } = $on;
}

#------------------------------------------------------------------------
# TT2LoadPerl On		# enable LOAD_PERL
#------------------------------------------------------------------------

sub TT2LoadPerl($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ LOAD_PERL } = $on;
}

#------------------------------------------------------------------------
# TT2Recursion On		# enable RECURSION
#------------------------------------------------------------------------

sub TT2Recursion($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ RECURSION } = $on;
}

#------------------------------------------------------------------------
# TT2PluginBase My::Plugins 	# define PLUGIN_BASE package(s)
# TT2PluginBase Your::Plugin	# additional PLUGIN_BASE package(s)
#------------------------------------------------------------------------

sub TT2PluginBase($$@) {
    my ($cfg, $parms, $base) = @_;
    my $pbases = $cfg->{ PLUGIN_BASE } ||= [ ];
    push(@$pbases, $base);
}

#------------------------------------------------------------------------
# TT2AutoReset Off		# disable AUTO_RESET
#------------------------------------------------------------------------

sub TT2AutoReset($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ AUTO_RESET } = $on;
}

#------------------------------------------------------------------------
# TT2CacheSize 128		# define CACHE_SIZE
#------------------------------------------------------------------------

sub TT2CacheSize($$$) {
    my ($cfg, $parms, $size) = @_;
    $cfg->{ CACHE_SIZE } = $size;
}

#------------------------------------------------------------------------
# TT2CompileExt .tt2		# define COMPILE_EXT
#------------------------------------------------------------------------

sub TT2CompileExt($$$) {
    my ($cfg, $parms, $ext) = @_;
    $cfg->{ COMPILE_EXT } = $ext;
}

#------------------------------------------------------------------------
# TT2CompileDir /var/tt2/cache	# define COMPILE_DIR
#------------------------------------------------------------------------

sub TT2CompileDir($$$) {
    my ($cfg, $parms, $dir) = @_;
    $cfg->{ COMPILE_DIR } = $dir;
}

#------------------------------------------------------------------------
# TT2Debug On			# enable DEBUG
#------------------------------------------------------------------------

sub TT2Debug($$$) {
    my ($cfg, $parms, $on) = @_;
    $cfg->{ DEBUG } = $DEBUG = $on;
}

#------------------------------------------------------------------------
# TT2Headers length etag	    # add certain HTTP headers
#------------------------------------------------------------------------

sub TT2Headers($$@) {
    my ($cfg, $parms, $item) = @_;
    my $headers = $cfg->{ SERVICE_HEADERS } ||= [ ];
    push(@$headers, $item);
}

#------------------------------------------------------------------------
# TT2Params uri env pnotes	    # define parameters as template vars
#------------------------------------------------------------------------

sub TT2Params($$@) {
    my ($cfg, $parms, $item) = @_;
    my $params = $cfg->{ SERVICE_PARAMS } ||= [ ];
    push(@$params, $item);
}

#------------------------------------------------------------------------
# TT2ServiceModule   My::Service::Class	    # custom service module
#------------------------------------------------------------------------

sub TT2ServiceModule($$$) {
    my ($cfg, $parms, $module) = @_;
    $cfg->{ SERVICE_MODULE } = $module;
    warn "set SERVICE_MODULE => $module\n";
}



#========================================================================
# Configuration creators/mergers
#
# NOTE: these seem to be broken in the version of Apache I'm using
# (will report back once I've got enough tuits to install and test
# with the latest version of Apache/mod_perl).  The DIR_MERGE sub seems
# to get called twice on each request, similary for SERVER_MERGE which
# gets called twice for each virtual host.  For now, I've disabled
# them and set all config options to have a req_override of RSRC_CONF.
# As and when this problem gets fixed, I'd like to make them RSRC_CONF
# | ACCESS_CONF to allow different locations, directories, etc., to
# support different TT2 configurations.
#========================================================================

my $dir_counter = 1;	    # used for debugging/testing of problems
my $srv_counter = 1;	    # with SERVER_MERGE and DIR_MERGE

sub not_used_SERVER_CREATE {
    my $class  = shift;
    my $config = bless { }, $class;
    warn "SERVER_CREATE($class) => $config\n" if $DEBUG;
    return $config;
}

sub not_used_SERVER_MERGER {
    my ($parent, $config) = @_;
    my $merged = bless { %$parent, %$config }, ref($parent);
    if ($DEBUG) {
	$merged->{ counter } = $srv_counter;
	warn "\nSERVER_MERGE #" . $srv_counter++ . "\n" 
	    . "$parent\n" . dump_hash($parent) . "\n+\n"
	    . "$config\n" . dump_hash($config) . "\n=\n"
	    . "$merged\n" . dump_hash($merged) . "\n";
    }
    return $merged;
}

sub not_used_DIR_CREATE {
    my $class  = shift;
    my $config = bless { }, $class;
    warn "DIR_CREATE($class) => $config\n" if $DEBUG;
    return $config;
}

sub not_used_DIR_MERGE {
    my ($parent, $config) = @_;
    my $merged = bless { %$parent, %$config }, ref($parent);
    if ($DEBUG) {
	$merged->{ counter } = $dir_counter;
	warn "\nDIR_MERGE #" . $dir_counter++ . "\n" 
	    . "$parent\n" . dump_hash($parent) . "\n+\n"
	    . "$config\n" . dump_hash($config) . "\n=\n"
	    . "$merged\n" . dump_hash($merged) . "\n";
    }
    return $merged;
}


# debug methods for testing problems with DIR_MERGE, etc.

sub dump_hash {
    my $hash = shift;
    my $out = "{\n";

    while (my($key, $value) = (each %$hash)) {
	$value = "[ @$value ]" if ref $value eq 'ARRAY';
	$out .= "    $key => $value\n";
    }
    $out .= "}";
}

sub dump_hash_html {
    my $hash = dump_hash(shift);
    for ($hash) {
	s/>/&gt;/g;
	s/\n/<br>/g;
	s/ /&nbsp;/g;
    }
    return $hash;
}

	
1;

__END__

=head1 NAME

Apache::Template - Apache/mod_perl interface to the Template Toolkit

=head1 SYNOPSIS

    # add the following to your httpd.conf
    PerlModule          Apache::Template

    # set various configuration options, e.g.
    TT2Trim             On
    TT2PostChomp        On
    TT2EvalPerl         On
    TT2IncludePath      /usr/local/tt2/templates
    TT2IncludePath      /home/abw/tt2/lib
    TT2PreProcess       config header
    TT2PostProcess      footer
    TT2Error            error

    # now define Apache::Template as a PerlHandler, e.g.
    <Files *.tt2>
	SetHandler	perl-script
        PerlHandler     Apache::Template
    </Files>

    <Location /tt2>
	SetHandler	perl-script
        PerlHandler     Apache::Template
    </Location>

=head1 DESCRIPTION

The Apache::Template module provides a simple interface to the
Template Toolkit from Apache/mod_perl.  The Template Toolkit is a
fast, powerful and extensible template processing system written in
Perl.  It implements a general purpose template language which allows
you to clearly separate application logic, data and presentation
elements.  It boasts numerous features to facilitate in the generation
of web content both online and offline in "batch mode".

This documentation describes the Apache::Template module, concerning
itself primarily with the Apache/mod_perl configuration options
(e.g. the httpd.conf side of things) and not going into any great
depth about the Template Toolkit itself.  The Template Toolkit 
includes copious documentation which already covers these things
in great detail.  See L<Template> for further information.

=head1 CONFIGURATION

Most of the Apache::Template configuration directives relate directly
to their Template Toolkit counterparts, differing only in having a
'TT2' prefix, mixed capitalisation and lack of underscores to space
individual words.  This is to keep Apache::Template configuration
directives in keeping with the preferred Apache/mod_perl style.

e.g.

    Apache::Template  =>  Template Toolkit
    --------------------------------------
    TT2Trim	          TRIM
    TT2IncludePath        INCLUDE_PATH
    TT2PostProcess        POST_PROCESS
    ...etc...

In some cases, the configuration directives are named or behave
slightly differently to optimise for the Apache/mod_perl environment
or domain specific features.  For example, the TT2Tags configuration
directive can be used to set TAG_STYLE and/or START_TAG and END_TAG
and as such, is more akin to the Template Toolkit TAGS directive.

e.g.

    TT2Tags	    html
    TT2Tags	    <!--  -->

The configuration directives are listed in full below.  Consult 
L<Template> for further information on their effects within the 
Template Toolkit.

=over 4

=item TT2Tags

Used to set the tags used to indicate Template Toolkit directives
within source templates.  A single value can be specified to 
indicate a TAG_STYLE, e.g.

    TT2Tags	    html

A pair of values can be used to indicate a START_TAG and END_TAG.

    TT2Tags	    <!--    -->

Note that, unlike the Template Toolkit START_TAG and END_TAG
configuration options, these values are automatically escaped to
remove any special meaning within regular expressions.

    TT2Tags	    [*  *]	# no need to escape [ or *

By default, the start and end tags are set to C<[%> and C<%]>
respectively.  Thus, directives are embedded in the form: 
[% INCLUDE my/file %].

=item TT2PreChomp

Equivalent to the PRE_CHOMP configuration item.  This flag can be set
to have removed any whitespace preceeding a directive, up to and
including the preceeding newline.  Default is 'Off'.

    TT2PreChomp	    On

=item TT2PostChomp

Equivalent to the POST_CHOMP configuration item.  This flag can be set
to have any whitespace after a directive automatically removed, up to 
and including the following newline.  Default is 'Off'.

    TT2PostChomp    On

=item TT2Trim

Equivalent to the TRIM configuration item, this flag can be set
to have all surrounding whitespace stripped from template output.
Default is 'Off'.

    TT2Trim	    On

=item TT2AnyCase

Equivalent to the ANY_CASE configuration item, this flag can be set
to allow directive keywords to be specified in any case.  By default,
this setting is 'Off' and all directive (e.g. 'INCLUDE', 'FOREACH', 
etc.) should be specified in UPPER CASE only.

    TT2AnyCase	    On

=item TT2Interpolate

Equivalent to the INTERPOLATE configuration item, this flag can be set
to allow simple variables of the form C<$var> to be embedded within
templates, outside of regular directives.  By default, this setting is
'Off' and variables must appear in the form [% var %], or more explicitly,
[% GET var %].

    TT2Interpolate  On

=item TT2IncludePath

Equivalent to the INCLUDE_PATH configuration item.  This can be used
to specify one or more directories in which templates are located.
Multiple directories may appear on each TT2IncludePath directive line,
and the directive may be repeated.  Directories are searched in the 
order defined.

    TT2IncludePath  /usr/local/tt2/templates
    TT2InludePath   /home/abw/tt2   /tmp/tt2

Note that this only affects templates which are processed via
directive such as INCLUDE, PROCESS, INSERT, WRAPPER, etc.  The full
path of the main template processed by the Apache/mod_perl handler is
generated (by Apache) by appending the request URI to the
DocumentRoot, as per usual.  For example, consider the following
configuration extract:

    DocumentRoot    /usr/local/web/ttdocs
    [...]
    TT2IncludePath  /usr/local/tt2/templates

    <Files *.tt2>
	SetHandler	perl-script
        PerlHandler     Apache::Template
    </Files>

A request with a URI of '/foo/bar.tt2' will cause the handler to
process the file '/usr/local/web/ttdocs/foo/bar.tt2' (i.e.
DocumentRoot + URI).  If that file should include a directive such
as [% INCLUDE foo/bar.tt2 %] then that template should exist as the
file '/usr/local/tt2/templates/foo/bar.tt2' (i.e. TT2IncludePath + 
template name).

=item TT2Absolute

Equivalent to the ABSOLUTE configuration item, this flag can be enabled
to allow templates to be processed (via INCLUDE, PROCESS, etc.) which are
specified with absolute filenames.

    TT2Absolute	    On

With the flag enabled a template directive of the form:

    [% INCLUDE /etc/passwd %]

will be honoured.  The default setting is 'Off' and any attempt to
load a template by absolute filename will result in a 'file' exception
being throw with a message indicating that the ABSOLUTE option is not
set.  See L<Template> for further discussion on exception handling.

=item TT2Relative

Equivalent to the RELATIVE configuration item.  This is similar to the 
TT2Absolute option, but relating to files specified with a relative filename,
that is, starting with './' or '../'

    TT2Relative On

Enabling the option permits templates to be specifed as per this example:

    [% INCLUDE ../../../etc/passwd %]

As with TT2Absolute, this option is set 'Off', causing a 'file' exception
to be thrown if used in this way.

=item TT2Delimiter

Equivalent to the DELIMTER configuration item, this can be set to define 
an alternate delimiter for separating multiple TT2IncludePath options.
By default, it is set to ':', and thus multiple directories can be specified
as:

    TT2IncludePath  /here:/there

Note that Apache implicitly supports space-delimited options, so the
following is also valid and defines 3 directories, /here, /there and
/anywhere.

    TT2IncludePath  /here:/there /anywhere

If you're unfortunate enough to be running Apache on a Win32 system and 
you need to specify a ':' in a path name, then set the TT2Delimiter to 
an alternate value to avoid confusing the Template Toolkit into thinking
you're specifying more than one directory:

    TT2Delimiter    ,
    TT2IncludePath  C:/HERE D:/THERE E:/ANYWHERE

=item TT2PreProcess

Equivalent to PRE_PROCESS, this option allows one or more templates to
be named which should be processed before the main template.  This can
be used to process a global configuration file, add canned headers,
etc.  These templates should be located in one of the TT2IncludePath
directories, or specified absolutely if the TT2Absolute option is set.

    TT2PreProcess   config header

=item TT2PostProcess

Equivalent to POST_PROCESS, this option allow one or more templates to
be named which should be processed after the main template, e.g. to
add standard footers.  As per TTPreProcess, these should be located in
one of the TT2IncludePath directories, or specified absolutely if the
TT2Absolute option is set.

    TT2PostProcess  copyright footer

=item TT2Process

This is equivalent to the PROCESS configuration item.  It can be used
to specify one or more templates to be process instead of the main
template.  This can be used to apply a standard "wrapper" around all
template files processed by the handler.

    TT2Process	    mainpage

The original template (i.e. whose path is formed from the DocumentRoot
+ URI, as explained in the L<TT2IncludePath|TT2IncludePath> item
above) is preloaded and available as the 'template' variable.  This a 
typical TT2Process template might look like:

    [% PROCESS header %]
    [% PROCESS $template %]	
    [% PROCESS footer %]

Note the use of the leading '$' on template to defeat the auto-quoting
mechanism which is applied to INCLUDE, PROCESS, etc., directives.  The
directive would otherwise by interpreted as:

    [% PROCESS "template" %]

=item TT2Default

This is equivalent to the DEFAULT configuration item.  This can be
used to name a template to be used in place of a missing template
specified in a directive such as INCLUDE, PROCESS, INSERT, etc.  Note
that if the main template is not found (i.e. that which is mapped from
the URI) then the handler will decline the request, resulting in a 404
- Not Found.  The template specified should exist in one of the 
directories named by TT2IncludePath.

    TT2Default	    nonsuch

=item TT2Error

This is equivalent to the ERROR configuration item.  It can be
used to name a template to be used to report errors that are otherwise
uncaught.  The template specified should exist in one of the 
directories named by TT2IncludePath.  When the error template is 
processed, the 'error' variable will be set to contain the relevant
error details.

    TT2Error	    error

=item TT2EvalPerl

This is equivalent to the EVAL_PERL configuration item.  It can be
enabled to allow embedded [% PERL %] ... [% END %] sections
within templates.  It is disabled by default and any PERL sections
encountered will raise 'perl' exceptions with the message 'EVAL_PERL
not set'.

    TT2EvalPerl	    On

=item TT2LoadPerl

This is equivalent to the LOAD_PERL configuration item which allows
regular Perl modules to be loaded as Template Toolkit plugins via the 
USE directive.  It is set 'Off' by default.

    TT2LoadPerl	    On

=item TT2Recursion

This is equivalent to the RECURSION option which allows templates to
recurse into themselves either directly or indirectly.  It is set
'Off' by default.

    TT2Recursion    On

=item TT2PluginBase

This is equivalent to the PLUGIN_BASE option.  It allows multiple 
Perl packages to be specified which effectively form a search path
for loading Template Toolkit plugins.  The default value is 
'Template::Plugin'.

    TT2PluginBase   My::Plugins  Your::Plugins

=item TT2AutoReset

This is equivalent to the AUTO_RESET option and is enabled by default.
It causes any template BLOCK definitions to be cleared before each
main template is processed.

    TT2AutoReset    Off

=item TT2CacheSize

This is equivalent to the CACHE_SIZE option.  It can be used to limit 
the number of compiled templates that are cached in memory.  The default
value is undefined and all compiled templates will be cached in memory.
It can be set to a specified numerical value to define the maximum
number of templates, or to 0 to disable caching altogether.

    TT2CacheSize    64

=item TT2CompileExt

This is equivalent to the COMPILE_EXT option.  It can be used to
specify a filename extension which the Template Toolkit will use for
writing compiled templates back to disk, thus providing cache
persistance.

    TT2CompileExt   .ttc

=item TT2CompileDir

This is equivalent to the COMPILE_DIR option.  It can be used to
specify a root directory under which compiled templates should be 
written back to disk for cache persistance.  Any TT2IncludePath 
directories will be replicated in full under this root directory.

    TT2CompileDir   /var/tt2/cache

=item TT2Debug

This is equivalent to the DEBUG option which enables Template Toolkit
debugging.  The main effect is to raise additional warnings when
undefined variables are used but is likely to be expanded in a future
release to provide more extensive debugging capabilities.

    TT2Debug	    On

=item TT2Headers

Allows you to specify which HTTP headers you want added to the 
response.  Current permitted values are: 'modified' (Last-Modified),
'length' (Content-Length) or 'all' (all the above).

    TT2Headers	    all

=item TT2Params

Allows you to specify which parameters you want defined as template
variables.  Current permitted values are 'uri', 'env' (hash of 
environment variables), 'params' (hash of CGI parameters), 'pnotes'
(the request pnotes hash), 'cookies' (hash of cookies) or 'all'.

    TT2Params	    uri env params

When set, these values can then be accessed from within any 
template processed:

    The URI is [% uri %]

    Server name is [% env.SERVER_NAME %]

    CGI params are:
    <table>
    [% FOREACH key = params.keys %]
       <tr>
	 <td>[% key %]</td>  <td>[% params.$key %]</td>
       </tr>
    [% END %]
    </table>

=item TT2ServiceModule

The modules have been designed in such a way as to make it easy to
subclass the Template::Service::Apache module to create your own
custom services.  

For example, the regular service module does a simple 1:1 mapping of
URI to template using the request filename provided by Apache, but
you might want to implement an alternative scheme.  You might prefer,
for example, to map multiple URIs to the same template file, but to
set some different template variables along the way.  

To do this, you can subclass Template::Service::Apache and redefine
the appropriate methods.  The template() method performs the task of
mapping URIs to templates and the params() method sets up the template
variable parameters.  Or if you need to modify the HTTP headers, then
headers() is the one for you.

The TT2ServiceModule option can be set to indicate the name of your
custom service module.  The following trivial example shows how you
might subclass Template::Service::Apache to add an additional parameter,
in this case as the template variable 'message'.

    <perl>
    package My::Service::Module;
    use base qw( Template::Service::Apache );

    sub params {
	my $self = shift;
        my $params = $self->SUPER::params(@_);
        $params->{ message } = 'Hello World';
        return $params;
    }
    </perl>

    PerlModule          Apache::Template
    TT2ServiceModule    My::Service::Module

=back

=head1 BUGS, LIMITATIONS AND FUTURE ENHANCEMENTS

=head2 Multiple Concurrent Configurations

The biggest current limitation is that it's not possible to run multiple
Template Toolkit configurations within the same Apache/mod_perl server 
process.  For example, it would be nice to be able to do something like
this:

    PerlModule		Apache::Template

    TT2PostChomp	On
    TT2IncludePath	/usr/local/tt2/shared
    
    <Location /tom>
	TT2IncludePath	/home/tom/tt2
	TT2EvalPerl	On
    </Location>
	
    <Location /dick>
	TT2IncludePath	/home/dick/tt2
	TT2Trim		On
	TT2PostChomp	Off
    </Location>

Here, all URI's starting '/tom' should have an effective
TT2IncludePath of:

    TT2IncludePath  /usr/local/tt2/shared /home/tom/tt2

and those starting '/dick' should be:

    TT2IncludePath  /usr/local/tt2/shared /home/dick/tt2

Similarly, different options such as TT2PostChomp, TT2EvalPerl, etc.,
should enabled/disabled appropriately for different locations.

This should be possible using the DIR_MERGE facility, and also
SERVER_MERGE for handling multiple virtual hosts.  It should also be
relatively easy to generate the required Template Toolkit
configurations to support this (having multiple Template::Providers
chained together in different ways would be the obvious way to
implement different TT2IncludePath settings, for example).

Alas, my extended experimentation with DIR_MERGE and SERVER_MERGE 
left my brain scrambled.  It seems to be the case that they both
get called twice at each merge point instead of just once.  I have 
no idea why this is the case and it seems to be contrary to the 
advertised behaviour.  After spending far too long trying to figure
it out, I gave up and decided to leave that feature for a later
version.  

Any insight into this matter that anyone can provide would be 
gratefully accepted.  I've left the code intact, above.  Simply
remove the 'not_used_' prefixes from the DIR/SERVER_CREATE/MERGE
subs above and rebuild to see the problem in action.

=head2 Headers and Parameters

I'm in two minds about whether it's better to use full names to 
specify TT2Headers, e.g.

    TT2Headers	Content-Length Last-Modified

or short keyword forms for brevity:

    TT2Header	length modified

The latter is less typing, but the former are more "offical".  In
an ideal module, we'd do a regex match on /(Content-)?Length/i,
for example, but at present we just stuff 'length' in a hash and 
don't bother.

Oh, and I need to add E-Tag as well.  That was in Darren's Grover
module, but I forgot to add it here.  Darn, I know I'm being lazy
because I could have added it in the time it took me to type this.

=head1 AUTHOR

Andy Wardley E<lt>abw@kfs.orgE<gt>

This module has been derived in part from the 'Grover' module by
Darren Chamberlain (darren@boston.com).  Darren kindly donated his
code for integration into the Apache::Template module.

=head1 VERSION

This is version 0.2 of the Apache::Template module.

=head1 COPYRIGHT

    Copyright (C) 1996-2001 Andy Wardley.  All Rights Reserved.
    Copyright (C) 1998-2001 Canon Research Centre Europe Ltd.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

For further information about the Template Toolkit, see L<Template>
or http://www.template-toolkit.org/

